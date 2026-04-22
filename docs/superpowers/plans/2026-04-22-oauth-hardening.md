# OAuth Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Harden the shipped SNS-login system along five axes: remove plaintext PII retention (`Identity.raw_info`), make `remember_token` server-revocable, decouple merge failure from auth success, and add a Content-Security-Policy layer (Report-Only → enforce).

**Architecture:** Five sequential PRs (Phases 1–5), one spec, overlapping files. Each phase ships independently. Phase 1 precedes Phase 3 (both touch `SessionCreator`; cleaner if `raw_info` is already gone). Phase 5 follows Phase 4 after a ≥1-week observation window with zero `csp.violation` log entries.

**Tech Stack:** Rails 8.1 · SQLite · OmniAuth (google_oauth2 · kakao · naver) · ViewComponent · Hotwire (Turbo + Stimulus) · Minitest · Tidy-First TDD discipline per `CLAUDE.md`.

**Spec:** `docs/superpowers/specs/2026-04-22-oauth-hardening-design.md`

**Delta from spec:**
- Spec shows `GuestMerger#merge!`; actual code uses `GuestMerger#call` — keep `#call`.
- `SessionCreator#attach_and_merge` calls `stamp_terms(target_user)` *after* merger. In Phase 3, `stamp_terms` moves **inside** the committed transaction (it's part of promoting the user, not of merging guest data). Merge runs *after* commit.
- `testing_controller#set_remember_cookie` currently writes an integer payload. Phase 2 updates it to the new `{id, iat}` hash shape so integration tests exercise the real payload.

---

## File Structure

### Files created

| Phase | Path | Responsibility |
|---|---|---|
| 1 | `db/migrate/{ts}_restructure_identities_for_pii_minimization.rb` | Remove `raw_info`, add `email_verified` column |
| 2 | `db/migrate/{ts}_add_tokens_invalidated_at_to_users.rb` | Adds server-side revocation timestamp |
| 4 | `app/controllers/csp_reports_controller.rb` | Receives browser CSP violation reports and tags them in `Rails.logger` |
| 4 | `test/controllers/csp_reports_controller_test.rb` | Exercises the reporting endpoint |
| 4 | `test/integration/csp_test.rb` | Asserts CSP header + nonce injection end-to-end |

### Files modified

| Phase | Path | Change |
|---|---|---|
| 1 | `app/models/identity.rb` | Drop `serialize :raw_info` |
| 1 | `app/services/auth/provider_profile.rb` | Drop `raw_info`, add `email_verified` |
| 1 | `app/services/auth/google_adapter.rb` | Map `info.email_verified` → `email_verified`; stop mapping raw_info |
| 1 | `app/services/auth/kakao_adapter.rb` | Map `kakao_account.is_email_verified` → `email_verified`; stop mapping raw_info |
| 1 | `app/services/auth/naver_adapter.rb` | Map `raw_info.response.email_verified` (nil-safe) → `email_verified`; stop mapping raw_info |
| 1 | `app/services/session_creator.rb` | Stop assigning `i.raw_info` on identity upsert |
| 1 | `test/models/identity_test.rb`, `test/services/auth/**`, `test/services/session_creator_test.rb`, `test/controllers/auth/omniauth_callbacks_controller_test.rb` | Drop `raw_info:` arguments and expectations; add `email_verified` coverage |
| 2 | `app/controllers/application_controller.rb` | `ensure_current_user` accepts new payload shape; adds `cookie_still_valid?` |
| 2 | `app/controllers/auth/omniauth_callbacks_controller.rb` | Write `{id, iat}` cookie payload |
| 2 | `app/controllers/auth/sessions_controller.rb` | New `destroy_all` action |
| 2 | `app/controllers/testing_controller.rb` | `set_remember_cookie` writes new payload shape |
| 2 | `config/routes.rb` | `delete "auth/session/all"` route |
| 2 | `app/components/header/component.html.erb` | Adds "모든 기기에서 로그아웃" link inside user dropdown |
| 2 | `test/integration/guest_session_test.rb`, `test/controllers/auth/sessions_controller_test.rb` | Cover new payload shape, revocation, destroy_all |
| 3 | `app/services/session_creator.rb` | Move `GuestMerger#call` out of `transaction` block; wrap in rescue; return `SessionCreator::Result` |
| 3 | `app/controllers/auth/omniauth_callbacks_controller.rb` | Consume `result.user` / `result.merge_failed` |
| 3 | `test/services/session_creator_test.rb`, `test/controllers/auth/omniauth_callbacks_controller_test.rb` | Assert Result value object + merge-failure degrade |
| 4 | `config/initializers/content_security_policy.rb` | Activate policy in Report-Only mode |
| 4 | `config/routes.rb` | `post "/csp_reports"` |
| 4 | `app/views/layouts/application.html.erb` | Replace inline `<script>` dark-mode FOUC with nonce-tagged `javascript_tag` |
| 5 | `config/initializers/content_security_policy.rb` | Flip `content_security_policy_report_only = false` |
| 5 | `test/integration/csp_test.rb` | Expect enforcement header, not Report-Only |

---

# Phase 1 — Drop `Identity.raw_info`, add `email_verified`

**PR scope:** Schema + struct + adapters + model + service, all in lockstep. Ships as one PR. Touches both structural changes (remove `raw_info` field across the domain) and a behavioral change (map `email_verified` per provider). Separate commits: one structural ("remove raw_info"), one per adapter's `email_verified` mapping.

---

### Task 1.1: Add migration to restructure `identities`

**Files:**
- Create: `db/migrate/{timestamp}_restructure_identities_for_pii_minimization.rb`

- [ ] **Step 1: Generate the migration file**

Run:
```bash
bin/rails generate migration RestructureIdentitiesForPiiMinimization
```

Then replace the generated body with:
```ruby
class RestructureIdentitiesForPiiMinimization < ActiveRecord::Migration[8.1]
  def change
    remove_column :identities, :raw_info, :text
    add_column :identities, :email_verified, :boolean
  end
end
```

- [ ] **Step 2: Apply migration and verify schema**

Run:
```bash
bin/rails db:migrate
bin/rails runner 'puts Identity.columns.map(&:name).sort.inspect'
```
Expected: `["created_at", "email", "email_verified", "id", "provider", "uid", "updated_at", "user_id"]` — `raw_info` absent, `email_verified` present.

- [ ] **Step 3: Commit (structural)**

```bash
git add db/migrate/*_restructure_identities_for_pii_minimization.rb db/schema.rb
git commit -m "refactor(db): remove identities.raw_info, add email_verified"
```

---

### Task 1.2: Drop `raw_info` from the domain struct, model, adapters, service, and tests (structural)

All references to `raw_info` move together in one commit. TDD does not apply — this is a field removal; the behavior test lives in Task 1.3+ once `email_verified` is being mapped.

**Files modified:**
- `app/services/auth/provider_profile.rb`
- `app/models/identity.rb`
- `app/services/auth/google_adapter.rb`
- `app/services/auth/kakao_adapter.rb`
- `app/services/auth/naver_adapter.rb`
- `app/services/session_creator.rb`
- `test/services/auth/provider_profile_test.rb`
- `test/services/auth/google_adapter_test.rb`
- `test/services/auth/kakao_adapter_test.rb`
- `test/services/auth/naver_adapter_test.rb`
- `test/services/session_creator_test.rb`
- `test/controllers/auth/omniauth_callbacks_controller_test.rb` (no `raw_info:` today, verify)

- [ ] **Step 1: Update `ProviderProfile` struct**

Replace `app/services/auth/provider_profile.rb`:
```ruby
module Auth
  ProviderProfile = Struct.new(
    :provider, :uid, :email, :email_verified, :name, :avatar_url,
    keyword_init: true
  )
end
```

- [ ] **Step 2: Remove `serialize :raw_info` from Identity**

Edit `app/models/identity.rb`:
```ruby
class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
end
```

- [ ] **Step 3: Drop raw_info mapping from each adapter**

`app/services/auth/google_adapter.rb`:
```ruby
module Auth
  class GoogleAdapter
    PROVIDER = "google".freeze

    def initialize(auth_hash)
      @auth_hash = auth_hash
    end

    def to_profile
      ProviderProfile.new(
        provider: PROVIDER,
        uid: @auth_hash["uid"],
        email: @auth_hash.dig("info", "email"),
        email_verified: nil,
        name: @auth_hash.dig("info", "name"),
        avatar_url: @auth_hash.dig("info", "image")
      )
    end
  end
end
```

`app/services/auth/kakao_adapter.rb`:
```ruby
module Auth
  class KakaoAdapter
    PROVIDER = "kakao".freeze

    def initialize(auth_hash)
      @auth_hash = auth_hash
    end

    def to_profile
      ProviderProfile.new(
        provider: PROVIDER,
        uid: @auth_hash["uid"].to_s,
        email: @auth_hash.dig("info", "email"),
        email_verified: nil,
        name: @auth_hash.dig("info", "name"),
        avatar_url: @auth_hash.dig("info", "image")
      )
    end
  end
end
```

`app/services/auth/naver_adapter.rb`:
```ruby
module Auth
  class NaverAdapter
    PROVIDER = "naver".freeze

    def initialize(auth_hash)
      @auth_hash = auth_hash
    end

    def to_profile
      ProviderProfile.new(
        provider: PROVIDER,
        uid: @auth_hash["uid"].to_s,
        email: @auth_hash.dig("info", "email"),
        email_verified: nil,
        name: @auth_hash.dig("info", "name"),
        avatar_url: @auth_hash.dig("info", "image") ||
                    @auth_hash.dig("extra", "raw_info", "response", "profile_image")
      )
    end
  end
end
```

(`email_verified: nil` is a placeholder — real provider-specific mapping lands in Tasks 1.3–1.5 with tests.)

- [ ] **Step 4: Stop assigning raw_info in SessionCreator**

Edit `app/services/session_creator.rb` — two blocks. Replace each with the block below (drop `i.raw_info = @profile.raw_info` and add `i.email_verified = @profile.email_verified`):

Block A (line ~26, Case B):
```ruby
Identity.find_or_create_by!(provider: @profile.provider, uid: @profile.uid) do |i|
  i.user = existing
  i.email = @profile.email
  i.email_verified = @profile.email_verified
end
```

Block B (`#upsert_identity`):
```ruby
def upsert_identity
  Identity.find_or_create_by!(provider: @profile.provider, uid: @profile.uid) do |i|
    i.user = @current_guest
    i.email = @profile.email
    i.email_verified = @profile.email_verified
  end
rescue ActiveRecord::RecordNotUnique
  Identity.find_by!(provider: @profile.provider, uid: @profile.uid)
end
```

- [ ] **Step 5: Update tests — drop `raw_info:` from every profile/auth_hash constructor**

`test/services/auth/provider_profile_test.rb`:
```ruby
require "test_helper"

class Auth::ProviderProfileTest < ActiveSupport::TestCase
  test "constructs with keyword args" do
    p = Auth::ProviderProfile.new(
      provider: "kakao", uid: "123", email: "a@b.com", email_verified: true,
      name: "홍길동", avatar_url: "http://x/y.jpg"
    )
    assert_equal "kakao", p.provider
    assert_equal "홍길동", p.name
    assert_equal true, p.email_verified
  end

  test "email may be nil (Kakao opt-out case)" do
    p = Auth::ProviderProfile.new(
      provider: "kakao", uid: "1", email: nil, email_verified: nil,
      name: "a", avatar_url: nil
    )
    assert_nil p.email
    assert_nil p.email_verified
  end
end
```

`test/services/auth/google_adapter_test.rb` — drop the `raw_info` assertion on the final line:
```ruby
assert_equal "https://lh3.googleusercontent.com/a/x.jpg", profile.avatar_url
```
(remove `assert_equal "ko", profile.raw_info["locale"]`)

`test/services/auth/kakao_adapter_test.rb` and `test/services/auth/naver_adapter_test.rb` — no existing `raw_info` assertions, but remove `raw_info` from `auth_hash["extra"]` in test fixtures unchanged (they still need `extra.raw_info` for the Naver fallback test, so keep `extra.raw_info.response.profile_image` in Naver's test; Kakao test can keep `extra.raw_info` since it's provider input, not stored output).

`test/services/session_creator_test.rb` — remove `raw_info: {}` from all four `Auth::ProviderProfile.new(...)` calls.

- [ ] **Step 6: Run the full test suite**

Run:
```bash
bin/rails test
```
Expected: all tests pass. Any failures indicate a missed `raw_info` reference.

- [ ] **Step 7: Commit (structural)**

```bash
git add app/models/identity.rb \
        app/services/auth/provider_profile.rb \
        app/services/auth/google_adapter.rb \
        app/services/auth/kakao_adapter.rb \
        app/services/auth/naver_adapter.rb \
        app/services/session_creator.rb \
        test/services/auth/ \
        test/services/session_creator_test.rb
git commit -m "refactor(auth): drop raw_info from identity domain"
```

---

### Task 1.3: Map `email_verified` in GoogleAdapter (TDD — behavioral)

**Files:**
- Test: `test/services/auth/google_adapter_test.rb`
- Modify: `app/services/auth/google_adapter.rb`

- [ ] **Step 1: Write the failing test**

Append to `test/services/auth/google_adapter_test.rb`:
```ruby
test "maps info.email_verified true" do
  auth_hash = OmniAuth::AuthHash.new(
    "provider" => "google_oauth2", "uid" => "1",
    "info"  => { "email" => "x@y.com", "name" => "X", "image" => nil, "email_verified" => true },
    "extra" => { "raw_info" => {} }
  )
  profile = Auth::GoogleAdapter.new(auth_hash).to_profile
  assert_equal true, profile.email_verified
end

test "maps info.email_verified false" do
  auth_hash = OmniAuth::AuthHash.new(
    "provider" => "google_oauth2", "uid" => "2",
    "info"  => { "email" => "x@y.com", "name" => "X", "image" => nil, "email_verified" => false },
    "extra" => { "raw_info" => {} }
  )
  profile = Auth::GoogleAdapter.new(auth_hash).to_profile
  assert_equal false, profile.email_verified
end

test "maps missing email_verified as nil" do
  auth_hash = OmniAuth::AuthHash.new(
    "provider" => "google_oauth2", "uid" => "3",
    "info"  => { "email" => "x@y.com", "name" => "X", "image" => nil },
    "extra" => { "raw_info" => {} }
  )
  profile = Auth::GoogleAdapter.new(auth_hash).to_profile
  assert_nil profile.email_verified
end
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
bin/rails test test/services/auth/google_adapter_test.rb
```
Expected: 3 failures — `email_verified` is `nil` for the true/false cases (adapter doesn't read the field yet).

- [ ] **Step 3: Implement mapping**

Edit `app/services/auth/google_adapter.rb` — replace `email_verified: nil`:
```ruby
email_verified: @auth_hash.dig("info", "email_verified"),
```

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
bin/rails test test/services/auth/google_adapter_test.rb
```
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/auth/google_adapter.rb test/services/auth/google_adapter_test.rb
git commit -m "feat(auth): GoogleAdapter maps email_verified"
```

---

### Task 1.4: Map `email_verified` in KakaoAdapter (TDD — behavioral)

Kakao exposes the flag under `extra.raw_info.kakao_account.is_email_verified`.

**Files:**
- Test: `test/services/auth/kakao_adapter_test.rb`
- Modify: `app/services/auth/kakao_adapter.rb`

- [ ] **Step 1: Write the failing test**

Append to `test/services/auth/kakao_adapter_test.rb`:
```ruby
test "maps kakao_account.is_email_verified true" do
  auth_hash = OmniAuth::AuthHash.new(
    "provider" => "kakao", "uid" => "1",
    "info"  => { "email" => "a@b.com", "name" => "X", "image" => nil },
    "extra" => { "raw_info" => { "kakao_account" => { "is_email_verified" => true } } }
  )
  assert_equal true, Auth::KakaoAdapter.new(auth_hash).to_profile.email_verified
end

test "maps kakao_account.is_email_verified false" do
  auth_hash = OmniAuth::AuthHash.new(
    "provider" => "kakao", "uid" => "2",
    "info"  => { "email" => "a@b.com", "name" => "X", "image" => nil },
    "extra" => { "raw_info" => { "kakao_account" => { "is_email_verified" => false } } }
  )
  assert_equal false, Auth::KakaoAdapter.new(auth_hash).to_profile.email_verified
end

test "kakao_account missing → email_verified is nil" do
  auth_hash = OmniAuth::AuthHash.new(
    "provider" => "kakao", "uid" => "3",
    "info"  => { "email" => nil, "name" => "익명", "image" => nil },
    "extra" => { "raw_info" => {} }
  )
  assert_nil Auth::KakaoAdapter.new(auth_hash).to_profile.email_verified
end
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
bin/rails test test/services/auth/kakao_adapter_test.rb
```
Expected: 2 failures (true/false cases return nil).

- [ ] **Step 3: Implement mapping**

Edit `app/services/auth/kakao_adapter.rb` — replace `email_verified: nil`:
```ruby
email_verified: @auth_hash.dig("extra", "raw_info", "kakao_account", "is_email_verified"),
```

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
bin/rails test test/services/auth/kakao_adapter_test.rb
```
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add app/services/auth/kakao_adapter.rb test/services/auth/kakao_adapter_test.rb
git commit -m "feat(auth): KakaoAdapter maps email_verified"
```

---

### Task 1.5: Map `email_verified` in NaverAdapter (TDD — behavioral)

Naver exposes the flag under `extra.raw_info.response.email_verified` (nil-safe).

**Files:**
- Test: `test/services/auth/naver_adapter_test.rb`
- Modify: `app/services/auth/naver_adapter.rb`

- [ ] **Step 1: Write the failing test**

Append to `test/services/auth/naver_adapter_test.rb`:
```ruby
test "maps response.email_verified true" do
  auth_hash = OmniAuth::AuthHash.new(
    "provider" => "naver", "uid" => "1",
    "info"  => { "email" => "a@b.com", "name" => "X", "image" => nil },
    "extra" => { "raw_info" => { "response" => { "email_verified" => true } } }
  )
  assert_equal true, Auth::NaverAdapter.new(auth_hash).to_profile.email_verified
end

test "response.email_verified absent → nil" do
  auth_hash = OmniAuth::AuthHash.new(
    "provider" => "naver", "uid" => "2",
    "info"  => { "email" => "a@b.com", "name" => "X", "image" => nil },
    "extra" => { "raw_info" => { "response" => {} } }
  )
  assert_nil Auth::NaverAdapter.new(auth_hash).to_profile.email_verified
end

test "raw_info absent → nil (no exception)" do
  auth_hash = OmniAuth::AuthHash.new(
    "provider" => "naver", "uid" => "3",
    "info"  => { "email" => "a@b.com", "name" => "X", "image" => nil },
    "extra" => {}
  )
  assert_nil Auth::NaverAdapter.new(auth_hash).to_profile.email_verified
end
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
bin/rails test test/services/auth/naver_adapter_test.rb
```
Expected: 1 failure (the positive case; nil cases already pass by accident).

- [ ] **Step 3: Implement mapping**

Edit `app/services/auth/naver_adapter.rb` — replace `email_verified: nil`:
```ruby
email_verified: @auth_hash.dig("extra", "raw_info", "response", "email_verified"),
```

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
bin/rails test test/services/auth/naver_adapter_test.rb
```
Expected: all pass.

- [ ] **Step 5: Full suite regression check**

Run:
```bash
bin/rails test
```
Expected: all pass — confirms no other test references `raw_info`.

- [ ] **Step 6: Commit**

```bash
git add app/services/auth/naver_adapter.rb test/services/auth/naver_adapter_test.rb
git commit -m "feat(auth): NaverAdapter maps email_verified"
```

**End of Phase 1.** Push branch, open PR, merge.

---

# Phase 2 — Revocable `remember_token`

**PR scope:** New `users.tokens_invalidated_at` column, cookie payload shape change (`{id, iat}`), restore-logic with revocation check, `destroy_all` action, header dropdown link.

---

### Task 2.1: Migration — `users.tokens_invalidated_at`

**Files:**
- Create: `db/migrate/{timestamp}_add_tokens_invalidated_at_to_users.rb`

- [ ] **Step 1: Generate migration**

Run:
```bash
bin/rails generate migration AddTokensInvalidatedAtToUsers tokens_invalidated_at:datetime
```

Verify generated body is:
```ruby
class AddTokensInvalidatedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :tokens_invalidated_at, :datetime
  end
end
```

- [ ] **Step 2: Apply migration**

Run:
```bash
bin/rails db:migrate
bin/rails runner 'puts User.columns.map(&:name).include?("tokens_invalidated_at")'
```
Expected: `true`.

- [ ] **Step 3: Commit (structural)**

```bash
git add db/migrate/*_add_tokens_invalidated_at_to_users.rb db/schema.rb
git commit -m "refactor(db): add users.tokens_invalidated_at"
```

---

### Task 2.2: Update `testing_controller#set_remember_cookie` to new payload shape (structural prep)

**Files:**
- Modify: `app/controllers/testing_controller.rb`

- [ ] **Step 1: Replace testing cookie writer**

Replace `app/controllers/testing_controller.rb`:
```ruby
# Test-only controller for seeding cookies that integration tests cannot set directly.
class TestingController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :ensure_current_user

  def set_remember_cookie
    iat = params[:iat].present? ? params[:iat].to_i : Time.current.to_i
    cookies.permanent.signed[:remember_token] = {
      value: { id: params[:user_id].to_i, iat: iat },
      httponly: true,
      same_site: :lax
    }
    render plain: "ok"
  end
end
```

- [ ] **Step 2: Run existing integration tests to confirm they still pass**

Run:
```bash
bin/rails test test/integration/guest_session_test.rb
```

`remember_token`-related tests will now fail — the restore logic in `ApplicationController` is still reading an integer. That's expected: Task 2.3 replaces the restore logic. Skip this step's expectation and move on.

Expected after Task 2.3: they pass.

- [ ] **Step 3: Commit (structural)**

```bash
git add app/controllers/testing_controller.rb
git commit -m "refactor(test): testing_controller writes new remember cookie shape"
```

---

### Task 2.3: Update restore logic in ApplicationController (TDD — behavioral)

**Files:**
- Test: `test/integration/guest_session_test.rb`
- Modify: `app/controllers/application_controller.rb`
- Modify: `app/controllers/auth/omniauth_callbacks_controller.rb` (cookie writer, same shape)

- [ ] **Step 1: Write failing tests — three scenarios**

Append to `test/integration/guest_session_test.rb` (inside the existing `class GuestSessionTest`):
```ruby
test "remember_token: hash payload with iat ≥ tokens_invalidated_at restores session" do
  user = User.create!(guest: false, email: "rev@x.com", name: "Rev")
  user.update!(tokens_invalidated_at: 1.hour.ago)
  post "/testing/set_remember_cookie", params: { user_id: user.id, iat: Time.current.to_i }

  get "/auth/login"
  assert_equal user.id, session[:user_id]
end

test "remember_token: iat earlier than tokens_invalidated_at is rejected" do
  user = User.create!(guest: false, email: "rej@x.com", name: "Rej")
  user.update!(tokens_invalidated_at: Time.current)
  post "/testing/set_remember_cookie", params: { user_id: user.id, iat: 2.hours.ago.to_i }

  get "/auth/login"
  refute_equal user.id, session[:user_id]
end

test "remember_token: tokens_invalidated_at nil always restores" do
  user = User.create!(guest: false, email: "nv@x.com", name: "NV")
  post "/testing/set_remember_cookie", params: { user_id: user.id, iat: Time.current.to_i }

  get "/auth/login"
  assert_equal user.id, session[:user_id]
end

test "remember_token: legacy integer payload is rejected and deleted" do
  user = User.create!(guest: false, email: "legacy@x.com", name: "Legacy")
  # Simulate the pre-refactor integer payload directly.
  cookies.signed[:remember_token] = user.id

  get "/auth/login"
  refute_equal user.id, session[:user_id], "integer payload must not restore"
end
```

Also update the existing test "signed remember_token cookie restores session" — the existing call already uses the new shape via Task 2.2; no edit needed.

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
bin/rails test test/integration/guest_session_test.rb
```
Expected: the 4 new tests plus the pre-existing "signed remember_token cookie restores session" and "remember_token cookie is ignored for guest users" all fail (restore logic still expects integer).

- [ ] **Step 3: Replace `ensure_current_user`**

Edit `app/controllers/application_controller.rb`. Replace the `ensure_current_user` method body:
```ruby
def ensure_current_user
  if session[:user_id] && (user = User.find_by(id: session[:user_id]))
    @current_user = user
  elsif (user = user_from_remember_cookie)
    session[:user_id] = user.id
    @current_user = user
  else
    cookies.delete(:remember_token) if cookies.signed[:remember_token]
    @current_user = User.create!
    session[:user_id] = @current_user.id
  end
end

def user_from_remember_cookie
  payload = cookies.signed[:remember_token]
  return nil unless payload.is_a?(Hash)
  id, iat = payload["id"] || payload[:id], payload["iat"] || payload[:iat]
  return nil unless id && iat.is_a?(Integer)

  user = User.find_by(id: id, guest: false)
  return nil unless user
  return user if user.tokens_invalidated_at.nil?
  Time.zone.at(iat) >= user.tokens_invalidated_at ? user : nil
end
```

Place `user_from_remember_cookie` in the `private` section alongside `ensure_current_user`.

- [ ] **Step 4: Update the cookie writer in OmniauthCallbacksController**

Edit `app/controllers/auth/omniauth_callbacks_controller.rb` — replace the `cookies.permanent.signed[:remember_token]` line:
```ruby
cookies.permanent.signed[:remember_token] = {
  value: { id: target_user.id, iat: Time.current.to_i },
  httponly: true,
  same_site: :lax
}
```

- [ ] **Step 5: Run tests to verify pass**

Run:
```bash
bin/rails test test/integration/guest_session_test.rb test/controllers/auth/omniauth_callbacks_controller_test.rb
```
Expected: all pass.

- [ ] **Step 6: Run full suite**

```bash
bin/rails test
```
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/application_controller.rb \
        app/controllers/auth/omniauth_callbacks_controller.rb \
        test/integration/guest_session_test.rb
git commit -m "feat(auth): remember_token carries {id, iat}; revocation honored"
```

---

### Task 2.4: `destroy_all` action — global logout (TDD)

**Files:**
- Test: `test/controllers/auth/sessions_controller_test.rb`
- Modify: `app/controllers/auth/sessions_controller.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the failing test**

Append to `test/controllers/auth/sessions_controller_test.rb`:
```ruby
test "DELETE destroy_all updates tokens_invalidated_at and logs out" do
  user = User.create!(guest: false, email: "ga@x.com", name: "GlobalOut")
  post "/testing/sign_in", params: { user_id: user.id }
  freeze_time do
    delete "/auth/session/all"

    assert_redirected_to root_path
    assert_equal Time.current, user.reload.tokens_invalidated_at
    assert_equal "모든 기기에서 로그아웃되었습니다.", flash[:notice]
  end

  get root_path
  refute_equal user.id, session[:user_id], "must land on a fresh guest session"
end

test "DELETE destroy_all is a no-op for guest sessions" do
  get root_path
  guest_id = session[:user_id]
  delete "/auth/session/all"

  guest = User.find(guest_id)
  assert_nil guest.tokens_invalidated_at, "no timestamp mutation on a guest"
end
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
bin/rails test test/controllers/auth/sessions_controller_test.rb
```
Expected: both new tests fail with "No route matches".

- [ ] **Step 3: Add route**

Edit `config/routes.rb` — inside the existing `namespace :auth do ... end`, add a line after the logout route:
```ruby
delete "session/all", to: "sessions#destroy_all", as: :destroy_all_session
```

Final namespace block:
```ruby
namespace :auth do
  get    "login",    to: "sessions#new",     as: :login
  delete "logout",   to: "sessions#destroy", as: :logout
  delete "session/all", to: "sessions#destroy_all", as: :destroy_all_session
  get    ":provider/callback", to: "omniauth_callbacks#create", as: :callback
  get    "failure",  to: "omniauth_callbacks#failure"
end
```

- [ ] **Step 4: Implement `destroy_all`**

Edit `app/controllers/auth/sessions_controller.rb`:
```ruby
class Auth::SessionsController < ApplicationController
  def new
    session[:pending_post_action] = params[:pending] if params[:pending].present?
  end

  def destroy
    reset_session
    cookies.delete(:remember_token)
    redirect_to root_path, notice: "로그아웃되었습니다."
  end

  def destroy_all
    user = current_user
    user.update!(tokens_invalidated_at: Time.current) if user && !user.guest?
    reset_session
    cookies.delete(:remember_token)
    redirect_to root_path, notice: "모든 기기에서 로그아웃되었습니다."
  end
end
```

- [ ] **Step 5: Run tests to verify pass**

Run:
```bash
bin/rails test test/controllers/auth/sessions_controller_test.rb
```
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/auth/sessions_controller.rb \
        config/routes.rb \
        test/controllers/auth/sessions_controller_test.rb
git commit -m "feat(auth): destroy_all revokes tokens via tokens_invalidated_at"
```

---

### Task 2.5: Add "모든 기기에서 로그아웃" link to user dropdown (UI, Tidy First — structural)

**Files:**
- Modify: `app/components/header/component.html.erb`
- Modify: `test/integration/guest_session_test.rb`

- [ ] **Step 1: Write the failing assertion**

Append to `test/integration/guest_session_test.rb`:
```ruby
test "logged-in dropdown exposes '모든 기기에서 로그아웃' link" do
  user = User.create!(guest: false, email: "menu@x.com", name: "Menu")
  post "/testing/sign_in", params: { user_id: user.id }
  get "/auth/login"
  assert_match "모든 기기에서 로그아웃", response.body
end
```

- [ ] **Step 2: Run to verify failure**

Run:
```bash
bin/rails test test/integration/guest_session_test.rb -n test_logged_in_dropdown_exposes___모든_기기에서_로그아웃___link
```
Expected: FAIL (substring absent).

- [ ] **Step 3: Add link to the dropdown menu**

Edit `app/components/header/component.html.erb`. Replace the `<div data-dropdown-target="menu">…</div>` block with:
```erb
<div data-dropdown-target="menu" class="hidden absolute right-0 mt-2 w-44 bg-white dark:bg-slate-800 rounded-md shadow-lg border border-slate-200 dark:border-slate-700 py-1">
  <%= link_to "설정", "/settings/budget", class: "block px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700" %>
  <%= button_to "로그아웃", "/auth/logout", method: :delete, form_class: "w-full",
      class: "block w-full text-left px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700" %>
  <%= button_to "모든 기기에서 로그아웃", "/auth/session/all", method: :delete, form_class: "w-full",
      class: "block w-full text-left px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700",
      data: { turbo_confirm: "모든 기기에서 로그아웃하시겠습니까?" } %>
</div>
```

- [ ] **Step 4: Run test to verify pass**

Run:
```bash
bin/rails test test/integration/guest_session_test.rb
```
Expected: all pass.

- [ ] **Step 5: Full suite regression check**

```bash
bin/rails test
```
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add app/components/header/component.html.erb test/integration/guest_session_test.rb
git commit -m "feat(ui): user dropdown exposes '모든 기기에서 로그아웃'"
```

**End of Phase 2.** Push branch, open PR, merge.

---

# Phase 3 — Move merge out of the auth transaction

**PR scope:** `SessionCreator#call` returns `SessionCreator::Result(user:, merge_failed:)`. `GuestMerger#call` runs *after* the auth transaction commits. Merge errors are logged + surfaced via `flash[:alert]`; login still succeeds.

---

### Task 3.1: Introduce `SessionCreator::Result` value object and move merge out of the transaction (TDD — behavioral)

This task changes the contract of `SessionCreator#call` and necessarily touches every existing test that asserts on its return. Do it in one TDD cycle so tests and implementation land atomically.

**Files:**
- Modify: `app/services/session_creator.rb`
- Modify: `test/services/session_creator_test.rb`

- [ ] **Step 1: Rewrite `test/services/session_creator_test.rb` — expect `Result`**

Replace file contents:
```ruby
require "test_helper"

class SessionCreatorTest < ActiveSupport::TestCase
  setup do
    @guest = User.create!
    @existing = User.create!(guest: false, email: "me@example.com", name: "Me")
    @existing.identities.create!(provider: "kakao", uid: "100")
  end

  def new_profile(**overrides)
    Auth::ProviderProfile.new(
      provider: "kakao", uid: "100", email: "me@example.com", email_verified: nil,
      name: "Me", avatar_url: nil, **overrides
    )
  end

  test "Result is a Data value object with user + merge_failed" do
    result = SessionCreator.new(current_guest: @guest, profile: new_profile).call
    assert_kind_of SessionCreator::Result, result
    assert_respond_to result, :user
    assert_respond_to result, :merge_failed
  end

  test "Case A: existing identity logs into existing user and merges guest" do
    result = SessionCreator.new(current_guest: @guest, profile: new_profile).call
    assert_equal @existing, result.user
    refute result.merge_failed
    assert_raises(ActiveRecord::RecordNotFound) { @guest.reload }
  end

  test "Case B: email matches existing account — attaches new identity" do
    existing = User.create!(guest: false, email: "alice@example.com", name: "Alice")
    existing.identities.create!(provider: "kakao", uid: "kakao-1")

    result = SessionCreator.new(
      current_guest: @guest,
      profile: new_profile(provider: "google", uid: "google-1", email: "alice@example.com", name: "Alice")
    ).call

    assert_equal existing, result.user
    refute result.merge_failed
    assert_equal 2, existing.reload.identities.count
  end

  test "Case B nil-email falls to Case C (current guest promoted)" do
    User.create!(guest: false, email: nil, name: "AnonOne")
    result = SessionCreator.new(
      current_guest: @guest,
      profile: new_profile(uid: "k-2", email: nil, name: "AnonTwo")
    ).call
    assert_equal @guest.id, result.user.id
    refute result.user.guest?
  end

  test "Case C: new user - promotes current guest preserving data" do
    prop = Property.create!(case_number: "2024-1111")
    @guest.user_properties.create!(property: prop)

    result = SessionCreator.new(
      current_guest: @guest,
      profile: new_profile(provider: "google", uid: "new-1", email: "new@example.com", name: "New User", avatar_url: "http://x/y.jpg")
    ).call

    assert_equal @guest.id, result.user.id
    refute result.user.guest?
    assert_equal "new@example.com", result.user.email
    assert_equal 1, result.user.user_properties.count
    refute result.merge_failed
  end

  test "GuestMerger failure does not rollback the auth transaction" do
    with_stubbed_merger_raising(Auth::MergeError.new("boom")) do
      result = SessionCreator.new(current_guest: @guest, profile: new_profile).call

      assert_equal @existing, result.user, "login completes despite merge failure"
      assert result.merge_failed
      # Identity is still there (auth transaction committed before merge ran):
      assert Identity.exists?(provider: "kakao", uid: "100")
      # The guest row remains; GuestCleanupJob reaps it later.
      assert @guest.reload.persisted?
    end
  end

  test "GuestMerger failure emits auth.merge_failure log line" do
    captured = StringIO.new
    original_logger = Rails.logger
    Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new(captured))

    with_stubbed_merger_raising(Auth::MergeError.new("kaboom")) do
      SessionCreator.new(current_guest: @guest, profile: new_profile).call
    end

    assert_match(/auth\.merge_failure/, captured.string)
    assert_match(/kaboom/, captured.string)
    assert_match(/"user_id":#{@existing.id}/, captured.string)
  ensure
    Rails.logger = original_logger if original_logger
  end

  private

  def with_stubbed_merger_raising(error)
    GuestMerger.class_eval do
      alias_method :_orig_call, :call
      define_method(:call) { raise error }
    end
    yield
  ensure
    GuestMerger.class_eval do
      alias_method :call, :_orig_call
      remove_method :_orig_call
    end
  end
end
```

Note: the manual `class_eval` override is used because `mocha` is not in the Gemfile. The `with_stubbed_merger_raising` helper closes over `error` from the enclosing scope (the `define_method` block captures it correctly).

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
bin/rails test test/services/session_creator_test.rb
```
Expected: all tests fail — `result` is a `User`, not a `SessionCreator::Result`.

- [ ] **Step 3: Rewrite `SessionCreator`**

Replace `app/services/session_creator.rb`:
```ruby
class SessionCreator
  Result = Data.define(:user, :merge_failed)

  def initialize(current_guest:, profile:)
    @current_guest = current_guest
    @profile = profile
  end

  def call
    target_user = ActiveRecord::Base.transaction(joinable: false) do
      begin
        ActiveRecord::Base.connection.execute("BEGIN IMMEDIATE")
      rescue ActiveRecord::StatementInvalid
        # nested transaction (savepoint in tests) — BEGIN IMMEDIATE not applicable
      end
      dispatch
    end

    merge_failed = false
    if @current_guest != target_user
      begin
        GuestMerger.new(from: @current_guest, to: target_user).call
      rescue Auth::MergeError => e
        merge_failed = true
        log_merge_failure(target_user, e)
      end
    end

    Result.new(user: target_user, merge_failed: merge_failed)
  end

  private

  def dispatch
    if (identity = Identity.find_by(provider: @profile.provider, uid: @profile.uid))
      return attach(identity.user)
    end
    if @profile.email.present? &&
       (existing = User.find_by(email: @profile.email, guest: false))
      Identity.find_or_create_by!(provider: @profile.provider, uid: @profile.uid) do |i|
        i.user = existing
        i.email = @profile.email
        i.email_verified = @profile.email_verified
      end
      return attach(existing)
    end
    promote_guest
  end

  def promote_guest
    @current_guest.reload
    if @current_guest.guest?
      @current_guest.update!(
        guest: false,
        guest_token: nil,
        email: @profile.email,
        name: @profile.name,
        avatar_url: @profile.avatar_url,
        terms_accepted_at: Time.current
      )
    end
    upsert_identity
    @current_guest
  end

  def upsert_identity
    Identity.find_or_create_by!(provider: @profile.provider, uid: @profile.uid) do |i|
      i.user = @current_guest
      i.email = @profile.email
      i.email_verified = @profile.email_verified
    end
  rescue ActiveRecord::RecordNotUnique
    Identity.find_by!(provider: @profile.provider, uid: @profile.uid)
  end

  def attach(target_user)
    stamp_terms(target_user)
    target_user
  end

  def stamp_terms(user)
    user.update!(terms_accepted_at: Time.current) if user.terms_accepted_at.nil?
  end

  def log_merge_failure(user, error)
    Rails.logger.tagged("auth.merge_failure") do
      Rails.logger.error({ user_id: user.id, error: error.class.name, message: error.message }.to_json)
    end
  end
end
```

Key structural shifts from current code:
- Renamed `attach_and_merge` → `attach` (no longer merges — merge moved out of transaction).
- `stamp_terms` runs inside the committed transaction (part of account creation).
- `GuestMerger.new(...).call` runs *after* `transaction do … end` returns, never inside it.
- Returns `Result` value object.

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
bin/rails test test/services/session_creator_test.rb
```
Expected: all pass.

- [ ] **Step 5: Commit (behavioral)**

```bash
git add app/services/session_creator.rb test/services/session_creator_test.rb
git commit -m "feat(auth): SessionCreator returns Result; merge runs after commit"
```

---

### Task 3.2: Update OmniauthCallbacksController to consume Result (TDD)

**Files:**
- Test: `test/controllers/auth/omniauth_callbacks_controller_test.rb`
- Modify: `app/controllers/auth/omniauth_callbacks_controller.rb`

- [ ] **Step 1: Write failing tests for merge-failure degrade**

Append to `test/controllers/auth/omniauth_callbacks_controller_test.rb`:
```ruby
test "merge failure still logs user in, surfaces alert flash" do
  user = User.create!(guest: false, email: "mf@x.com", name: "MF")
  user.identities.create!(provider: "kakao", uid: "mf-1")

  GuestMerger.class_eval do
    alias_method :_orig_call, :call
    define_method(:call) { raise Auth::MergeError, "boom" }
  end

  mock_omniauth(:kakao, uid: "mf-1", email: "mf@x.com", name: "MF")
  get "/auth/kakao/callback"

  assert_redirected_to root_path
  assert_equal user.id, session[:user_id]
  assert_match(/옮기지 못했습니다/, flash[:alert])
  assert cookies[:remember_token].present?, "login cookie must be set despite merge failure"
ensure
  GuestMerger.class_eval do
    if private_method_defined?(:_orig_call) || method_defined?(:_orig_call)
      alias_method :call, :_orig_call
      remove_method :_orig_call
    end
  end
end

test "merge success shows welcome notice, no alert" do
  user = User.create!(guest: false, email: "ok@x.com", name: "OK")
  user.identities.create!(provider: "kakao", uid: "ok-1")

  mock_omniauth(:kakao, uid: "ok-1", email: "ok@x.com", name: "OK")
  get "/auth/kakao/callback"

  assert_nil flash[:alert]
  assert_match(/환영합니다/, flash[:notice])
end
```

Note: manual `class_eval` override used (mocha is not in the Gemfile).

- [ ] **Step 2: Run to verify failure**

Run:
```bash
bin/rails test test/controllers/auth/omniauth_callbacks_controller_test.rb
```
Expected: the merge-failure test fails (controller raises `Auth::MergeError` and hits the rescue_from, redirecting to `/auth/login` instead of `root_path`).

- [ ] **Step 3: Update controller**

Edit `app/controllers/auth/omniauth_callbacks_controller.rb`. Replace the `create` action:
```ruby
def create
  adapter_class = ADAPTERS[request.env["omniauth.auth"]["provider"]]
  raise Auth::ProviderError, "unknown provider" unless adapter_class

  profile = adapter_class.new(request.env["omniauth.auth"]).to_profile
  return_to = session.delete(:return_to_url) || root_path
  pending = session.delete(:pending_post_action)

  result = SessionCreator.new(current_guest: current_user, profile: profile).call

  reset_session
  session[:user_id] = result.user.id
  cookies.permanent.signed[:remember_token] = {
    value: { id: result.user.id, iat: Time.current.to_i },
    httponly: true,
    same_site: :lax
  }
  cookies.permanent[:last_provider] = profile.provider

  if result.merge_failed
    flash[:alert] = "이전 임시 데이터를 옮기지 못했습니다. 문제가 계속되면 고객센터로 알려주세요."
  else
    notice = "환영합니다, #{result.user.name}님"
    notice = "#{notice} — #{pending}를 다시 눌러주세요." if pending
    flash[:notice] = notice
  end
  redirect_to return_to
end
```

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
bin/rails test test/controllers/auth/omniauth_callbacks_controller_test.rb
```
Expected: all pass.

- [ ] **Step 5: Full regression**

```bash
bin/rails test
```
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/auth/omniauth_callbacks_controller.rb \
        test/controllers/auth/omniauth_callbacks_controller_test.rb
git commit -m "feat(auth): callback handles merge failure as soft alert"
```

**End of Phase 3.** Push branch, open PR, merge.

---

# Phase 4 — CSP Report-Only + reporting endpoint

**PR scope:** Replace the commented-out default CSP initializer with an active Report-Only policy; add a report-ingest controller that logs tagged payloads; convert the one inline script in `application.html.erb` to a nonce-tagged `javascript_tag`.

---

### Task 4.1: Nonce-tag the dark-mode FOUC script (structural prep)

The current `<script>` block in `application.html.erb:31-38` runs before CSS load to prevent flash-of-wrong-theme. It uses `localStorage` directly and does not participate in importmap — it must be authored inline. Under CSP we must attach a nonce.

**Files:**
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Convert inline script to nonce-tagged helper**

Replace lines 31–38 of `app/views/layouts/application.html.erb`:
```erb
  <%= javascript_tag nonce: true do %>
    (function() {
      const darkMode = localStorage.getItem("dark-mode");
      if (darkMode === "true" || (darkMode === null && window.matchMedia("(prefers-color-scheme: dark)").matches)) {
        document.documentElement.classList.add("dark");
      }
    })();
  <% end %>
```

Note: the `<script>…</script>` block was between the closing `</head>` and opening `<body>` in the source; `javascript_tag` emits the same structure. Leave the placement unchanged.

- [ ] **Step 2: Run existing tests**

```bash
bin/rails test
```
Expected: all pass — the rendered markup is equivalent (before CSP activation, `nonce: true` is a no-op).

- [ ] **Step 3: Commit (structural)**

```bash
git add app/views/layouts/application.html.erb
git commit -m "refactor(ui): nonce-ready javascript_tag for dark-mode FOUC"
```

---

### Task 4.2: CSP Report-Only + reports endpoint (TDD)

**Files:**
- Create: `app/controllers/csp_reports_controller.rb`
- Create: `test/controllers/csp_reports_controller_test.rb`
- Create: `test/integration/csp_test.rb`
- Modify: `config/initializers/content_security_policy.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing tests — CSP header + nonce**

Create `test/integration/csp_test.rb`:
```ruby
require "test_helper"

class CspTest < ActionDispatch::IntegrationTest
  test "response carries Content-Security-Policy-Report-Only header" do
    get "/auth/login"
    header = response.headers["Content-Security-Policy-Report-Only"]
    assert header.present?, "Report-Only header missing"
    assert_match(/default-src 'self'/, header)
    assert_match(%r{report-uri /csp_reports}, header)
  end

  test "nonce is injected into the header and the dark-mode script" do
    get "/auth/login"
    header = response.headers["Content-Security-Policy-Report-Only"]
    nonce = header[/script-src[^;]*'nonce-([^']+)'/, 1]
    assert nonce.present?, "script-src nonce missing from header"
    assert_match(/<script nonce="#{Regexp.escape(nonce)}">/, response.body)
  end

  test "no enforcement header while in Report-Only mode" do
    get "/auth/login"
    assert_nil response.headers["Content-Security-Policy"]
  end
end
```

Create `test/controllers/csp_reports_controller_test.rb`:
```ruby
require "test_helper"

class CspReportsControllerTest < ActionDispatch::IntegrationTest
  test "POST returns 204 and logs the raw payload with csp.violation tag" do
    captured = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new(captured))

    payload = '{"csp-report":{"document-uri":"http://example/x","violated-directive":"script-src"}}'
    post "/csp_reports", params: payload, headers: { "CONTENT_TYPE" => "application/csp-report" }

    assert_response :no_content
    assert_match "csp.violation", captured.string
    assert_match "violated-directive", captured.string
  ensure
    Rails.logger = original if original
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
bin/rails test test/integration/csp_test.rb test/controllers/csp_reports_controller_test.rb
```
Expected: all fail — policy not active, controller not defined, route missing.

- [ ] **Step 3: Activate the CSP initializer**

Replace `config/initializers/content_security_policy.rb`:
```ruby
# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :https
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.connect_src :self
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self,
                       "https://accounts.google.com",
                       "https://nid.naver.com",
                       "https://kauth.kakao.com"
    policy.report_uri  "/csp_reports"
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
  config.content_security_policy_report_only = true
end
```

Note: the Pretendard font comes from `https://cdn.jsdelivr.net`. It is loaded via `<link rel="stylesheet">`, which is governed by `style-src` — but stylesheets referenced from an external origin count against `style-src` only for `<style>`/`style=""`; external stylesheet *requests* are governed by the fetch directive `style-src` for the stylesheet itself. This will require a `style-src` whitelist entry. Revisit during the observation window (see Task 4.3). Starting with `:self` is deliberate — the whole point of Report-Only is to discover these without impact.

Same logic for the Pretendard `.woff2` files (`font-src`) — the external origin is not yet whitelisted. Observation will surface the need.

- [ ] **Step 4: Create the reports controller**

Create `app/controllers/csp_reports_controller.rb`:
```ruby
class CspReportsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create
  skip_before_action :ensure_current_user, only: :create
  skip_before_action :capture_return_to_url, only: :create
  skip_before_action :touch_last_seen, only: :create

  def create
    Rails.logger.tagged("csp.violation") do
      Rails.logger.warn(request.raw_post.presence || "<empty>")
    end
    head :no_content
  end
end
```

- [ ] **Step 5: Add route**

Edit `config/routes.rb` — insert after the `root` line:
```ruby
post "/csp_reports", to: "csp_reports#create"
```

- [ ] **Step 6: Run tests to verify pass**

Run:
```bash
bin/rails test test/integration/csp_test.rb test/controllers/csp_reports_controller_test.rb
```
Expected: all pass.

- [ ] **Step 7: Full regression**

```bash
bin/rails test
```
Expected: all pass.

- [ ] **Step 8: Manual smoke check — boot dev server and confirm header**

Run:
```bash
bin/dev &
sleep 5
curl -sI http://localhost:3000/auth/login | grep -i 'content-security'
kill %1
```
Expected: a single `Content-Security-Policy-Report-Only:` header with `default-src 'self'` and `report-uri /csp_reports`.

- [ ] **Step 9: Commit**

```bash
git add config/initializers/content_security_policy.rb \
        app/controllers/csp_reports_controller.rb \
        config/routes.rb \
        test/integration/csp_test.rb \
        test/controllers/csp_reports_controller_test.rb
git commit -m "feat(security): CSP Report-Only + /csp_reports logger sink"
```

**End of Phase 4.** Push branch, open PR, merge. Begin observation window.

---

# Phase 5 — Enforce CSP

**PR scope:** One config flag flip and a test update. Ships **only after** at least one week of clean `csp.violation` logs (filter: ignore `source-file` starting with `chrome-extension://`, `moz-extension://`, `safari-web-extension://`).

---

### Task 5.1: Verify observation window is clean

- [ ] **Step 1: Inspect the report log**

Run (substitute the correct production log location if different):
```bash
grep -h 'csp.violation' log/production.log | \
  grep -vE 'chrome-extension://|moz-extension://|safari-web-extension://' | \
  wc -l
```
Expected: `0` across ≥ 1 week of normal traffic. If not zero, triage each distinct violation and decide: (a) add to whitelist (update Task 4.2 initializer), (b) fix the offending template, or (c) block Phase 5 until resolved.

- [ ] **Step 2: Re-verify the fix list**

Common likely findings to expect during observation:
- `https://cdn.jsdelivr.net` (Pretendard font CSS) → add to `style-src` and `font-src`.
- `data:` URIs in `img-src` → already allowed.
- Provider OAuth redirect pages → already covered via `form-action`.

If any of these emerged and were added to the initializer, land those changes in a *separate* Phase 4.5 PR **before** flipping enforcement.

---

### Task 5.2: Flip CSP to enforce mode (TDD)

**Files:**
- Modify: `config/initializers/content_security_policy.rb`
- Modify: `test/integration/csp_test.rb`

- [ ] **Step 1: Update the integration test**

Edit `test/integration/csp_test.rb`. Replace all three tests:
```ruby
require "test_helper"

class CspTest < ActionDispatch::IntegrationTest
  test "response carries Content-Security-Policy (enforcement) header" do
    get "/auth/login"
    header = response.headers["Content-Security-Policy"]
    assert header.present?, "Enforcement header missing"
    assert_match(/default-src 'self'/, header)
    assert_match(%r{report-uri /csp_reports}, header)
  end

  test "nonce is injected into the enforcement header and the dark-mode script" do
    get "/auth/login"
    header = response.headers["Content-Security-Policy"]
    nonce = header[/script-src[^;]*'nonce-([^']+)'/, 1]
    assert nonce.present?, "script-src nonce missing"
    assert_match(/<script nonce="#{Regexp.escape(nonce)}">/, response.body)
  end

  test "no Report-Only header in enforcement mode" do
    get "/auth/login"
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
bin/rails test test/integration/csp_test.rb
```
Expected: all fail — `Content-Security-Policy` header is nil, Report-Only header is still present.

- [ ] **Step 3: Flip the flag**

Edit `config/initializers/content_security_policy.rb`. Replace the last active line:
```ruby
config.content_security_policy_report_only = false
```

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
bin/rails test test/integration/csp_test.rb
```
Expected: all pass.

- [ ] **Step 5: Full regression + manual smoke**

```bash
bin/rails test
bin/dev &
sleep 5
curl -sI http://localhost:3000/auth/login | grep -i 'content-security'
kill %1
```
Expected: test suite green; one `Content-Security-Policy:` header (no `-Report-Only`).

- [ ] **Step 6: Commit**

```bash
git add config/initializers/content_security_policy.rb test/integration/csp_test.rb
git commit -m "feat(security): enforce Content-Security-Policy"
```

**End of Phase 5.** Push branch, open PR, merge. OAuth Hardening complete.

---

## Validation Checklist (post-Phase-5 verification)

Run after Phase 5 merges to prod.

- [ ] Open a fresh browser, navigate to root, inspect DevTools → Security tab → verify `Content-Security-Policy` (no `-Report-Only`) header is present.
- [ ] Log in via Kakao, Google, Naver — each still redirects back and logs the user in.
- [ ] Navigate to `/auth/session/all`, confirm redirect-with-flash "모든 기기에서 로그아웃되었습니다" and that a second browser (same account) is now logged out on next request.
- [ ] `bin/rails runner 'puts Identity.column_names'` — confirm no `raw_info`, yes `email_verified`.
- [ ] Verify dark-mode toggle still works with no FOUC (nonce applied correctly).
- [ ] Tail `log/production.log`; after 24h confirm no `csp.violation` entries from first-party traffic.
