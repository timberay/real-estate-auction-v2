# OAuth Hardening: Five-Phase Security & Completion Pass

**Date:** 2026-04-22
**Status:** Design pending user review, then implementation plan
**Companion to:** `2026-04-22-sns-login-design.md` (the original SNS login spec)

## Context

The SNS login implementation shipped (commits `63ce30d` … `fd63a79`) covers Case A/B/C OAuth flow, GuestMerger with per-association policy, rate limiting, session-fixation defense, remember_token cookie, and a comprehensive test suite. An objective post-ship review surfaced 18 candidate improvement areas. The user selected the five highest-leverage items — those that are either:

1. Documented in the original design but not implemented, or
2. Carry direct PII / token-revocability risk.

This spec covers those five. Out-of-scope items are listed at the end and remain candidates for future specs.

## Decisions (from brainstorming)

| # | Topic | Decision |
|---|---|---|
| 1 | `Identity.raw_info` handling | **Drop the column entirely.** Whitelist needed fields as typed columns. raw_info has no production reader; the only beneficiary is debugging, which doesn't justify indefinite PII retention. |
| 2 | `remember_token` revocability | **Single `users.tokens_invalidated_at` timestamp.** Cookie payload becomes `{id, issued_at}`. Restore rejects when `issued_at < tokens_invalidated_at`. Per-device sessions table is out of scope (no UI driver yet). |
| 3 | Merge failure UX | **Move merge out of the auth transaction.** Login always succeeds; merge failure produces a warning flash + structured log. Confirmation UI deferred — too much UX surface for an edge case. |
| 4 | CSP rollout | **Report-Only first, enforce in a follow-up PR after a 1–2 week observation window.** Strict-from-day-one risks blocking external assets we haven't catalogued. |
| 5 | Bundling | **One spec, five sequential PRs (Phase 1–5).** All five touch overlapping files (`identity.rb`, `application_controller.rb`, `session_creator.rb`, the auth test files); a single planning context is cheaper than five small specs. |

## Goals & Non-Goals

**Goals**
- Eliminate indefinite plaintext PII storage in `identities.raw_info`.
- Make `remember_token` revocable from the server (currently impossible without changing `users.id`).
- Ensure a transient `GuestMerger` failure cannot block a user from logging in.
- Add a server-side XSS defense layer (CSP) that the project currently has zero of.

**Non-Goals (deferred to separate specs if/when prioritized)**
- Per-device session management UI ("이 기기에서 로그아웃")
- Account linking / unlinking from a settings page
- PKCE for any provider
- Terms-of-service version tracking
- Identity merge audit log
- Provider registry refactor (currently 4-file change to add a new provider)
- Account-aware (per-email) rate limiting beyond the existing IP throttle
- Encrypted-at-rest secrets beyond Rails encrypted credentials

## Architecture

### Phase 1 — Drop `Identity.raw_info`

**Current state**

```ruby
# app/models/identity.rb
serialize :raw_info, coder: JSON

# app/services/auth/google_adapter.rb (and naver_adapter, kakao_adapter)
ProviderProfile.new(
  provider:, uid:, email:, name:, avatar_url:,
  raw_info: auth_hash.to_h  # entire provider response, plaintext
)

# app/services/session_creator.rb
Identity.find_or_create_by!(provider:, uid:) do |i|
  i.raw_info = @profile.raw_info
end
```

**Target state**

```ruby
# app/models/identity.rb — `serialize :raw_info` removed
# app/services/auth/provider_profile.rb — raw_info field removed.
#   email_verified:Boolean added (Google `email_verified`, Naver `email_verified`,
#   Kakao `kakao_account.is_email_verified` — nil where provider doesn't expose it)

# Migration
remove_column :identities, :raw_info, :text

# Adapters: stop carrying the full hash, only map whitelisted fields
```

The `email_verified` field is the one piece of provider metadata that has a future use (e.g., not auto-linking on Case B if email is unverified). Adding it now is cheap and avoids a second migration later.

### Phase 2 — Revocable `remember_token`

**Current cookie:** `cookies.permanent.signed[:remember_token] = { value: target_user.id, ... }`
The signed payload is just the user id. To "log out everywhere" today, you'd have to change the user id, which is impossible.

**New cookie payload:**

```ruby
cookies.permanent.signed[:remember_token] = {
  value: { id: target_user.id, iat: Time.current.to_i },
  httponly: true,
  same_site: :lax
}
```

**New restore logic in `ApplicationController#ensure_current_user`:**

```ruby
elsif (payload = cookies.signed[:remember_token]).is_a?(Hash) &&
      (user = User.find_by(id: payload["id"], guest: false)) &&
      cookie_still_valid?(user, payload["iat"])
  # restore
else
  cookies.delete(:remember_token) if cookies.signed[:remember_token]
  # fall through to guest creation
end

def cookie_still_valid?(user, iat)
  return false unless iat.is_a?(Integer)
  return true if user.tokens_invalidated_at.nil?
  Time.zone.at(iat) >= user.tokens_invalidated_at
end
```

**Migration**

```ruby
add_column :users, :tokens_invalidated_at, :datetime
```

**New action — global logout**

```ruby
# app/controllers/auth/sessions_controller.rb
def destroy_all
  if (user = Current.user) && !user.guest?
    user.update!(tokens_invalidated_at: Time.current)
  end
  reset_session
  cookies.delete(:remember_token)
  redirect_to root_path, notice: "모든 기기에서 로그아웃되었습니다."
end
```

**Routes**

```ruby
namespace :auth do
  delete "session/all", to: "sessions#destroy_all", as: :destroy_all_session
end
```

**UI**

A single link in the existing user dropdown / mobile menu: "모든 기기에서 로그아웃". No separate page, no device list.

**Backwards compatibility**

Old cookies (where `signed[:remember_token]` returns an integer, not a hash) are treated as invalid → silently deleted → user falls through to guest. Acceptable because pre-deployment.

### Phase 3 — Move merge out of the auth transaction

**Current flow** (paraphrased from `session_creator.rb`):

```
SessionCreator#call
  ApplicationRecord.transaction do
    upsert_or_attach_identity
    promote_or_resolve_user
    GuestMerger.new(...).merge!   # raises Auth::MergeError on failure → entire transaction rolls back, login fails
  end
```

**New flow:**

```
SessionCreator#call → returns SessionCreator::Result(user:, merge_failed:)

  target_user = ApplicationRecord.transaction do
    upsert_or_attach_identity
    promote_or_resolve_user        # returns the now-real account user
  end
  # Login is decided here. Merge happens AFTER and is non-fatal.
  merge_failed = false
  begin
    GuestMerger.new(target: target_user, source: @current_guest).merge!
  rescue Auth::MergeError => e
    merge_failed = true
    Rails.logger.tagged("auth.merge_failure") do
      Rails.logger.error({ user_id: target_user.id, error: e.class.name, message: e.message }.to_json)
    end
  end
  Result.new(user: target_user, merge_failed: merge_failed)
```

`SessionCreator::Result` is a `Data.define(:user, :merge_failed)` value object. The merge error is **swallowed inside `SessionCreator`** so the caller doesn't need scope-juggling around `begin/rescue`.

**Controller change** (`Auth::OmniauthCallbacksController#create`):

```ruby
result = Auth::SessionCreator.new(...).call
reset_session
session[:user_id] = result.user.id
cookies.permanent.signed[:remember_token] = { id: result.user.id, iat: Time.current.to_i }

if result.merge_failed
  redirect_to return_to, alert: "이전 임시 데이터를 옮기지 못했습니다. 문제가 계속되면 고객센터로 알려주세요."
else
  redirect_to return_to, notice: "환영합니다, #{result.user.name}님."
end
```

The contract: `SessionCreator#call` always returns a `Result` whose `user` is logged-in-able. Non-merge errors (identity conflict, missing email, provider error) still raise `Auth::Error` subclasses and surface via the existing `rescue_from` in `ApplicationController`. Only `Auth::MergeError` is downgraded to a flag.

**Implication for guest data:** if merge fails, the original guest user remains in the database (orphaned from session). The existing `GuestCleanupJob` will reap it after 30 days, so no manual cleanup is required.

### Phase 4 — CSP Report-Only

**Activate `config/initializers/content_security_policy.rb`:**

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :https
    policy.object_src  :none
    policy.script_src  :self, :nonce
    policy.style_src   :self, :nonce
    policy.connect_src :self
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self, "https://accounts.google.com",
                              "https://nid.naver.com",
                              "https://kauth.kakao.com"
    policy.report_uri  "/csp_reports"
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
  config.content_security_policy_report_only = true
end
```

**Reporting endpoint:**

```ruby
# app/controllers/csp_reports_controller.rb
class CspReportsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create
  skip_before_action :ensure_current_user, only: :create

  def create
    Rails.logger.tagged("csp.violation") do
      Rails.logger.warn(request.raw_post)
    end
    head :no_content
  end
end

# config/routes.rb
post "/csp_reports", to: "csp_reports#create"
```

The endpoint just logs. No DB table, no aggregation — Rails logs are enough for the observation window. If volume becomes a problem we throttle via rack-attack later.

**Audit pass before activation:** scan ERB templates for inline `<script>` and `style=` attributes; convert any found to nonce-tagged or external assets. Stimulus and Turbo Streams use neither, so the impact should be minimal.

### Phase 5 — CSP enforce (separate PR, after observation)

A single config change plus a test update. Held to its own PR so the observation window is explicit:

```ruby
config.content_security_policy_report_only = false
```

Spec note: Phase 5 ships **only after** the team confirms `csp.violation` log volume is at zero (or known acceptable) for at least one week of normal traffic.

## Component Inventory

| Phase | File | Change |
|---|---|---|
| 1 | `db/migrate/{ts}_restructure_identities_for_pii_minimization.rb` | New — single migration: `remove_column :identities, :raw_info`; `add_column :identities, :email_verified, :boolean` |
| 1 | `app/models/identity.rb` | Remove `serialize :raw_info` |
| 1 | `app/services/auth/provider_profile.rb` | Remove `raw_info`; add `email_verified` |
| 1 | `app/services/auth/google_adapter.rb` | Map `email_verified` from `info.email_verified`; drop raw_info |
| 1 | `app/services/auth/kakao_adapter.rb` | Map from `kakao_account.is_email_verified`; drop raw_info |
| 1 | `app/services/auth/naver_adapter.rb` | Map from `raw_info.response.email_verified` (nil-safe); drop raw_info |
| 1 | `app/services/session_creator.rb` | Stop assigning `i.raw_info` |
| 2 | `db/migrate/{ts}_add_tokens_invalidated_at_to_users.rb` | New |
| 2 | `app/controllers/application_controller.rb` | New `cookie_still_valid?`; payload-shape check in restore |
| 2 | `app/controllers/auth/omniauth_callbacks_controller.rb` | Cookie payload `{id, iat}` |
| 2 | `app/controllers/auth/sessions_controller.rb` | New `destroy_all` action |
| 2 | `config/routes.rb` | `delete "auth/session/all"` |
| 2 | View partial for user menu | "모든 기기에서 로그아웃" link |
| 3 | `app/services/session_creator.rb` | Move `GuestMerger#merge!` out of `transaction` block |
| 3 | `app/controllers/auth/omniauth_callbacks_controller.rb` | `rescue Auth::MergeError` → login + alert flash |
| 4 | `config/initializers/content_security_policy.rb` | Activate, Report-Only |
| 4 | `app/controllers/csp_reports_controller.rb` | New |
| 4 | `config/routes.rb` | `post "/csp_reports"` |
| 4 | ERB templates audit | Convert any inline scripts/styles found |
| 5 | `config/initializers/content_security_policy.rb` | `report_only = false` |

## Data Model Changes

```diff
  identities:
-   raw_info: text (JSON serialized)
+   email_verified: boolean, nullable

  users:
+   tokens_invalidated_at: datetime, nullable
```

No data migration needed — both changes are additive (Phase 1 column removal is fine because all current rows are dev/test).

## Error Handling

| Scenario | Behavior |
|---|---|
| Phase 1 migration rollback | Standard Rails — `raw_info` column restored if `down` runs. Safe. |
| Phase 2: cookie payload is integer (legacy shape) | Restore returns nil; cookie deleted; guest fallback. |
| Phase 2: cookie `iat` missing or non-integer | Treated invalid; cookie deleted. |
| Phase 2: `tokens_invalidated_at` set after cookie issuance | Restore rejected; cookie deleted; guest fallback. |
| Phase 3: `GuestMerger` raises | Login completes; `flash[:alert]` shown; `Rails.logger.tagged("auth.merge_failure")` records `user_id` + error class. |
| Phase 3: SessionCreator transaction (non-merge) raises | Existing `Auth::Error` rescue — no change. |
| Phase 4: ERB inline script discovered post-deploy | CSP Report-Only logs it; no user impact. Fix forward. |
| Phase 4: high CSP report volume | Add rack-attack throttle on `/csp_reports`. |

## Testing Plan

| Phase | Test file | Cases |
|---|---|---|
| 1 | `test/models/identity_test.rb` | Remove `raw_info` assertions |
| 1 | `test/services/auth/{google,kakao,naver}_adapter_test.rb` | Drop raw_info expectation; assert `email_verified` mapping (positive, negative, nil) |
| 1 | `test/services/auth/provider_profile_test.rb` | New `email_verified` field |
| 1 | `test/services/session_creator_test.rb` | Identity attach without raw_info |
| 2 | `test/integration/guest_session_test.rb` | (a) Cookie issued at T1, `tokens_invalidated_at = T2 > T1` → restore rejected, cookie deleted. (b) `tokens_invalidated_at` nil → restore allowed. (c) Legacy integer cookie → restore rejected, cookie deleted. |
| 2 | `test/controllers/auth/sessions_controller_test.rb` | `DELETE /auth/session/all` updates `tokens_invalidated_at`, deletes cookie, resets session |
| 3 | `test/services/session_creator_test.rb` | Stub `GuestMerger#merge!` to raise `Auth::MergeError` → `SessionCreator#call` returns `Result(user:, merge_failed: true)`; identity + user upsert still persisted (auth transaction committed before merge attempt); `auth.merge_failure` log line emitted |
| 3 | `test/services/session_creator_test.rb` | Happy path now returns `Result(user:, merge_failed: false)` — update existing assertions to use `.user` accessor |
| 3 | `test/controllers/auth/omniauth_callbacks_controller_test.rb` | Stubbed merge failure → 302 to return_to, `session[:user_id]` set, remember_token cookie present, `flash[:alert]` matches "옮기지 못했습니다" |
| 4 | `test/integration/csp_test.rb` (new) | Response carries `Content-Security-Policy-Report-Only` header; nonce appears in header and in injected `<script nonce="...">` tags |
| 4 | `test/controllers/csp_reports_controller_test.rb` (new) | POST returns 204; payload appears in logs (capture via `Rails.logger`) |
| 5 | `test/integration/csp_test.rb` | Updated to expect `Content-Security-Policy` (not `-Report-Only`) |

## Rollout Sequence

Each Phase ships as its own PR. They are independent at the file level except:
- Phase 1 must precede Phase 3 (Phase 3 changes `SessionCreator`; cleaner if raw_info is already gone).
- Phase 5 must follow Phase 4 by ≥ 1 week of clean reports.

Suggested order: **1 → 2 → 3 → 4 → 5**.

## Risks

| Risk | Mitigation |
|---|---|
| Phase 1 destroys raw_info diagnostic data we end up needing | Pre-deployment timing — no production data exists. If it later matters, add structured columns instead of restoring raw blob. |
| Phase 2 cookie shape change breaks existing logged-in test sessions | Tests reset cookies between cases; `testing_controller.rb` updates cookie shape in one place. |
| Phase 3 leaves orphan guest rows when merge fails | Acceptable — `GuestCleanupJob` reaps after 30 days. |
| Phase 4 Report-Only generates noise from third-party browser extensions | Filter at ingest endpoint (skip reports where `source-file` is `chrome-extension://`). |
| Phase 5 enforce blocks something we missed | Roll back the one-line config change; re-open observation window. |

## Open Questions

None at this point. All five decisions landed on Option A in brainstorming.
