# SNS Login: Guest-First OAuth with Seamless Promotion

**Date:** 2026-04-22
**Status:** Design approved, pending implementation plan

## Context

Today, every visitor shares a single `User` record (`guest@auction.local`) created by `ApplicationController#set_guest_user`. All budgets, onboarding answers, saved properties, and results are stored against the same row — multi-user deployment would leak data across sessions. The app is not yet deployed, so we can redesign cleanly.

The SRS v2 mandates SNS-only authentication (Google, Naver, Kakao) with no email/password login. Phase 4.1 of the MVP roadmap lists this as the single remaining post-MVP task. The priority is **maximum user convenience** — low-friction onboarding, no login wall until a clear save moment, and preservation of in-progress work across login.

## Decisions (from brainstorming)

| # | Topic | Decision |
|---|---|---|
| 1 | Flow | **Guest-first + login on save/export/revisit** (Option 2) |
| 2 | Deploy state | Fresh slate — no existing user data to migrate |
| 3 | Providers | **Google, Naver, Kakao** (no Apple) |
| 4 | Login triggers | PDF export · "save result" · revisit to `/saved` or `/history`; plus always-visible header login button |
| 5 | Account linking | **Email-based auto-link**; separate account when email missing (Kakao opt-out case) |
| 6 | Post-login profile prompt | **None** — immediate entry; terms consent via button-click-implies-consent |
| 7 | Session persistence | **Remember-me by default** (30-day signed permanent cookie, no checkbox) |
| 8 | Merge conflict | **Guest data wins** automatically (latest user intent) |
| 9 | Login UI | **Turbo Frame modal** (bottom sheet on mobile) with "last used provider" promoted to top |
| 10 | Post-login UX | Modal closes, toast greeting, original action auto-resumes |
| 11 | Guest retention | **30 days inactive** → daily cleanup job |
| 12 | Merge failure recovery | User chooses between "continue with guest data" and "switch to account (discard)" |
| 13 | Merge policy | **Per-association metadata** on `User` (`merge_policy:`, `natural_key:`); no blanket "guest wins" |
| 14 | OAuth scope | Explicit scope strings for Kakao + Naver (not just Google); dev-console checklist in README |
| 15 | Naver gem risk | 15-minute compatibility spike before writing-plans; fallback to custom `omniauth-oauth2` strategy |
| 16 | Deferred action | URL-based (`session[:return_to_url]`, GET only); POST actions surface via toast + highlighted button |
| 17 | nil-email defense | Service-layer guard (`email.present?` + `guest: false`) + DB partial unique with `email IS NOT NULL` |
| 18 | Concurrency | SQLite `BEGIN IMMEDIATE` around merge + idempotent `find_or_create_by!` on Identity + Stimulus button disable |

## Architecture

```
[Visitor]
   │
   ▼
ApplicationController#ensure_current_user
   │
   ├─ existing session[:user_id] valid? ──► use it
   │
   └─ else ──► create new guest User (guest: true, guest_token)
                session[:user_id] = guest.id
   │
   ▼
[Guest browses freely — onboarding, questions, results]
   │
   ▼
[Triggers login modal: header button OR save/export/revisit]
   │
   ▼
Login Modal (Turbo Frame)
   │
   └─ provider click ──► /auth/:provider  (OmniAuth)
                             │
                             ▼
                         Provider consent
                             │
                             ▼
                    /auth/:provider/callback  (POST, CSRF-protected)
                             │
                             ▼
                    OmniauthCallbacksController#create
                             │
                             ▼
                    Auth::{Google,Naver,Kakao}Adapter
                      → Auth::ProviderProfile (normalized)
                             │
                             ▼
                    SessionCreator
                      │
      ┌──────────────┼──────────────┐
      │              │              │
   Case A         Case B         Case C
(identity      (email           (fully new)
 match)         match)
      │              │              │
      ▼              ▼              ▼
 log in +      attach new    promote current
 merge guest   identity +    guest in place
 into user     merge         (flip flags,
                              fill fields,
                              attach identity)
      │              │              │
      └──────────────┼──────────────┘
                     ▼
              reset_session
              session[:user_id] = target_user.id
              cookies.permanent.signed[:remember_token]
                     │
                     ▼
              resume deferred action (return_to_action)
              toast "환영합니다, {name}님"
```

## Data Model

### `users` (modified)

```ruby
# Migration: drop password_digest, add guest fields
t.string   :email          # nullable — guest rows may have null
t.string   :name           # nullable — populated after OAuth
t.string   :avatar_url     # nullable
t.boolean  :guest, null: false, default: true
t.string   :guest_token    # nullable, unique
t.datetime :last_seen_at
t.datetime :terms_accepted_at

add_index :users, :guest_token, unique: true
add_index :users, :email, where: "guest = false AND email IS NOT NULL", unique: true  # partial unique; nil-email tolerated
add_index :users, [:guest, :last_seen_at]  # cleanup job
```

- `has_secure_password` removed; `password_digest` column dropped; `bcrypt` gem removed from Gemfile.
- `email` uniqueness only enforced for non-guest rows (partial index).
- `terms_accepted_at` set on the first successful OAuth callback for that user (Case A/B/C alike); not overwritten on subsequent logins. Preserves legal record of first consent moment.

### `identities` (new)

```ruby
create_table :identities do |t|
  t.references :user, null: false, foreign_key: true
  t.string :provider, null: false   # "google" | "naver" | "kakao"
  t.string :uid,      null: false
  t.string :email                   # as provided by provider, may be nil
  t.text   :raw_info                # JSON dump (see retention note)
  t.timestamps
end

add_index :identities, [:provider, :uid], unique: true
add_index :identities, [:user_id, :provider]
```

`raw_info` is retained for 90 days only (cleared by cleanup job) — PII minimization.

## Services

### `Auth::ProviderProfile`

```ruby
Auth::ProviderProfile = Struct.new(:provider, :uid, :email, :name, :avatar_url, :raw_info, keyword_init: true)
```

### `Auth::{Google,Naver,Kakao}Adapter`

Each adapter normalizes the OmniAuth `auth_hash` into `Auth::ProviderProfile`. Provider-specific quirks are isolated here (e.g., Kakao `kakao_account.email` may be nil; Naver `response.profile_image` for avatar).

```
app/services/auth/
├─ provider_profile.rb
├─ google_adapter.rb
├─ naver_adapter.rb
└─ kakao_adapter.rb
```

### `SessionCreator`

Single entry point from the callback controller. Dispatches to Case A/B/C and delegates merging.

```ruby
class SessionCreator
  def initialize(current_guest:, profile:); end

  def call  # returns target_user or raises Auth::Error
    ActiveRecord::Base.transaction(joinable: false) do
      ActiveRecord::Base.connection.execute("BEGIN IMMEDIATE")  # SQLite write lock
      dispatch
    end
  end

  private

  def dispatch
    identity = Identity.find_by(provider: profile.provider, uid: profile.uid)
    return attach_and_merge(identity.user) if identity                     # Case A
    if profile.email.present? && (existing = User.find_by(email: profile.email, guest: false))
      return attach_and_merge(existing)                                    # Case B
    end
    promote_guest                                                          # Case C (includes nil-email Kakao)
  end
end
```

- `BEGIN IMMEDIATE` elevates the SQLite transaction to a write lock, serializing concurrent logins for the same guest and preventing double-merge.
- `Identity.find_or_create_by!(provider:, uid:)` is used when attaching (Case B/C) so a racing second callback is idempotent.
- `profile.email.present? && guest: false` scope prevents accidental linking to another nil-email user (belt-and-suspenders with the DB partial unique index).

### `GuestMerger`

Merge behavior is **explicit per association** on the `User` model, not inferred from reflections. Each `has_many`/`has_one` that must participate in merge declares its `merge_policy` and, if the association has a composite unique index involving `user_id`, its `natural_key`. Associations without `merge_policy` are **ignored** by the merger (safe default — a new association added later won't silently leak).

```ruby
# app/models/user.rb
class User < ApplicationRecord
  # Policies:
  #   :prefer_guest — guest row wins; on natural_key collision, target row is deleted first
  #   :keep_target  — target row wins; on collision, guest row is discarded
  #   :coexist      — no collision possible (no unique index); simply reassign user_id
  #
  # natural_key names the non-user_id column(s) in the composite unique index.

  has_one  :budget_setting,            dependent: :destroy, merge_policy: :prefer_guest
  has_many :user_properties,           dependent: :destroy, merge_policy: :prefer_guest, natural_key: :property_id
  has_many :inspection_results,        dependent: :destroy, merge_policy: :prefer_guest, natural_key: [:property_id, :inspection_item_id]
  has_many :rights_analysis_reports,   dependent: :destroy, merge_policy: :prefer_guest, natural_key: :property_id
  has_many :search_results,            dependent: :destroy, merge_policy: :prefer_guest, natural_key: :case_number
  has_many :api_credentials,           dependent: :destroy, merge_policy: :keep_target, natural_key: :provider_name
  has_many :llm_analysis_logs,         dependent: :nullify  # no merge_policy → ignored
  has_many :properties, through: :user_properties           # through: ignored
end
```

```ruby
class GuestMerger
  def initialize(from:, to:); end

  def call
    ActiveRecord::Base.transaction do
      User.mergeable_reflections.each { |reflection| merge(reflection) }
      from.destroy!
    end
  end

  private

  def merge(reflection)
    policy = reflection.options[:merge_policy]
    natural_key = Array(reflection.options[:natural_key])

    case policy
    when :prefer_guest
      delete_target_collisions(reflection, natural_key)
      from.public_send(reflection.name).update_all(user_id: to.id)
    when :keep_target
      if reflection.macro == :has_one
        from.public_send(reflection.name)&.destroy
      else
        delete_guest_collisions(reflection, natural_key)
        from.public_send(reflection.name).update_all(user_id: to.id)
      end
    when :coexist
      from.public_send(reflection.name).update_all(user_id: to.id)
    end
  end
end
```

- `User.mergeable_reflections` returns only reflections that declare `merge_policy`.
- The two collision helpers (`delete_target_collisions`, `delete_guest_collisions`) use `natural_key` to find `to`'s or `from`'s conflicting rows and destroy them before the `user_id` reassignment.
- `api_credentials` is explicitly `keep_target` to prevent guest-registered keys from overwriting the logged-in user's real credentials.
- New association added later without `merge_policy` is silently skipped, making the default safe. A developer deliberately including it in merge must declare intent.

## Controllers & Routes

### Routes

```ruby
# config/routes.rb
get    "/auth/login",              to: "auth/sessions#new",     as: :login
delete "/auth/logout",             to: "auth/sessions#destroy", as: :logout
get    "/auth/:provider/callback", to: "auth/omniauth_callbacks#create", as: :auth_callback
get    "/auth/failure",            to: "auth/omniauth_callbacks#failure"
```

The request-phase endpoint `POST /auth/:provider` is intercepted by OmniAuth middleware (no Rails route entry). `omniauth-rails_csrf_protection` forces this phase to be POST and validates the CSRF token; the callback phase returns as a GET from the provider.

### `Auth::SessionsController`

- `new` — renders the login modal (Turbo Frame)
- `destroy` — clears session + remember_token cookie, creates new guest

### `Auth::OmniauthCallbacksController`

- `create` — success path; invokes adapter → `SessionCreator` → resume deferred action
- `failure` — routes OmniAuth error codes into localized UI messages

### `ApplicationController` changes

Replace `set_guest_user` with `ensure_current_user` (see Architecture). Add:

```ruby
rescue_from Auth::Error, with: :handle_auth_error
```

## UI / UX

### Header

| State | Right side |
|-------|------------|
| Guest | `[로그인]` button (outlined, low-attention) |
| Logged in | Avatar + name + dropdown (`내 결과`, `설정`, `로그아웃`) |

### Login Modal

```
┌──────────────────────────────┐
│           로그인              │
│                              │
│   내 결과를 안전하게 저장하세요. │
│                              │
│   [🟡 카카오로 계속하기]     │ ← "last used" floats to top
│   [🟢 네이버로 계속하기]     │
│   [⚪ Google로 계속하기]     │
│                              │
│   계속 진행 시 [이용약관] 및   │
│   [개인정보 처리방침]에 동의합니다.│
└──────────────────────────────┘
```

- Default order: Kakao → Naver → Google (Korean market share)
- Last-used provider remembered via `cookies.permanent[:last_provider]` and reorders buttons on subsequent visits
- Mobile: renders as bottom sheet
- Same-tab redirect (no popup)
- Minimum 44px tap target
- Contextual hint: when triggered by PDF export, header reads "PDF를 저장하려면 로그인이 필요해요"
- Buttons disable on click via a Stimulus controller (`auth_modal_controller.js`), preventing double-submit and giving immediate "loading" feedback. Pairs with the SQLite transaction lock in `SessionCreator` to protect against concurrent-login edge cases.

### Deferred Action Resumption

URL-based, GET-only. When the login modal is triggered from a context the user wants to return to:

1. On modal open, the current page path is captured: `session[:return_to_url] = request.fullpath` (only when the current request is `GET`).
2. Before `reset_session`, the value is moved to a local variable.
3. After session reset and new `user_id` assignment, it is passed via `flash[:return_to]` to the redirect target.
4. The post-login controller redirects to `flash[:return_to]` or root if absent.

For POST-initiated triggers (e.g., "PDF 내보내기" button which submits a form):
- Do not attempt automatic replay of the POST.
- Redirect back to the page that originated the action and show a toast: "로그인되었습니다. PDF 내보내기를 다시 눌러주세요." with the target button highlighted.
- Rationale: replaying POSTs across a session boundary is CSRF-fragile; one extra click is a reasonable tradeoff for predictability.

Post-resume greeting toast: "환영합니다, {name}님" (3s, independent of return_to).

## Error Handling

### `Auth::Error` hierarchy

```
Auth::Error (StandardError)
├─ Auth::ProviderError        # unrecoverable provider fault
├─ Auth::EmailMissingError    # handled silently — separate account created
├─ Auth::IdentityConflictError
└─ Auth::MergeError
```

### OmniAuth failure codes

| Code | Response |
|------|----------|
| `access_denied` | Modal reopens with "로그인이 취소되었습니다" |
| `invalid_credentials` | Log + generic retry message |
| `timeout` | Retry button |
| `csrf_detected` | Modal reopens, log incident |
| other | Generic message + log |

### Merge failure

On `Auth::MergeError`, render a confirmation screen:
- **Continue with guest data** — stay on guest user, surface "로그인되지 않았습니다" flash
- **Switch to account (discard guest work)** — log in, guest user destroyed

Log `guest_user_id`, `target_user_id`, and failing association.

## Security

- `omniauth-rails_csrf_protection` gem — POST callbacks only, CSRF state validation
- `reset_session` before setting `session[:user_id]` — session fixation defense
- `cookies.permanent.signed[:remember_token]` — 32-byte SecureRandom, 30-day TTL
- Credentials in `config/credentials/{environment}.yml.enc`; ENV fallback documented in README
- `config.force_ssl = true` in production (Rails 8 default)
- Scope minimization: each provider requests email, name, avatar only
- No PII in logs: `user_id`, `provider`, result code only. `raw_info` purged at 90 days.
- Rate limit `/auth/:provider` at 10/min/IP (rack-attack)

## Guest Cleanup

`GuestCleanupJob` (Solid Queue, daily):
- Destroys `users` where `guest = true AND last_seen_at < 30 days ago`
- `dependent: :destroy` cascades associations
- Logs daily count for monitoring

`last_seen_at` is updated on each request, throttled to one write per minute per user. Implementation: `Rails.cache.fetch("last_seen:#{user.id}", expires_in: 1.minute) { user.touch(:last_seen_at); true }` — the cache token prevents `UPDATE` storm on every request.

## Configuration

### Gemfile additions

```ruby
gem "omniauth"
gem "omniauth-rails_csrf_protection"
gem "omniauth-google-oauth2"
gem "omniauth-naver"
gem "omniauth-kakao"
gem "rack-attack"   # if not already present
```

### Gemfile removal

```ruby
# Remove — OAuth-only now
gem "bcrypt", "~> 3.1.7"
```

### `config/initializers/omniauth.rb`

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2,
    Rails.application.credentials.dig(:google, :client_id),
    Rails.application.credentials.dig(:google, :client_secret),
    scope: "email,profile"
  provider :naver,
    Rails.application.credentials.dig(:naver, :client_id),
    Rails.application.credentials.dig(:naver, :client_secret),
    scope: "name email profile_image"
  provider :kakao,
    Rails.application.credentials.dig(:kakao, :client_id),
    Rails.application.credentials.dig(:kakao, :client_secret),
    scope: "account_email profile_nickname profile_image"
end

OmniAuth.config.on_failure = proc { |env| Auth::OmniauthCallbacksController.action(:failure).call(env) }
```

**Scope rationale:** Kakao does not return `account_email` by default; Naver requires each field to be enabled as a consent item in the developer console AND requested by the client. Without these explicit scopes, Case B (email-based auto-link) silently fails for Kakao and may miss name/avatar for Naver.

### Provider developer-console checklist (README)

Each developer MUST complete the following for local OAuth to function:

**Kakao (`https://developers.kakao.com`)**
1. Create an app; copy REST API key → `:kakao, :client_id`.
2. 보안 → 생성 Client Secret → `:kakao, :client_secret`.
3. 카카오 로그인 → 활성화 ON.
4. Redirect URI: `http://localhost:3000/auth/kakao/callback`.
5. 동의항목: enable **카카오계정(이메일) — 필수 동의**, **프로필 정보(닉네임)**, **프로필 사진**.

**Naver (`https://developers.naver.com`)**
1. Application → 등록. 서비스 URL: `http://localhost:3000`. Callback URL: `http://localhost:3000/auth/naver/callback`.
2. 제공 정보: check **이메일 주소**, **별명**, **프로필 사진**.
3. Client ID/Secret → `:naver, :client_id` / `:client_secret`.

**Google (`https://console.cloud.google.com`)**
1. APIs & Services → Credentials → OAuth 2.0 Client ID (Web application).
2. Authorized redirect URI: `http://localhost:3000/auth/google_oauth2/callback`.
3. OAuth consent screen: scopes `userinfo.email`, `userinfo.profile`.
4. Client ID/Secret → `:google, :client_id` / `:client_secret`.

### Developer credential setup (README)

Each developer creates their own provider apps and injects credentials. No shared credentials. Document registration URLs and callback URL format:
- Google: `http(s)://{host}/auth/google_oauth2/callback`
- Naver: `http(s)://{host}/auth/naver/callback`
- Kakao: `http(s)://{host}/auth/kakao/callback`

## Testing Strategy

Per project CLAUDE.md: TDD, Red-Green-Refactor, small commits, Tidy First (structural and behavioral changes in separate commits).

### Mocking

```ruby
OmniAuth.config.test_mode = true
OmniAuth.config.mock_auth[:kakao] = OmniAuth::AuthHash.new(
  provider: "kakao", uid: "12345",
  info: { email: "user@kakao.test", name: "홍길동" }
)
```

### Coverage matrix

| Layer | Tests |
|-------|-------|
| Model (`test/models/`) | Guest creation defaults, promotion state transition, Identity uniqueness `(provider, uid)`, partial email uniqueness allows nil, `User.mergeable_reflections` filter, `last_seen_at` throttle |
| Service (`test/services/auth/`) | ProviderProfile normalization per provider, Kakao nil-email returns Case C (not linked to existing nil-email user), GuestMerger atomicity, per-policy dispatch (`prefer_guest` / `keep_target` / `coexist`), natural-key collision resolution for each composite unique index, api_credentials is NOT overwritten |
| Controller (`test/controllers/auth/`) | Case A/B/C callbacks, `access_denied` redirect, CSRF enforcement (GET-phase request blocked), `reset_session` called, `return_to_url` captured before reset and surfaced after, POST-origin trigger surfaces toast instead of replaying |
| System (`test/system/`) | End-to-end: guest → onboard → PDF click → modal → Kakao mock → return to page + toast; revisit auto-login from permanent cookie; logout resets to new guest; two-browser guest isolation; button-disable on click |
| Concurrency (`test/integration/`) | Two concurrent callback requests for the same guest produce exactly one merge; identity `find_or_create_by!` is idempotent under race |
| Job (`test/jobs/`) | GuestCleanupJob deletes only `guest: true` past 30 days, preserves logged-in users, cascades associations per policy |

### Pre-implementation spike (gate)

Before writing-plans begins, run a 15-minute spike to de-risk the `omniauth-naver` gem:

1. Add `gem "omniauth-naver"` on a throwaway branch; `bundle install`.
2. Configure with a disposable Naver test app.
3. Walk through one full Naver login in local dev.
4. If success → pin the exact gem version in Gemfile; proceed to implementation.
5. If failure → fall back to a custom `omniauth-oauth2`-based Naver strategy in `lib/omniauth/strategies/naver.rb` (~80 lines) and discard the gem.

This gate prevents mid-implementation discovery of Rails 8 / OmniAuth 2 incompatibility.

### Implementation order (TDD)

1. Migration: `users` (drop `password_digest`, add guest fields, partial unique email index) + `identities` table — structural commit
2. `User` + `Identity` model specs and implementations (including `mergeable_reflections` metadata) — behavioral commit(s)
3. `Auth::ProviderProfile` + three adapters
4. `GuestMerger` service (policy dispatch, natural-key collision resolution)
5. `SessionCreator` service (SQLite `BEGIN IMMEDIATE` lock, idempotent Identity attach, nil-email Case C fallthrough)
6. Routes + `OmniauthCallbacksController` (Case A/B/C)
7. `Auth::SessionsController` + login modal view + Turbo Frame wiring + Stimulus button-disable controller
8. Header UI (guest vs logged-in)
9. `return_to_url` capture + post-login redirect (GET only; POST handled via toast)
10. `GuestCleanupJob`
11. `last_seen_at` throttle (Rails.cache token)
12. Security hardening (rack-attack, force_ssl check)
13. System test covering full flow

Each step: failing test → minimal implementation → refactor → commit. Structural and behavioral changes go in separate commits per CLAUDE.md Tidy First rule.

## Out of Scope

- Apple Sign In
- Email/password login
- Multi-factor authentication
- Account deletion UI (separate future task)
- Admin console for user management
- Provider-specific marketing fields (Kakao `age_range`, Naver `gender`, etc.)

## Open Questions

None — all decisions locked during brainstorming and plan-eng-review.

## Plan-Eng-Review Summary (2026-04-22)

Seven critical issues raised and resolved in this review, folded into the sections above:

1. **Per-association merge policy** (1A) — `merge_policy:` metadata on `User` associations; `api_credentials` is `:keep_target` to protect real API keys from guest overwrite.
2. **Composite unique index collisions** (2A) — `natural_key:` metadata + `delete_target_collisions` in `GuestMerger`.
3. **Kakao / Naver OAuth scope** (3A) — explicit scope strings + developer-console checklist in README.
4. **`omniauth-naver` risk** (4A) — 15-minute compatibility spike gates writing-plans.
5. **`return_to` mechanism** (5A) — URL-based, GET-only; POST-origin triggers surface via toast, not replay.
6. **nil-email defense** (6C) — service-layer guard + DB partial unique narrowed to `email IS NOT NULL`.
7. **Concurrent-login race** (7A + 7B) — SQLite `BEGIN IMMEDIATE` lock + idempotent `find_or_create_by!` + Stimulus button disable.

Secondary (non-critical) additions:
- `last_seen_at` throttle mechanism made concrete (`Rails.cache` token).
- TDD implementation order updated with new steps and spike gate.
- Test matrix expanded: new Concurrency layer, explicit coverage for per-policy merge, nil-email Case C, permanent-cookie auto-login, button-disable, two-browser isolation.
