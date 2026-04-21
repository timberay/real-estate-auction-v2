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
add_index :users, :email, where: "guest = false", unique: true  # partial unique
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
    identity = Identity.find_by(provider: profile.provider, uid: profile.uid)
    return attach_and_merge(identity.user) if identity                              # Case A
    return attach_and_merge(existing) if (existing = find_by_email(profile.email))  # Case B
    promote_guest                                                                    # Case C
  end
end
```

### `GuestMerger`

```ruby
class GuestMerger
  def initialize(from:, to:); end
  def call
    ActiveRecord::Base.transaction do
      User.reflections.each do |name, reflection|
        next unless reflection.macro == :has_many
        from.public_send(name).update_all(user_id: to.id)
      end
      resolve_conflicts  # guest wins
      from.destroy!
    end
  end
end
```

Conflict resolution is opinionated: when `to` already has a row on an association backed by a `unique` index on `user_id` (e.g., singleton `budget`), the target's existing row is deleted first, then the guest's row is reassigned. For non-unique associations (e.g., saved properties), both sets coexist post-merge. Conflict resolution lives in `GuestMerger#resolve_conflicts`.

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

### Deferred Action Resumption

On trigger, the intended action is serialized to `session[:return_to_action]` as a structured payload (`{ controller:, action:, params: }`). Post-login, a before_action re-dispatches it. Post-resume toast: "환영합니다, {name}님" (3s).

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

`last_seen_at` updated on each request, throttled to 1 write per minute per user.

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
    Rails.application.credentials.dig(:naver, :client_secret)
  provider :kakao,
    Rails.application.credentials.dig(:kakao, :client_id),
    Rails.application.credentials.dig(:kakao, :client_secret)
end

OmniAuth.config.on_failure = proc { |env| Auth::OmniauthCallbacksController.action(:failure).call(env) }
```

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
| Model (`test/models/`) | Guest creation defaults, promotion state transition, Identity uniqueness `(provider, uid)`, partial email uniqueness |
| Service (`test/services/auth/`) | ProviderProfile normalization per provider, Kakao-null-email branch, GuestMerger atomicity, conflict resolution (guest wins) |
| Controller (`test/controllers/auth/`) | Case A/B/C callbacks, `access_denied` redirect, CSRF enforcement (GET blocked), `reset_session` called, return_to_action resumption |
| System (`test/system/`) | End-to-end: guest → onboard → PDF click → modal → Kakao mock → auto-export; revisit auto-login; logout resets to guest |
| Job (`test/jobs/`) | GuestCleanupJob deletes only `guest: true` past 30 days, preserves logged-in users, cascades associations |

### Implementation order (TDD)

1. Migration: `users` (drop `password_digest`, add guest fields) + `identities` table — structural commit
2. `User` + `Identity` model specs and implementations — behavioral commit(s)
3. `Auth::ProviderProfile` + three adapters
4. `GuestMerger` service
5. `SessionCreator` service
6. Routes + `OmniauthCallbacksController` (Case A/B/C)
7. `Auth::SessionsController` + login modal view + Turbo Frame wiring
8. Header UI (guest vs logged-in)
9. `return_to_action` pipeline + deferred action resumption
10. `GuestCleanupJob`
11. Security hardening (rack-attack, force_ssl check)
12. System test covering full flow

Each step: failing test → minimal implementation → refactor → commit.

## Out of Scope

- Apple Sign In
- Email/password login
- Multi-factor authentication
- Account deletion UI (separate future task)
- Admin console for user management
- Provider-specific marketing fields (Kakao `age_range`, Naver `gender`, etc.)

## Open Questions

None — all decisions locked during brainstorming.
