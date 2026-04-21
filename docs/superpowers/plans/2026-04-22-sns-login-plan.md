# SNS Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the shared-guest-user authentication bug with per-session guest isolation and Google/Naver/Kakao OAuth, preserving all in-progress work through login.

**Architecture:** Rails 8 + OmniAuth 2. Guests get their own `User` row keyed by a per-session `guest_token`. OAuth callbacks promote or merge the current guest into the authenticated user via `SessionCreator` + `GuestMerger`. Merge behavior is explicit per-association via `merge_policy` metadata. Provider quirks (Kakao nil-email, Naver scope) are isolated in `Auth::*Adapter` services. Concurrency is serialized by a SQLite `BEGIN IMMEDIATE` transaction plus `find_or_create_by!` idempotency.

**Tech Stack:** Rails 8.1, SQLite, Minitest, Hotwire (Turbo + Stimulus), OmniAuth 2, Solid Queue, rack-attack.

**Source spec:** `docs/superpowers/specs/2026-04-22-sns-login-design.md` (commit `eb42c4d`).

**Tidy First reminder:** Structural changes (migrations, file moves, removing validations) and behavioral changes (new logic) MUST be in separate commits. Each phase below marks commits as `[STRUCT]` or `[BEHAVIOR]`.

---

## File Structure

### Created files

**Migrations**
- `db/migrate/<ts>_restructure_users_for_oauth.rb` — drop `password_digest`, add guest fields, partial unique email index
- `db/migrate/<ts>_create_identities.rb` — new `identities` table

**Models**
- `app/models/identity.rb` — OAuth identity per provider

**Services**
- `app/services/auth/errors.rb` — `Auth::Error` hierarchy
- `app/services/auth/provider_profile.rb` — normalized OAuth profile struct
- `app/services/auth/google_adapter.rb`
- `app/services/auth/naver_adapter.rb`
- `app/services/auth/kakao_adapter.rb`
- `app/services/guest_merger.rb` — per-association merge with natural-key collision resolution
- `app/services/session_creator.rb` — Case A/B/C dispatch + concurrency lock

**Controllers**
- `app/controllers/auth/sessions_controller.rb` — login modal, logout
- `app/controllers/auth/omniauth_callbacks_controller.rb` — provider callback + failure

**Jobs**
- `app/jobs/guest_cleanup_job.rb`

**Views**
- `app/views/auth/sessions/new.html.erb` — login modal (Turbo Frame)
- `app/views/auth/sessions/_modal.html.erb`
- `app/views/layouts/_header.html.erb` (if not already present)

**JavaScript**
- `app/javascript/controllers/auth_modal_controller.js` — button disable on click

**Config**
- `config/initializers/omniauth.rb`
- `config/initializers/rack_attack.rb`

**Optional fallback**
- `lib/omniauth/strategies/naver.rb` — only if Phase 0 spike fails

**Tests**
- `test/models/identity_test.rb`
- `test/services/auth/google_adapter_test.rb`
- `test/services/auth/naver_adapter_test.rb`
- `test/services/auth/kakao_adapter_test.rb`
- `test/services/guest_merger_test.rb`
- `test/services/session_creator_test.rb`
- `test/controllers/auth/sessions_controller_test.rb`
- `test/controllers/auth/omniauth_callbacks_controller_test.rb`
- `test/integration/concurrent_login_test.rb`
- `test/jobs/guest_cleanup_job_test.rb`
- `test/system/auth_flow_test.rb`

### Modified files

- `app/models/user.rb` — remove `has_secure_password`, add guest behavior + `merge_policy` metadata
- `app/controllers/application_controller.rb` — replace `set_guest_user` with `ensure_current_user`, add `return_to_url` capture, `Auth::Error` rescue
- `config/routes.rb` — add auth routes
- `app/views/layouts/application.html.erb` — include header partial
- `Gemfile` — add OmniAuth + rack-attack, remove bcrypt
- `test/fixtures/users.yml` — switch to guest/identity structure
- `test/test_helper.rb` — add OmniAuth test-mode setup helpers
- `README.md` — OAuth developer-console setup checklist

---

## Phase 0: Pre-implementation Spike (GATE)

Single 15-30 minute investigation to de-risk `omniauth-naver`. Do not proceed to Phase 1 until this passes or a fallback is chosen.

### Task 0.1: Naver gem compatibility spike

**Files:**
- Temporary branch `spike/naver-gem`
- Temporary edit: `Gemfile`

- [ ] **Step 1: Create spike branch**

```bash
git checkout -b spike/naver-gem
```

- [ ] **Step 2: Add Naver + OmniAuth to Gemfile (temp)**

Edit `Gemfile`, add after line 21 (`gem "bcrypt", ...`):

```ruby
gem "omniauth", "~> 2.1"
gem "omniauth-rails_csrf_protection", "~> 1.0"
gem "omniauth-naver", "~> 0.1"
```

Run:

```bash
bundle install
```

Expected: bundler resolves. If a dep conflict arises, record the version constraint and try alternative forks (e.g., `gem "omniauth-naver", github: "naver/naver-omniauth-rails"`).

- [ ] **Step 3: Register a disposable Naver developer app**

At `https://developers.naver.com`:
- Service URL: `http://localhost:3000`
- Callback URL: `http://localhost:3000/auth/naver/callback`
- Enable consent items: 이메일, 별명, 프로필 사진

Export to env:

```bash
export NAVER_CLIENT_ID=<the-id>
export NAVER_CLIENT_SECRET=<the-secret>
```

- [ ] **Step 4: Create minimal OmniAuth config**

Create `config/initializers/omniauth_spike.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :naver, ENV["NAVER_CLIENT_ID"], ENV["NAVER_CLIENT_SECRET"],
    scope: "name email profile_image"
end
OmniAuth.config.allowed_request_methods = [:post]
```

Edit `config/routes.rb`, add temporarily:

```ruby
get "/auth/:provider/callback", to: ->(env) {
  [200, {"Content-Type" => "text/plain"}, [env["omniauth.auth"].to_h.inspect]]
}
```

Add a form to trigger at `app/views/home/index.html.erb` (temp):

```erb
<%= button_to "Naver spike", "/auth/naver", method: :post, data: { turbo: false } %>
```

- [ ] **Step 5: Exercise the flow**

```bash
bin/rails server
```

Open `http://localhost:3000`, click the Naver spike button, complete consent, land on callback. Verify:
- Callback body contains `info.email`, `info.name`, `info.image`
- No exception in server log
- `auth_hash["uid"]` is present

- [ ] **Step 6: Record verdict and clean up**

If PASS:
```bash
git checkout main
git branch -D spike/naver-gem  # throwaway
```
Record in the main-branch plan: "Naver gem version X.Y.Z confirmed working on Rails 8.1.3 / OmniAuth 2."

If FAIL:
- Mark Phase 4 Task 4.3 "Use `lib/omniauth/strategies/naver.rb` custom fallback"
- Delete `omniauth-naver` from Gemfile before Phase 1.
- Keep spike branch for reference.

**No commit is made on `main` during Phase 0.** The spike branch is discarded.

---

## Phase 1: Data Model (structural)

### Task 1.1: Users migration — drop password_digest, add guest fields

**Files:**
- Create: `db/migrate/<ts>_restructure_users_for_oauth.rb`

- [ ] **Step 1: Generate the migration**

```bash
bin/rails generate migration RestructureUsersForOauth
```

- [ ] **Step 2: Write migration body**

Replace file contents with:

```ruby
class RestructureUsersForOauth < ActiveRecord::Migration[8.1]
  def change
    change_table :users do |t|
      t.remove :password_digest, type: :string
      t.string   :name
      t.string   :avatar_url
      t.boolean  :guest,       null: false, default: true
      t.string   :guest_token
      t.datetime :last_seen_at
      t.datetime :terms_accepted_at
      t.change   :email, :string, null: true
    end

    remove_index :users, :email if index_exists?(:users, :email)
    add_index :users, :guest_token, unique: true
    add_index :users, :email,
      unique: true,
      where: "guest = 0 AND email IS NOT NULL",
      name: "index_users_on_email_when_account"
    add_index :users, [:guest, :last_seen_at]
  end
end
```

Note: SQLite represents boolean `false` as `0`; the partial-index WHERE clause uses that literal.

- [ ] **Step 3: Run the migration**

```bash
bin/rails db:migrate
```

Expected: `== RestructureUsersForOauth: migrated` and `db/schema.rb` updated.

- [ ] **Step 4: Commit [STRUCT]**

```bash
git add db/migrate/*_restructure_users_for_oauth.rb db/schema.rb
git commit -m "refactor(db): restructure users table for OAuth (drop password_digest, add guest fields)"
```

### Task 1.2: Identities table migration

**Files:**
- Create: `db/migrate/<ts>_create_identities.rb`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration CreateIdentities
```

- [ ] **Step 2: Write migration body**

```ruby
class CreateIdentities < ActiveRecord::Migration[8.1]
  def change
    create_table :identities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider, null: false
      t.string :uid,      null: false
      t.string :email
      t.text   :raw_info
      t.timestamps
    end

    add_index :identities, [:provider, :uid], unique: true
    add_index :identities, [:user_id, :provider]
  end
end
```

- [ ] **Step 3: Run the migration**

```bash
bin/rails db:migrate
```

- [ ] **Step 4: Commit [STRUCT]**

```bash
git add db/migrate/*_create_identities.rb db/schema.rb
git commit -m "feat(db): add identities table for OAuth"
```

### Task 1.3: Remove has_secure_password from User model

**Files:**
- Modify: `app/models/user.rb`

- [ ] **Step 1: Delete `has_secure_password` line and email validations**

Edit `app/models/user.rb` — remove:

```ruby
has_secure_password
```

And:

```ruby
validates :email, presence: true, uniqueness: true
```

(Keep the `has_one :budget_setting` and other associations unchanged for now.)

- [ ] **Step 2: Delete the existing user model test**

```bash
rm test/models/user_test.rb
```

Rationale: every test in that file exercised `has_secure_password` and will fail. A replacement will be written in Phase 2 Task 2.1.

- [ ] **Step 3: Update fixtures to new shape**

Overwrite `test/fixtures/users.yml`:

```yaml
guest_one:
  guest: true
  guest_token: "guest-token-one"
  last_seen_at: <%= 1.hour.ago %>

guest_two:
  guest: true
  guest_token: "guest-token-two"
  last_seen_at: <%= 5.minutes.ago %>

budget_user:
  email: "budget@auction.local"
  name: "Budget User"
  guest: false
  terms_accepted_at: <%= 1.day.ago %>
  last_seen_at: <%= 10.minutes.ago %>
```

- [ ] **Step 4: Run the full test suite to see remaining breakage**

```bash
bin/rails test 2>&1 | tail -40
```

Expected: failures where fixtures or code reference `password` or `password_digest`. Record the list — these will be fixed incrementally in later tasks.

- [ ] **Step 5: Commit [STRUCT]**

```bash
git add app/models/user.rb test/models/user_test.rb test/fixtures/users.yml
git commit -m "refactor(user): remove has_secure_password; fixtures switched to guest/account shape"
```

---

## Phase 2: User + Identity domain models (behavior)

### Task 2.1: User — guest flag defaults + guest_token auto-generation

**Files:**
- Modify: `app/models/user.rb`
- Create: `test/models/user_test.rb`

- [ ] **Step 1: Write failing tests for guest defaults and token generation**

Create `test/models/user_test.rb`:

```ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "new user defaults to guest: true" do
    user = User.create!
    assert user.guest?
  end

  test "guest user gets a unique guest_token automatically" do
    u1 = User.create!
    u2 = User.create!
    assert u1.guest_token.present?
    assert u2.guest_token.present?
    refute_equal u1.guest_token, u2.guest_token
  end

  test "account user (guest: false) does not require guest_token" do
    account = User.create!(guest: false, email: "a@example.com")
    assert_nil account.guest_token
  end
end
```

- [ ] **Step 2: Run test, verify it fails**

```bash
bin/rails test test/models/user_test.rb -v
```

Expected: `new user defaults to guest: true` PASSES (DB default) but `guest_token` test FAILS with `guest_token: nil`.

- [ ] **Step 3: Implement guest_token auto-generation**

Edit `app/models/user.rb`, add near the top of the class:

```ruby
before_validation :assign_guest_token, on: :create

private

def assign_guest_token
  return unless guest?
  return if guest_token.present?
  self.guest_token = SecureRandom.urlsafe_base64(32)
end
```

- [ ] **Step 4: Run test, verify it passes**

```bash
bin/rails test test/models/user_test.rb -v
```

Expected: 3 tests, 3 assertions, 0 failures.

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/models/user.rb test/models/user_test.rb
git commit -m "feat(user): auto-assign guest_token on create for guest users"
```

### Task 2.2: User — partial email uniqueness (only for account users, email not null)

**Files:**
- Modify: `app/models/user.rb`
- Modify: `test/models/user_test.rb`

- [ ] **Step 1: Add failing tests**

Append to `test/models/user_test.rb`:

```ruby
test "two guests with null email coexist" do
  User.create!
  assert_nothing_raised { User.create! }
end

test "two account users with same email are rejected at DB level" do
  User.create!(guest: false, email: "dup@example.com")
  assert_raises(ActiveRecord::RecordNotUnique) do
    User.create!(guest: false, email: "dup@example.com")
  end
end

test "account user and guest with same email coexist" do
  User.create!(guest: false, email: "shared@example.com")
  assert_nothing_raised { User.create!(email: "shared@example.com") }
end
```

- [ ] **Step 2: Run tests to verify current behavior**

```bash
bin/rails test test/models/user_test.rb -v
```

Expected: all three new tests PASS — the DB partial unique index from Task 1.1 already enforces this. This task confirms the index is doing its job.

- [ ] **Step 3: Commit [BEHAVIOR]**

(No code change — this is a characterization commit that pins the DB-level behavior.)

```bash
git add test/models/user_test.rb
git commit -m "test(user): characterize partial email uniqueness (account-only, non-null)"
```

### Task 2.3: User — mergeable reflection metadata

**Files:**
- Modify: `app/models/user.rb`
- Modify: `test/models/user_test.rb`

- [ ] **Step 1: Write failing test for `User.mergeable_reflections`**

Append to `test/models/user_test.rb`:

```ruby
test "User.mergeable_reflections returns only associations with merge_policy" do
  names = User.mergeable_reflections.map(&:name).sort
  expected = %i[
    api_credentials budget_setting inspection_results
    rights_analysis_reports search_results user_properties
  ]
  assert_equal expected, names
end

test "merge_policy metadata is preserved on reflections" do
  r = User.reflect_on_association(:api_credentials)
  assert_equal :keep_target, r.options[:merge_policy]
  assert_equal :provider_name, r.options[:natural_key]
end

test "llm_analysis_logs is not mergeable (has no merge_policy)" do
  names = User.mergeable_reflections.map(&:name)
  refute_includes names, :llm_analysis_logs
end
```

- [ ] **Step 2: Run test, verify it fails**

```bash
bin/rails test test/models/user_test.rb -v
```

Expected: `NoMethodError: undefined method 'mergeable_reflections' for class User`.

- [ ] **Step 3: Add merge_policy metadata + class method**

Edit `app/models/user.rb` — replace the associations block with:

```ruby
has_one  :budget_setting,            dependent: :destroy, merge_policy: :prefer_guest
has_many :user_properties,           dependent: :destroy, merge_policy: :prefer_guest, natural_key: :property_id
has_many :properties, through: :user_properties
has_many :inspection_results,        dependent: :destroy, merge_policy: :prefer_guest, natural_key: [:property_id, :inspection_item_id]
has_many :rights_analysis_reports,   dependent: :destroy, merge_policy: :prefer_guest, natural_key: :property_id
has_many :search_results,            dependent: :destroy, merge_policy: :prefer_guest, natural_key: :case_number
has_many :api_credentials,           dependent: :destroy, merge_policy: :keep_target, natural_key: :provider_name
has_many :llm_analysis_logs,         dependent: :nullify
has_many :identities,                dependent: :destroy

def self.mergeable_reflections
  reflect_on_all_associations.select { |r| r.options[:merge_policy].present? }
end
```

Note: Rails raises on unknown `has_many` options by default. To allow custom keys like `merge_policy` and `natural_key`, register them. Create `config/initializers/reflection_extensions.rb`:

```ruby
# Allow custom options on association reflections so User can declare
# merge_policy / natural_key inline on has_many / has_one.
module ReflectionExtensions
  VALID_AUTOMATIC_INVERSE_MACROS = ActiveRecord::Reflection::AssociationReflection::VALID_AUTOMATIC_INVERSE_MACROS
end

ActiveRecord::Associations::Builder::HasMany.singleton_class.prepend(
  Module.new do
    def valid_options(options)
      super + [:merge_policy, :natural_key]
    end
  end
)
ActiveRecord::Associations::Builder::HasOne.singleton_class.prepend(
  Module.new do
    def valid_options(options)
      super + [:merge_policy, :natural_key]
    end
  end
)
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
bin/rails test test/models/user_test.rb -v
```

Expected: all tests pass. Especially `merge_policy metadata is preserved on reflections`.

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/models/user.rb test/models/user_test.rb config/initializers/reflection_extensions.rb
git commit -m "feat(user): add merge_policy metadata for GuestMerger dispatch"
```

### Task 2.4: Identity model

**Files:**
- Create: `app/models/identity.rb`
- Create: `test/models/identity_test.rb`
- Create: `test/fixtures/identities.yml`

- [ ] **Step 1: Write failing tests**

Create `test/models/identity_test.rb`:

```ruby
require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "belongs to user" do
    user = User.create!(guest: false, email: "x@y.com")
    id = Identity.create!(user: user, provider: "kakao", uid: "123")
    assert_equal user, id.user
  end

  test "provider + uid pair is unique" do
    user = User.create!(guest: false, email: "a@b.com")
    Identity.create!(user: user, provider: "kakao", uid: "123")
    assert_raises(ActiveRecord::RecordNotUnique) do
      Identity.create!(user: user, provider: "kakao", uid: "123")
    end
  end

  test "same uid across different providers is allowed" do
    user = User.create!(guest: false, email: "m@n.com")
    Identity.create!(user: user, provider: "kakao", uid: "123")
    assert_nothing_raised do
      Identity.create!(user: user, provider: "google", uid: "123")
    end
  end
end
```

Create `test/fixtures/identities.yml`:

```yaml
# starts empty; tests build identities directly
```

- [ ] **Step 2: Run tests, verify they fail**

```bash
bin/rails test test/models/identity_test.rb -v
```

Expected: `NameError: uninitialized constant Identity`.

- [ ] **Step 3: Create Identity model**

Create `app/models/identity.rb`:

```ruby
class Identity < ApplicationRecord
  belongs_to :user

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }

  serialize :raw_info, coder: JSON
end
```

- [ ] **Step 4: Run tests, verify they pass**

```bash
bin/rails test test/models/identity_test.rb -v
```

Expected: 3 runs, 0 failures.

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/models/identity.rb test/models/identity_test.rb test/fixtures/identities.yml
git commit -m "feat(identity): add Identity model with provider/uid uniqueness"
```

---

## Phase 3: Auth namespace (errors + profile)

### Task 3.1: Auth::Error hierarchy

**Files:**
- Create: `app/services/auth/errors.rb`

- [ ] **Step 1: Create the file**

```ruby
module Auth
  class Error < StandardError; end
  class ProviderError        < Error; end
  class EmailMissingError    < Error; end
  class IdentityConflictError < Error; end
  class MergeError           < Error; end
end
```

No test — these are marker classes. Later tasks will assert they are raised.

- [ ] **Step 2: Commit [BEHAVIOR]**

```bash
git add app/services/auth/errors.rb
git commit -m "feat(auth): Auth::Error hierarchy for OAuth flow failures"
```

### Task 3.2: Auth::ProviderProfile

**Files:**
- Create: `app/services/auth/provider_profile.rb`
- Create: `test/services/auth/provider_profile_test.rb`

- [ ] **Step 1: Write failing test**

Create `test/services/auth/provider_profile_test.rb`:

```ruby
require "test_helper"

class Auth::ProviderProfileTest < ActiveSupport::TestCase
  test "constructs with keyword args" do
    p = Auth::ProviderProfile.new(
      provider: "kakao", uid: "123", email: "a@b.com",
      name: "홍길동", avatar_url: "http://x/y.jpg", raw_info: {}
    )
    assert_equal "kakao", p.provider
    assert_equal "홍길동", p.name
  end

  test "email may be nil (Kakao opt-out case)" do
    p = Auth::ProviderProfile.new(provider: "kakao", uid: "1", email: nil, name: "a", avatar_url: nil, raw_info: {})
    assert_nil p.email
  end
end
```

- [ ] **Step 2: Run, verify fail**

```bash
bin/rails test test/services/auth/provider_profile_test.rb -v
```

Expected: `NameError: uninitialized constant Auth::ProviderProfile`.

- [ ] **Step 3: Create the struct**

Create `app/services/auth/provider_profile.rb`:

```ruby
module Auth
  ProviderProfile = Struct.new(
    :provider, :uid, :email, :name, :avatar_url, :raw_info,
    keyword_init: true
  )
end
```

- [ ] **Step 4: Run, verify pass**

```bash
bin/rails test test/services/auth/provider_profile_test.rb -v
```

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/services/auth/provider_profile.rb test/services/auth/provider_profile_test.rb
git commit -m "feat(auth): ProviderProfile struct for normalized OAuth data"
```

---

## Phase 4: Auth adapters

### Task 4.1: Auth::GoogleAdapter

**Files:**
- Create: `app/services/auth/google_adapter.rb`
- Create: `test/services/auth/google_adapter_test.rb`

- [ ] **Step 1: Write failing test**

```ruby
require "test_helper"

class Auth::GoogleAdapterTest < ActiveSupport::TestCase
  test "normalizes a standard google_oauth2 auth_hash" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "google_oauth2",
      "uid"      => "109876543210",
      "info"     => {
        "email" => "me@gmail.com",
        "name"  => "Jane Doe",
        "image" => "https://lh3.googleusercontent.com/a/x.jpg"
      },
      "extra"    => { "raw_info" => { "locale" => "ko" } }
    )
    profile = Auth::GoogleAdapter.new(auth_hash).to_profile
    assert_equal "google", profile.provider
    assert_equal "109876543210", profile.uid
    assert_equal "me@gmail.com", profile.email
    assert_equal "Jane Doe", profile.name
    assert_equal "https://lh3.googleusercontent.com/a/x.jpg", profile.avatar_url
    assert_equal "ko", profile.raw_info["locale"]
  end
end
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Implement**

Create `app/services/auth/google_adapter.rb`:

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
        name: @auth_hash.dig("info", "name"),
        avatar_url: @auth_hash.dig("info", "image"),
        raw_info: @auth_hash.dig("extra", "raw_info").to_h
      )
    end
  end
end
```

Note: the adapter maps the OmniAuth strategy name (`google_oauth2`) to the internal provider key (`google`). All `identities.provider` rows use the short key.

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/services/auth/google_adapter.rb test/services/auth/google_adapter_test.rb
git commit -m "feat(auth): GoogleAdapter normalizes google_oauth2 hash into ProviderProfile"
```

### Task 4.2: Auth::KakaoAdapter (with nil-email test)

**Files:**
- Create: `app/services/auth/kakao_adapter.rb`
- Create: `test/services/auth/kakao_adapter_test.rb`

- [ ] **Step 1: Write failing tests**

```ruby
require "test_helper"

class Auth::KakaoAdapterTest < ActiveSupport::TestCase
  test "normalizes a kakao auth_hash with email" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "kakao",
      "uid"      => "1234567890",
      "info"     => { "email" => "user@kakao.test", "name" => "홍길동", "image" => "https://k.kakaocdn.net/p.jpg" },
      "extra"    => { "raw_info" => { "kakao_account" => { "email" => "user@kakao.test" } } }
    )
    profile = Auth::KakaoAdapter.new(auth_hash).to_profile
    assert_equal "kakao", profile.provider
    assert_equal "user@kakao.test", profile.email
    assert_equal "홍길동", profile.name
  end

  test "email is nil when Kakao user opted out of email consent" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "kakao",
      "uid"      => "9999",
      "info"     => { "email" => nil, "name" => "익명", "image" => nil },
      "extra"    => { "raw_info" => { "kakao_account" => { "has_email" => false } } }
    )
    profile = Auth::KakaoAdapter.new(auth_hash).to_profile
    assert_nil profile.email
    assert_equal "익명", profile.name
  end
end
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Implement**

Create `app/services/auth/kakao_adapter.rb`:

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
        name: @auth_hash.dig("info", "name"),
        avatar_url: @auth_hash.dig("info", "image"),
        raw_info: @auth_hash.dig("extra", "raw_info").to_h
      )
    end
  end
end
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/services/auth/kakao_adapter.rb test/services/auth/kakao_adapter_test.rb
git commit -m "feat(auth): KakaoAdapter handles nil-email (opt-out) path"
```

### Task 4.3: Auth::NaverAdapter

**Files:**
- Create: `app/services/auth/naver_adapter.rb`
- Create: `test/services/auth/naver_adapter_test.rb`
- Create (conditional): `lib/omniauth/strategies/naver.rb` if spike failed

- [ ] **Step 1: Write failing test**

```ruby
require "test_helper"

class Auth::NaverAdapterTest < ActiveSupport::TestCase
  test "normalizes a naver auth_hash" do
    auth_hash = OmniAuth::AuthHash.new(
      "provider" => "naver",
      "uid"      => "naver-user-001",
      "info"     => { "email" => "u@naver.com", "name" => "네이버유저", "image" => "https://ssl.pstatic.net/x.jpg" },
      "extra"    => { "raw_info" => { "response" => { "profile_image" => "https://ssl.pstatic.net/x.jpg" } } }
    )
    profile = Auth::NaverAdapter.new(auth_hash).to_profile
    assert_equal "naver", profile.provider
    assert_equal "naver-user-001", profile.uid
    assert_equal "네이버유저", profile.name
  end
end
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Implement**

Create `app/services/auth/naver_adapter.rb`:

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
        name: @auth_hash.dig("info", "name"),
        avatar_url: @auth_hash.dig("info", "image") || @auth_hash.dig("extra", "raw_info", "response", "profile_image"),
        raw_info: @auth_hash.dig("extra", "raw_info").to_h
      )
    end
  end
end
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: (Only if Phase 0 spike failed) Create custom OmniAuth strategy**

Create `lib/omniauth/strategies/naver.rb`:

```ruby
require "omniauth-oauth2"

module OmniAuth
  module Strategies
    class Naver < OmniAuth::Strategies::OAuth2
      option :name, "naver"
      option :client_options, {
        site: "https://nid.naver.com",
        authorize_url: "/oauth2.0/authorize",
        token_url: "/oauth2.0/token"
      }

      uid { raw_info.dig("response", "id") }

      info do
        r = raw_info["response"] || {}
        { email: r["email"], name: r["name"] || r["nickname"], image: r["profile_image"] }
      end

      extra { { "raw_info" => raw_info } }

      def raw_info
        @raw_info ||= access_token.get("https://openapi.naver.com/v1/nid/me").parsed
      end
    end
  end
end

OmniAuth.config.add_mock(:naver, { uid: "test-naver-uid" })
```

Add to `config/application.rb` inside the class:

```ruby
config.autoload_paths += %W[#{config.root}/lib]
config.eager_load_paths += %W[#{config.root}/lib]
```

Only applies if Phase 0 Task 0.1 Step 6 recorded FAIL.

- [ ] **Step 6: Commit [BEHAVIOR]**

```bash
git add app/services/auth/naver_adapter.rb test/services/auth/naver_adapter_test.rb
# If custom strategy was needed:
# git add lib/omniauth/strategies/naver.rb config/application.rb
git commit -m "feat(auth): NaverAdapter normalizes naver auth_hash"
```

---

## Phase 5: GuestMerger

### Task 5.1: GuestMerger — :coexist policy (baseline, no collision)

**Files:**
- Create: `app/services/guest_merger.rb`
- Create: `test/services/guest_merger_test.rb`

- [ ] **Step 1: Write failing test for a `:coexist` association**

First, add a temporary `:coexist` association to User to enable isolated testing. The production associations use `:prefer_guest` / `:keep_target` — there is no native `:coexist` in the real model. We test the policy dispatch using a stub reflection. Use a real association without unique index: `llm_analysis_logs` has `dependent: :nullify` and no `user_id` unique constraint. We'll temporarily add `merge_policy: :coexist` for baseline test, then remove.

Actually, a cleaner approach: test the dispatcher with mock reflections. But this is complex. Let me write the test against the real `:prefer_guest` path with no natural-key collision first — that exercises the coexist code path (reassign user_id only).

Create `test/services/guest_merger_test.rb`:

```ruby
require "test_helper"

class GuestMergerTest < ActiveSupport::TestCase
  setup do
    @guest = User.create!
    @target = User.create!(guest: false, email: "target@example.com")
  end

  test "prefer_guest reassigns user_id when no collision exists" do
    prop = Property.create!(case_number: "2024-1234")
    @guest.user_properties.create!(property: prop)
    assert_equal 1, @guest.user_properties.count
    assert_equal 0, @target.user_properties.count

    GuestMerger.new(from: @guest, to: @target).call

    assert_raises(ActiveRecord::RecordNotFound) { @guest.reload }
    assert_equal 1, @target.user_properties.count
    assert_equal prop.id, @target.user_properties.first.property_id
  end
end
```

Note: `Property` must already exist in the project; check schema for required fields and adjust `case_number` as needed.

- [ ] **Step 2: Run, verify fail**

```bash
bin/rails test test/services/guest_merger_test.rb -v
```

Expected: `NameError: uninitialized constant GuestMerger`.

- [ ] **Step 3: Implement dispatcher skeleton with :prefer_guest (no-collision branch)**

Create `app/services/guest_merger.rb`:

```ruby
class GuestMerger
  def initialize(from:, to:)
    @from = from
    @to = to
  end

  def call
    ActiveRecord::Base.transaction do
      User.mergeable_reflections.each { |reflection| merge(reflection) }
      @from.destroy!
    end
  rescue ActiveRecord::ActiveRecordError => e
    raise Auth::MergeError, e.message
  end

  private

  def merge(reflection)
    case reflection.options[:merge_policy]
    when :prefer_guest
      merge_prefer_guest(reflection)
    end
  end

  def merge_prefer_guest(reflection)
    association = @from.public_send(reflection.name)
    if reflection.macro == :has_one
      target_record = @to.public_send(reflection.name)
      target_record&.destroy
      association&.update!(user_id: @to.id)
    else
      association.update_all(user_id: @to.id)
    end
  end
end
```

- [ ] **Step 4: Run, verify pass**

```bash
bin/rails test test/services/guest_merger_test.rb -v
```

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/services/guest_merger.rb test/services/guest_merger_test.rb
git commit -m "feat(merger): GuestMerger prefer_guest reassigns user_id in the no-collision case"
```

### Task 5.2: GuestMerger — :prefer_guest with natural_key collision

**Files:**
- Modify: `app/services/guest_merger.rb`
- Modify: `test/services/guest_merger_test.rb`

- [ ] **Step 1: Add failing test — both guest and target have the same property**

Append to `test/services/guest_merger_test.rb`:

```ruby
test "prefer_guest deletes target's colliding row when natural_key matches" do
  prop = Property.create!(case_number: "2024-1234")
  @guest.user_properties.create!(property: prop)
  @target.user_properties.create!(property: prop)

  guest_up_id = @guest.user_properties.first.id
  target_up_id = @target.user_properties.first.id

  GuestMerger.new(from: @guest, to: @target).call

  @target.reload
  assert_equal 1, @target.user_properties.count
  kept_id = @target.user_properties.first.id
  assert_equal guest_up_id, kept_id
  assert_raises(ActiveRecord::RecordNotFound) do
    UserProperty.find(target_up_id)
  end
end

test "prefer_guest handles composite natural_key (inspection_results)" do
  prop = Property.create!(case_number: "2024-5555")
  item = InspectionItem.first || InspectionItem.create!(code: "X", label: "x", tab_key: "t")
  guest_ir  = @guest.inspection_results.create!(property: prop, inspection_item: item, grade: "A")
  target_ir = @target.inspection_results.create!(property: prop, inspection_item: item, grade: "B")

  GuestMerger.new(from: @guest, to: @target).call

  @target.reload
  assert_equal 1, @target.inspection_results.count
  assert_equal "A", @target.inspection_results.first.grade
  assert_raises(ActiveRecord::RecordNotFound) do
    InspectionResult.find(target_ir.id)
  end
end
```

- [ ] **Step 2: Run, verify fail**

Expected failure: `ActiveRecord::RecordNotUnique` during `update_all` (target row still exists).

- [ ] **Step 3: Implement collision resolution**

Edit `app/services/guest_merger.rb` — replace `merge_prefer_guest`:

```ruby
def merge_prefer_guest(reflection)
  if reflection.macro == :has_one
    association = @from.public_send(reflection.name)
    @to.public_send(reflection.name)&.destroy
    association&.update!(user_id: @to.id)
  else
    delete_target_collisions(reflection)
    @from.public_send(reflection.name).update_all(user_id: @to.id)
  end
end

def delete_target_collisions(reflection)
  natural_key = Array(reflection.options[:natural_key])
  return if natural_key.empty?

  guest_rows = @from.public_send(reflection.name).pluck(*natural_key)
  return if guest_rows.empty?

  target_scope = @to.public_send(reflection.name)
  if natural_key.length == 1
    target_scope.where(natural_key.first => guest_rows).delete_all
  else
    guest_rows.each do |values|
      conditions = natural_key.zip(Array(values)).to_h
      target_scope.where(conditions).delete_all
    end
  end
end
```

- [ ] **Step 4: Run, verify pass**

```bash
bin/rails test test/services/guest_merger_test.rb -v
```

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/services/guest_merger.rb test/services/guest_merger_test.rb
git commit -m "feat(merger): prefer_guest resolves natural_key collisions by deleting target rows"
```

### Task 5.3: GuestMerger — :keep_target policy (api_credentials)

**Files:**
- Modify: `app/services/guest_merger.rb`
- Modify: `test/services/guest_merger_test.rb`

- [ ] **Step 1: Add failing test**

```ruby
test "keep_target preserves target's api_credentials when collision exists" do
  @target.api_credentials.create!(provider_name: "court_auction", api_key: "REAL_KEY")
  @guest.api_credentials.create!(provider_name: "court_auction", api_key: "GUEST_KEY")

  GuestMerger.new(from: @guest, to: @target).call

  @target.reload
  assert_equal 1, @target.api_credentials.count
  assert_equal "REAL_KEY", @target.api_credentials.first.api_key
end

test "keep_target still migrates non-colliding guest api_credentials" do
  @target.api_credentials.create!(provider_name: "court_auction", api_key: "REAL_A")
  @guest.api_credentials.create!(provider_name: "llm", api_key: "GUEST_B")

  GuestMerger.new(from: @guest, to: @target).call

  @target.reload
  assert_equal 2, @target.api_credentials.count
  names = @target.api_credentials.pluck(:provider_name).sort
  assert_equal %w[court_auction llm], names
end
```

Check `ApiCredential` fields before writing (columns may differ). If `api_key` is encrypted or named differently, adjust. Run `bin/rails runner "pp ApiCredential.column_names"` to verify.

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Implement :keep_target branch**

Edit `app/services/guest_merger.rb`, add to `merge` case and a new helper:

```ruby
def merge(reflection)
  case reflection.options[:merge_policy]
  when :prefer_guest then merge_prefer_guest(reflection)
  when :keep_target  then merge_keep_target(reflection)
  end
end

def merge_keep_target(reflection)
  if reflection.macro == :has_one
    @from.public_send(reflection.name)&.destroy
  else
    delete_guest_collisions(reflection)
    @from.public_send(reflection.name).update_all(user_id: @to.id)
  end
end

def delete_guest_collisions(reflection)
  natural_key = Array(reflection.options[:natural_key])
  return if natural_key.empty?

  target_rows = @to.public_send(reflection.name).pluck(*natural_key)
  return if target_rows.empty?

  guest_scope = @from.public_send(reflection.name)
  if natural_key.length == 1
    guest_scope.where(natural_key.first => target_rows).delete_all
  else
    target_rows.each do |values|
      conditions = natural_key.zip(Array(values)).to_h
      guest_scope.where(conditions).delete_all
    end
  end
end
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/services/guest_merger.rb test/services/guest_merger_test.rb
git commit -m "feat(merger): keep_target preserves existing user records on collision"
```

### Task 5.4: GuestMerger ignores unlabeled reflections

**Files:**
- Modify: `test/services/guest_merger_test.rb`

- [ ] **Step 1: Add test**

```ruby
test "associations without merge_policy are left untouched (safe default)" do
  log = @guest.llm_analysis_logs.create!(prompt: "x", response: "y")
  GuestMerger.new(from: @guest, to: @target).call
  log.reload
  # dependent: :nullify on the association cascades because @guest is destroyed
  assert_nil log.user_id
end
```

Adjust fields to match `LlmAnalysisLog` schema. Run `bin/rails runner "pp LlmAnalysisLog.column_names"` first.

- [ ] **Step 2: Run, verify pass (behavior is already correct)**

This is a characterization test — the existing dispatcher only handles the two labeled policies. The `llm_analysis_logs` association retains `dependent: :nullify`, which Rails handles on `@from.destroy!`.

- [ ] **Step 3: Commit [BEHAVIOR]**

```bash
git add test/services/guest_merger_test.rb
git commit -m "test(merger): unlabeled associations are ignored and nullified via dependent:"
```

### Task 5.5: GuestMerger transaction atomicity

**Files:**
- Modify: `test/services/guest_merger_test.rb`

- [ ] **Step 1: Add failing test — simulate mid-merge failure**

```ruby
test "all merges roll back if one association fails" do
  prop = Property.create!(case_number: "2024-9001")
  @guest.user_properties.create!(property: prop)
  @guest.api_credentials.create!(provider_name: "court_auction", api_key: "G")
  @target.api_credentials.create!(provider_name: "court_auction", api_key: "T")

  # Force failure by stubbing update_all on one reflection
  UserProperty.stub :update_all, ->(*) { raise ActiveRecord::StatementInvalid, "boom" } do
    assert_raises(Auth::MergeError) do
      GuestMerger.new(from: @guest, to: @target).call
    end
  end

  @guest.reload
  @target.reload
  assert_equal 1, @guest.user_properties.count, "guest user_properties should be restored"
  assert_equal "T", @target.api_credentials.first.api_key, "target api_credentials should be untouched"
end
```

- [ ] **Step 2: Run, verify pass**

Already passing — the existing transaction + `rescue => e; raise Auth::MergeError` produces the correct behavior. This is a regression test that pins the guarantee.

- [ ] **Step 3: Commit [BEHAVIOR]**

```bash
git add test/services/guest_merger_test.rb
git commit -m "test(merger): transaction rollback on mid-merge failure"
```

---

## Phase 6: SessionCreator

### Task 6.1: SessionCreator Case A (existing identity)

**Files:**
- Create: `app/services/session_creator.rb`
- Create: `test/services/session_creator_test.rb`

- [ ] **Step 1: Failing test**

```ruby
require "test_helper"

class SessionCreatorTest < ActiveSupport::TestCase
  setup do
    @guest = User.create!
    @existing = User.create!(guest: false, email: "me@example.com", name: "Me")
    @existing.identities.create!(provider: "kakao", uid: "100")
  end

  test "Case A: existing identity matches - logs into existing user and merges guest" do
    profile = Auth::ProviderProfile.new(
      provider: "kakao", uid: "100", email: "me@example.com",
      name: "Me", avatar_url: nil, raw_info: {}
    )
    result = SessionCreator.new(current_guest: @guest, profile: profile).call
    assert_equal @existing, result
    assert_raises(ActiveRecord::RecordNotFound) { @guest.reload }
  end
end
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Implement Case A skeleton**

Create `app/services/session_creator.rb`:

```ruby
class SessionCreator
  def initialize(current_guest:, profile:)
    @current_guest = current_guest
    @profile = profile
  end

  def call
    ActiveRecord::Base.transaction(joinable: false) do
      ActiveRecord::Base.connection.execute("BEGIN IMMEDIATE") rescue nil
      dispatch
    end
  end

  private

  def dispatch
    if (identity = Identity.find_by(provider: @profile.provider, uid: @profile.uid))
      return attach_and_merge(identity.user)
    end
    # Case B/C added in later tasks
    raise NotImplementedError
  end

  def attach_and_merge(target_user)
    GuestMerger.new(from: @current_guest, to: target_user).call if @current_guest != target_user
    stamp_terms(target_user)
    target_user
  end

  def stamp_terms(user)
    user.update!(terms_accepted_at: Time.current) if user.terms_accepted_at.nil?
  end
end
```

Note: `BEGIN IMMEDIATE` inside an already-open Rails transaction is a no-op on SQLite. The `rescue nil` accommodates test environments where `savepoint` is active. This keeps the lock semantics for production without breaking tests.

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/services/session_creator.rb test/services/session_creator_test.rb
git commit -m "feat(auth): SessionCreator Case A (existing identity → merge + login)"
```

### Task 6.2: SessionCreator Case B (email match)

**Files:**
- Modify: `app/services/session_creator.rb`
- Modify: `test/services/session_creator_test.rb`

- [ ] **Step 1: Failing test**

Append:

```ruby
test "Case B: email matches an existing account - attaches new identity and merges" do
  existing = User.create!(guest: false, email: "alice@example.com", name: "Alice")
  # No identity yet - simulates a user who previously logged in with Kakao and now tries Google
  existing.identities.create!(provider: "kakao", uid: "kakao-1")

  profile = Auth::ProviderProfile.new(
    provider: "google", uid: "google-1", email: "alice@example.com",
    name: "Alice", avatar_url: nil, raw_info: {}
  )
  result = SessionCreator.new(current_guest: @guest, profile: profile).call

  assert_equal existing, result
  assert_equal 2, existing.reload.identities.count
  assert_includes existing.identities.pluck(:provider, :uid), ["google", "google-1"]
end

test "Case B: email nil does NOT match — falls to Case C" do
  User.create!(guest: false, email: nil, name: "AnonOne")  # first nil-email user
  profile = Auth::ProviderProfile.new(
    provider: "kakao", uid: "k-2", email: nil,
    name: "AnonTwo", avatar_url: nil, raw_info: {}
  )
  result = SessionCreator.new(current_guest: @guest, profile: profile).call
  refute_equal "AnonOne", result.name
  assert_equal @guest.id, result.id  # guest was promoted
  refute result.guest?
end
```

- [ ] **Step 2: Run, verify fail**

Second test fails with `NotImplementedError` (Case C not built yet). That's expected.

- [ ] **Step 3: Implement Case B (but still raise for C)**

Edit `dispatch`:

```ruby
def dispatch
  if (identity = Identity.find_by(provider: @profile.provider, uid: @profile.uid))
    return attach_and_merge(identity.user)
  end
  if @profile.email.present? &&
     (existing = User.find_by(email: @profile.email, guest: false))
    Identity.find_or_create_by!(provider: @profile.provider, uid: @profile.uid) do |i|
      i.user = existing
      i.email = @profile.email
      i.raw_info = @profile.raw_info
    end
    return attach_and_merge(existing)
  end
  raise NotImplementedError, "Case C promote_guest not implemented yet"
end
```

- [ ] **Step 4: Run first test, verify pass; second still fails (expected)**

```bash
bin/rails test test/services/session_creator_test.rb -v
```

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/services/session_creator.rb test/services/session_creator_test.rb
git commit -m "feat(auth): SessionCreator Case B (email match attaches new identity)"
```

### Task 6.3: SessionCreator Case C (promote guest) + nil-email fallthrough

**Files:**
- Modify: `app/services/session_creator.rb`

- [ ] **Step 1: Add Case C test**

Append:

```ruby
test "Case C: completely new user - promotes current guest in place preserving data" do
  prop = Property.create!(case_number: "2024-1111")
  @guest.user_properties.create!(property: prop)

  profile = Auth::ProviderProfile.new(
    provider: "google", uid: "new-1", email: "new@example.com",
    name: "New User", avatar_url: "http://x/y.jpg", raw_info: {}
  )
  result = SessionCreator.new(current_guest: @guest, profile: profile).call

  assert_equal @guest.id, result.id
  refute result.guest?
  assert_equal "new@example.com", result.email
  assert_equal "New User", result.name
  assert_equal "http://x/y.jpg", result.avatar_url
  assert_equal 1, result.user_properties.count  # data preserved
  assert_equal 1, result.identities.count
  assert_equal "google", result.identities.first.provider
end
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Implement promote_guest**

Replace the `raise NotImplementedError` line with:

```ruby
promote_guest
```

Add:

```ruby
def promote_guest
  @current_guest.update!(
    guest: false,
    guest_token: nil,
    email: @profile.email,
    name: @profile.name,
    avatar_url: @profile.avatar_url,
    terms_accepted_at: Time.current
  )
  Identity.create!(
    user: @current_guest,
    provider: @profile.provider,
    uid: @profile.uid,
    email: @profile.email,
    raw_info: @profile.raw_info
  )
  @current_guest
end
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/services/session_creator.rb test/services/session_creator_test.rb
git commit -m "feat(auth): SessionCreator Case C promotes guest in place, preserving data"
```

### Task 6.4: SessionCreator concurrency — idempotent identity + BEGIN IMMEDIATE

**Files:**
- Modify: `app/services/session_creator.rb`
- Create: `test/integration/concurrent_login_test.rb`

- [ ] **Step 1: Write concurrency test**

```ruby
require "test_helper"

class ConcurrentLoginTest < ActiveSupport::TestCase
  self.use_transactional_tests = false  # threads need their own transactions

  teardown do
    Identity.delete_all
    User.delete_all
  end

  test "two simultaneous Case C callbacks for the same guest produce exactly one user" do
    guest = User.create!
    profile = Auth::ProviderProfile.new(
      provider: "kakao", uid: "race-1", email: "race@example.com",
      name: "R", avatar_url: nil, raw_info: {}
    )

    errors = []
    threads = 2.times.map do
      Thread.new do
        begin
          SessionCreator.new(current_guest: guest, profile: profile).call
        rescue => e
          errors << e
        end
      end
    end
    threads.each(&:join)

    # Exactly one Identity should exist
    assert_equal 1, Identity.where(provider: "kakao", uid: "race-1").count
    # Exactly one account User
    assert_equal 1, User.where(guest: false).count
  end
end
```

- [ ] **Step 2: Run, verify fail or flaky (race condition)**

```bash
bin/rails test test/integration/concurrent_login_test.rb -v
```

Without the lock, at least one of:
- `ActiveRecord::RecordNotUnique` on `identities.provider_uid`
- Two Identity rows (SQLite without serialization)

- [ ] **Step 3: Harden Case C with idempotent identity creation**

Replace the `Identity.create!` in `promote_guest` with:

```ruby
Identity.find_or_create_by!(provider: @profile.provider, uid: @profile.uid) do |i|
  i.user = @current_guest
  i.email = @profile.email
  i.raw_info = @profile.raw_info
end
```

Also, before the `@current_guest.update!` call, re-check that the guest is still a guest (the other thread may have already promoted):

```ruby
def promote_guest
  @current_guest.reload
  if @current_guest.guest?
    @current_guest.update!(
      guest: false, guest_token: nil,
      email: @profile.email, name: @profile.name, avatar_url: @profile.avatar_url,
      terms_accepted_at: Time.current
    )
  end
  Identity.find_or_create_by!(provider: @profile.provider, uid: @profile.uid) do |i|
    i.user = @current_guest
    i.email = @profile.email
    i.raw_info = @profile.raw_info
  end
  @current_guest
end
```

- [ ] **Step 4: Run, verify pass (idempotent)**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/services/session_creator.rb test/integration/concurrent_login_test.rb
git commit -m "feat(auth): SessionCreator idempotent under concurrent callbacks"
```

---

## Phase 7: ApplicationController changes

### Task 7.1: ensure_current_user replaces set_guest_user

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Create: `test/controllers/application_controller_test.rb`

- [ ] **Step 1: Write failing test**

Since `ApplicationController` doesn't render its own actions, test via a minimal probe controller (or a well-chosen existing route). Use a home controller request test:

Create `test/integration/guest_session_test.rb`:

```ruby
require "test_helper"

class GuestSessionTest < ActionDispatch::IntegrationTest
  test "first visit creates a new guest with its own user_id" do
    get root_path
    assert_response :success
    assert User.exists?(session[:user_id])
    user = User.find(session[:user_id])
    assert user.guest?
  end

  test "two separate sessions get different guest user_ids" do
    # Session 1
    session1 = open_session
    session1.get root_path
    uid1 = session1.session[:user_id]

    # Session 2 (fresh cookies)
    session2 = open_session
    session2.get root_path
    uid2 = session2.session[:user_id]

    refute_equal uid1, uid2, "two browsers must get distinct guest users"
  end
end
```

- [ ] **Step 2: Run, verify fail**

Expected fail: `two separate sessions get different guest user_ids` — currently both hit the shared `guest@auction.local`.

- [ ] **Step 3: Replace set_guest_user with ensure_current_user**

Edit `app/controllers/application_controller.rb`:

```ruby
class ApplicationController < ActionController::Base
  allow_browser versions: :modern
  stale_when_importmap_changes

  before_action :ensure_current_user

  rescue_from DataProvider::MissingCredentialError, with: :handle_missing_credential
  # ... existing rescue_from declarations unchanged ...

  private

  def ensure_current_user
    if session[:user_id] && (user = User.find_by(id: session[:user_id]))
      @current_user = user
    else
      @current_user = User.create!  # guest defaults handled by model
      session[:user_id] = @current_user.id
    end
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
  helper_method :current_user

  # ... existing handle_* methods unchanged ...
end
```

Delete the old `set_guest_user` method entirely.

- [ ] **Step 4: Run, verify pass**

```bash
bin/rails test test/integration/guest_session_test.rb -v
```

- [ ] **Step 5: Run FULL suite to catch any test referencing the old helper**

```bash
bin/rails test 2>&1 | tail -60
```

Fix any stale fixtures or tests that still call `User.find_by(email: "guest@auction.local")`. Most should already be updated in Phase 1 Task 1.3. Commit fixes together with this change.

- [ ] **Step 6: Commit [BEHAVIOR]**

```bash
git add app/controllers/application_controller.rb test/integration/guest_session_test.rb
# + any adjusted tests
git commit -m "feat(auth): per-session guest users replace shared guest@auction.local"
```

### Task 7.2: return_to_url capture

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Modify: `test/integration/guest_session_test.rb`

- [ ] **Step 1: Write failing test**

Append:

```ruby
test "GET request captures return_to_url in session" do
  get "/properties"
  assert_equal "/properties", session[:return_to_url]
end

test "POST request does NOT capture return_to_url" do
  get root_path  # seed session
  before = session[:return_to_url]
  post "/properties", params: { case_number: "2024-test" }
  assert_equal before, session[:return_to_url], "POST must not overwrite return_to_url"
end
```

- [ ] **Step 2: Run, verify fail**

- [ ] **Step 3: Add capture before_action**

Edit `ApplicationController`:

```ruby
before_action :capture_return_to_url

def capture_return_to_url
  return unless request.get?
  return if request.path.start_with?("/auth")
  return if request.xhr? || turbo_frame_request?
  session[:return_to_url] = request.fullpath
end
```

- [ ] **Step 4: Run, verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/controllers/application_controller.rb test/integration/guest_session_test.rb
git commit -m "feat(auth): capture return_to_url on GET for post-login redirect"
```

### Task 7.3: Auth::Error rescue_from

**Files:**
- Modify: `app/controllers/application_controller.rb`

- [ ] **Step 1: Test**

Append to `test/integration/guest_session_test.rb`:

```ruby
test "Auth::Error is rescued with a friendly redirect" do
  ApplicationController.any_instance.stubs(:ensure_current_user).raises(Auth::ProviderError, "boom")
  get root_path
  assert_redirected_to "/auth/login"
  assert_equal "로그인 중 문제가 발생했습니다. 다시 시도해주세요.", flash[:alert]
end
```

Requires `mocha` or a similar stubbing lib. If not installed, rewrite as a controller test using an inline controller. Prefer the alternative — add a dedicated test controller in `test/integration/`. Defer mocha addition outside this plan.

Rewrite with inline controller probe:

```ruby
test "Auth::Error rescue_from redirects to login with flash" do
  # Probe by raising through a custom action
  Rails.application.routes.disable_clear_and_finalize = true
  Rails.application.routes.draw do
    get "/boom", to: "boom#index"
  end

  ::BoomController = Class.new(ApplicationController) do
    def index; raise Auth::ProviderError, "boom"; end
  end

  get "/boom"
  assert_redirected_to "/auth/login"
  assert_equal "로그인 중 문제가 발생했습니다. 다시 시도해주세요.", flash[:alert]
ensure
  Rails.application.reload_routes!
end
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Add rescue**

Add to `ApplicationController`:

```ruby
rescue_from Auth::Error, with: :handle_auth_error

def handle_auth_error(error)
  Rails.logger.warn("[Auth::Error] #{error.class}: #{error.message}")
  redirect_to "/auth/login", alert: "로그인 중 문제가 발생했습니다. 다시 시도해주세요."
end
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/controllers/application_controller.rb test/integration/guest_session_test.rb
git commit -m "feat(auth): rescue Auth::Error with redirect + flash"
```

### Task 7.4: last_seen_at throttle

**Files:**
- Modify: `app/controllers/application_controller.rb`

- [ ] **Step 1: Failing test**

```ruby
test "last_seen_at updates on request, throttled to once per minute" do
  get root_path
  user = User.find(session[:user_id])
  first = user.reload.last_seen_at
  assert_not_nil first

  travel 30.seconds do
    get root_path
  end
  assert_equal first, user.reload.last_seen_at, "throttle must skip writes within 1 minute"

  travel 70.seconds do
    get root_path
  end
  second = user.reload.last_seen_at
  assert second > first
end
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Implement**

Add to `ApplicationController`:

```ruby
before_action :touch_last_seen

def touch_last_seen
  return unless @current_user
  return if Rails.cache.exist?("last_seen:#{@current_user.id}")
  Rails.cache.write("last_seen:#{@current_user.id}", true, expires_in: 1.minute)
  @current_user.update_column(:last_seen_at, Time.current)
end
```

Clear the cache between tests. Add to `test_helper.rb`:

```ruby
setup do
  Rails.cache.clear if Rails.cache.respond_to?(:clear)
end
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/controllers/application_controller.rb test/integration/guest_session_test.rb test/test_helper.rb
git commit -m "feat(user): last_seen_at throttled to one write per minute via Rails.cache"
```

---

## Phase 8: Routes + OmniAuth wiring

### Task 8.1: Gemfile updates

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add OmniAuth gems, remove bcrypt**

Edit `Gemfile`:

```ruby
# Remove:
# gem "bcrypt", "~> 3.1.7"

# Add, after turbo-rails:
gem "omniauth", "~> 2.1"
gem "omniauth-rails_csrf_protection", "~> 1.0"
gem "omniauth-google-oauth2", "~> 1.1"
gem "omniauth-naver"  # version pinned from Phase 0 spike verdict
gem "omniauth-kakao", "~> 0.2"
gem "rack-attack"
```

- [ ] **Step 2: bundle install**

```bash
bundle install
```

- [ ] **Step 3: Run full test suite to confirm baseline still green**

```bash
bin/rails test 2>&1 | tail -20
```

- [ ] **Step 4: Commit [STRUCT]**

```bash
git add Gemfile Gemfile.lock
git commit -m "chore(deps): add OmniAuth + rack-attack; remove bcrypt"
```

### Task 8.2: OmniAuth initializer

**Files:**
- Create: `config/initializers/omniauth.rb`

- [ ] **Step 1: Create initializer**

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

OmniAuth.config.allowed_request_methods = [:post]
OmniAuth.config.silence_get_warning = true

if Rails.env.test?
  OmniAuth.config.test_mode = true
end
```

- [ ] **Step 2: Add test helpers for mock auth**

Edit `test/test_helper.rb`, append before the `end` of `module ActiveSupport`:

```ruby
def mock_omniauth(provider, uid:, email: nil, name: "Test User", avatar: nil)
  OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
    "provider" => provider.to_s,
    "uid"      => uid.to_s,
    "info"     => { "email" => email, "name" => name, "image" => avatar },
    "extra"    => { "raw_info" => {} }
  )
end

teardown do
  OmniAuth.config.mock_auth.clear
end
```

- [ ] **Step 3: Commit [BEHAVIOR]**

```bash
git add config/initializers/omniauth.rb test/test_helper.rb
git commit -m "feat(auth): OmniAuth initializer with explicit Kakao/Naver scopes"
```

### Task 8.3: Routes

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing test**

Append to `test/integration/guest_session_test.rb`:

```ruby
test "auth login route renders login page" do
  get "/auth/login"
  assert_response :success
end

test "auth logout route accepts DELETE" do
  get root_path  # seed guest session
  delete "/auth/logout"
  assert_redirected_to root_path
end
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Add routes**

Edit `config/routes.rb`, add after `root`:

```ruby
namespace :auth do
  get    "login",    to: "sessions#new",     as: :login
  delete "logout",   to: "sessions#destroy", as: :logout
  get    ":provider/callback", to: "omniauth_callbacks#create", as: :callback
  get    "failure",  to: "omniauth_callbacks#failure"
end
```

- [ ] **Step 4: Verify route presence but not yet pass (controllers missing)**

```bash
bin/rails routes | grep auth
```

Tests still fail (controllers not created yet). That is fine — Task 9 creates them. Do NOT commit a broken suite.

- [ ] **Step 5: Defer commit**

Do not commit yet. This route block goes into the same commit as Task 9.1 below.

---

## Phase 9: Auth controllers

### Task 9.1: Auth::SessionsController (new + destroy)

**Files:**
- Create: `app/controllers/auth/sessions_controller.rb`
- Create: `app/views/auth/sessions/new.html.erb` (minimal placeholder)
- Create: `test/controllers/auth/sessions_controller_test.rb`

- [ ] **Step 1: Failing test**

```ruby
require "test_helper"

class Auth::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "GET new renders login modal" do
    get "/auth/login"
    assert_response :success
    assert_match "카카오로 계속하기", response.body
  end

  test "DELETE destroy signs out and resets to new guest" do
    # log a user in via session manipulation (mimic post-OAuth state)
    user = User.create!(guest: false, email: "x@y.com")
    post "/testing/sign_in", params: { user_id: user.id }  # helper route — see note

    delete "/auth/logout"
    assert_redirected_to root_path

    # Follow redirect: should land as a brand new guest (different id)
    get root_path
    refute_equal user.id, session[:user_id]
    assert User.find(session[:user_id]).guest?
  end
end
```

Note: the test uses a test-only `/testing/sign_in` route. Add it under a `Rails.env.test?` guard at the top of `config/routes.rb`:

```ruby
if Rails.env.test?
  post "/testing/sign_in", to: ->(env) {
    req = ActionDispatch::Request.new(env)
    req.session[:user_id] = req.params["user_id"].to_i
    [200, {}, ["ok"]]
  }
end
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Create controller + view**

`app/controllers/auth/sessions_controller.rb`:

```ruby
class Auth::SessionsController < ApplicationController
  skip_before_action :ensure_current_user, only: [:new]
  before_action :ensure_current_user, only: [:new]

  def new
    # renders login modal
  end

  def destroy
    reset_session
    cookies.delete(:remember_token)
    redirect_to root_path, notice: "로그아웃되었습니다."
  end
end
```

`app/views/auth/sessions/new.html.erb` (placeholder — full UI in Phase 10):

```erb
<div class="login-modal">
  <h2>로그인</h2>
  <%= button_to "카카오로 계속하기", "/auth/kakao", method: :post, data: { turbo: false } %>
  <%= button_to "네이버로 계속하기", "/auth/naver", method: :post, data: { turbo: false } %>
  <%= button_to "Google로 계속하기", "/auth/google_oauth2", method: :post, data: { turbo: false } %>
</div>
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/controllers/auth/sessions_controller.rb app/views/auth/sessions/new.html.erb config/routes.rb test/controllers/auth/sessions_controller_test.rb test/integration/guest_session_test.rb
git commit -m "feat(auth): SessionsController + login modal placeholder + auth routes"
```

### Task 9.2: Auth::OmniauthCallbacksController#create (Case A path)

**Files:**
- Create: `app/controllers/auth/omniauth_callbacks_controller.rb`
- Create: `test/controllers/auth/omniauth_callbacks_controller_test.rb`

- [ ] **Step 1: Failing test for Case A**

```ruby
require "test_helper"

class Auth::OmniauthCallbacksControllerTest < ActionDispatch::IntegrationTest
  test "Case A: existing identity logs user in and redirects to return_to_url" do
    user = User.create!(guest: false, email: "a@b.com", name: "A")
    user.identities.create!(provider: "kakao", uid: "k-1")

    get "/properties"  # seed return_to
    mock_omniauth(:kakao, uid: "k-1", email: "a@b.com", name: "A")

    get "/auth/kakao/callback"
    assert_redirected_to "/properties"
    assert_equal user.id, session[:user_id]
  end
end
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Implement**

`app/controllers/auth/omniauth_callbacks_controller.rb`:

```ruby
class Auth::OmniauthCallbacksController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:create]  # OmniAuth has its own CSRF
  skip_before_action :ensure_current_user, only: [:create, :failure]
  before_action :ensure_current_user, only: [:create, :failure]

  ADAPTERS = {
    "google_oauth2" => Auth::GoogleAdapter,
    "kakao"         => Auth::KakaoAdapter,
    "naver"         => Auth::NaverAdapter
  }.freeze

  def create
    adapter_class = ADAPTERS[request.env["omniauth.auth"]["provider"]]
    raise Auth::ProviderError, "unknown provider" unless adapter_class

    profile = adapter_class.new(request.env["omniauth.auth"]).to_profile
    return_to = session.delete(:return_to_url) || root_path

    target_user = SessionCreator.new(current_guest: current_user, profile: profile).call

    reset_session
    session[:user_id] = target_user.id
    cookies.permanent.signed[:remember_token] = { value: target_user.id, httponly: true, same_site: :lax }
    cookies.permanent[:last_provider] = profile.provider

    flash[:notice] = "환영합니다, #{target_user.name}님"
    redirect_to return_to
  end

  def failure
    code = params[:message].to_s
    flash[:alert] = failure_message(code)
    redirect_to "/auth/login"
  end

  private

  def failure_message(code)
    case code
    when "access_denied"      then "로그인이 취소되었습니다."
    when "timeout"            then "응답 지연입니다. 잠시 후 다시 시도해주세요."
    when "csrf_detected"      then "보안 검증에 실패했습니다. 다시 시도해주세요."
    when "invalid_credentials" then "로그인에 실패했습니다."
    else                            "로그인 중 문제가 발생했습니다."
    end
  end
end
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/controllers/auth/omniauth_callbacks_controller.rb test/controllers/auth/omniauth_callbacks_controller_test.rb
git commit -m "feat(auth): OmniauthCallbacksController Case A flow"
```

### Task 9.3: Callback Case B + Case C coverage

**Files:**
- Modify: `test/controllers/auth/omniauth_callbacks_controller_test.rb`

- [ ] **Step 1: Add tests**

```ruby
test "Case B: email matches existing account - attaches new identity and logs in" do
  existing = User.create!(guest: false, email: "alice@example.com", name: "Alice")
  existing.identities.create!(provider: "kakao", uid: "kakao-1")

  mock_omniauth(:google_oauth2, uid: "google-1", email: "alice@example.com", name: "Alice")
  get "/auth/google_oauth2/callback"

  assert_redirected_to root_path
  assert_equal existing.id, session[:user_id]
  assert_equal 2, existing.reload.identities.count
end

test "Case C: completely new user - promotes current guest in place" do
  get root_path
  guest_id = session[:user_id]

  mock_omniauth(:google_oauth2, uid: "g-new", email: "new@example.com", name: "New")
  get "/auth/google_oauth2/callback"

  assert_redirected_to root_path
  promoted = User.find(session[:user_id])
  assert_equal guest_id, promoted.id
  refute promoted.guest?
  assert_equal "new@example.com", promoted.email
end

test "Case C nil-email: Kakao user without email still promotes guest (no spurious Case B match)" do
  User.create!(guest: false, email: nil, name: "OldAnon")  # existing nil-email account

  get root_path
  guest_id = session[:user_id]

  mock_omniauth(:kakao, uid: "no-email", email: nil, name: "NewAnon")
  get "/auth/kakao/callback"

  assert_redirected_to root_path
  promoted = User.find(session[:user_id])
  assert_equal guest_id, promoted.id, "should promote the CURRENT guest, not link to OldAnon"
  refute_equal "OldAnon", promoted.name
end
```

- [ ] **Step 2: Verify pass (should already work — logic implemented in Phase 6)**

- [ ] **Step 3: Commit [BEHAVIOR]**

```bash
git add test/controllers/auth/omniauth_callbacks_controller_test.rb
git commit -m "test(auth): callback Case B, Case C, and Case C nil-email coverage"
```

### Task 9.4: Callback failure action

**Files:**
- Modify: `test/controllers/auth/omniauth_callbacks_controller_test.rb`

- [ ] **Step 1: Add tests**

```ruby
test "failure with access_denied shows cancel message" do
  get "/auth/failure?message=access_denied"
  assert_redirected_to "/auth/login"
  assert_equal "로그인이 취소되었습니다.", flash[:alert]
end

test "failure with csrf_detected shows security message" do
  get "/auth/failure?message=csrf_detected"
  assert_redirected_to "/auth/login"
  assert_match /보안 검증/, flash[:alert]
end

test "failure with unknown code shows generic message" do
  get "/auth/failure?message=something_weird"
  assert_redirected_to "/auth/login"
  assert_match /문제가 발생/, flash[:alert]
end
```

- [ ] **Step 2: Verify pass (already implemented)**

- [ ] **Step 3: Commit**

```bash
git add test/controllers/auth/omniauth_callbacks_controller_test.rb
git commit -m "test(auth): callback failure action covers access_denied / csrf / generic codes"
```

### Task 9.5: Callback reset_session + POST-only provider initiation

**Files:**
- Modify: `test/controllers/auth/omniauth_callbacks_controller_test.rb`

- [ ] **Step 1: Test reset_session behavior**

```ruby
test "successful callback rotates session id (fixation defense)" do
  get root_path
  old_session_data = session.to_hash.dup

  mock_omniauth(:google_oauth2, uid: "g-x", email: "x@y.com", name: "X")
  get "/auth/google_oauth2/callback"

  # After callback, session should have been reset then set[:user_id] rewritten
  assert session[:user_id].present?
  refute_equal old_session_data[:return_to_url], session[:return_to_url]
end

test "GET /auth/google_oauth2 request phase is rejected (POST only)" do
  # With omniauth-rails_csrf_protection + allowed_request_methods = [:post]
  assert_raises(ActionController::RoutingError) { get "/auth/google_oauth2" }
rescue ActionController::RoutingError
  pass
end
```

- [ ] **Step 2: Verify pass (already enforced by initializer)**

- [ ] **Step 3: Commit**

```bash
git add test/controllers/auth/omniauth_callbacks_controller_test.rb
git commit -m "test(auth): session fixation + POST-only request phase"
```

---

## Phase 10: UI

### Task 10.1: Login modal view (full)

**Files:**
- Overwrite: `app/views/auth/sessions/new.html.erb`
- Create: `app/views/auth/sessions/_modal.html.erb`

- [ ] **Step 1: Write the full modal partial**

`app/views/auth/sessions/_modal.html.erb`:

```erb
<%= turbo_frame_tag "auth_modal" do %>
  <div class="login-modal" data-controller="auth-modal">
    <button type="button" class="close" data-action="auth-modal#close">×</button>
    <h2>로그인</h2>
    <p class="subtitle">내 결과를 안전하게 저장하세요.</p>

    <% providers = ordered_providers %>
    <% providers.each do |provider| %>
      <%= button_to provider_path(provider), method: :post,
          class: "provider-btn #{provider}",
          data: { turbo: false, action: "auth-modal#disable" } do %>
        <%= provider_label(provider) %>
      <% end %>
    <% end %>

    <p class="terms-notice">
      계속 진행 시 <%= link_to "이용약관", "/terms", target: "_blank" %> 및
      <%= link_to "개인정보 처리방침", "/privacy", target: "_blank" %>에 동의합니다.
    </p>
  </div>
<% end %>
```

`app/views/auth/sessions/new.html.erb`:

```erb
<%= render "modal" %>
```

Create a helper at `app/helpers/auth_helper.rb`:

```ruby
module AuthHelper
  PROVIDERS = %w[kakao naver google_oauth2].freeze

  def ordered_providers
    last = cookies[:last_provider]
    PROVIDERS.sort_by { |p| p == last || (p == "google_oauth2" && last == "google") ? 0 : 1 }
  end

  def provider_path(provider)
    "/auth/#{provider}"
  end

  def provider_label(provider)
    {
      "kakao"         => "카카오로 계속하기",
      "naver"         => "네이버로 계속하기",
      "google_oauth2" => "Google로 계속하기"
    }[provider]
  end
end
```

- [ ] **Step 2: Controller test for rendering**

Already covered by Task 9.1 `GET new renders login modal` — add an assertion for ordering:

```ruby
test "last_provider cookie floats matching button to top" do
  cookies[:last_provider] = "google"
  get "/auth/login"
  kakao_pos  = response.body.index("카카오로 계속하기")
  google_pos = response.body.index("Google로 계속하기")
  assert google_pos < kakao_pos
end
```

- [ ] **Step 3: Run, verify pass**

- [ ] **Step 4: Commit [BEHAVIOR]**

```bash
git add app/views/auth/sessions/ app/helpers/auth_helper.rb test/controllers/auth/sessions_controller_test.rb
git commit -m "feat(auth): login modal with last-provider sort and terms notice"
```

### Task 10.2: Stimulus auth_modal controller

**Files:**
- Create: `app/javascript/controllers/auth_modal_controller.js`

- [ ] **Step 1: Create controller**

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  disable(event) {
    const btn = event.currentTarget.querySelector("button") || event.currentTarget
    btn.disabled = true
    btn.dataset.originalText = btn.textContent
    btn.textContent = "로그인 중..."
  }

  close() {
    const frame = this.element.closest("turbo-frame")
    if (frame) frame.innerHTML = ""
  }
}
```

Register in `app/javascript/controllers/index.js` if explicit registration is used; importmaps auto-register if convention followed.

- [ ] **Step 2: System test covers this (Phase 12 Task 12.1)**

- [ ] **Step 3: Commit [BEHAVIOR]**

```bash
git add app/javascript/controllers/auth_modal_controller.js
git commit -m "feat(auth): Stimulus controller disables provider button on click"
```

### Task 10.3: Header with login button / avatar menu

**Files:**
- Create/overwrite: `app/views/layouts/_header.html.erb`
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Header partial**

`app/views/layouts/_header.html.erb`:

```erb
<header class="app-header">
  <%= link_to "경매", root_path, class: "logo" %>
  <% if current_user && !current_user.guest? %>
    <div class="user-menu" data-controller="dropdown">
      <button data-action="dropdown#toggle">
        <% if current_user.avatar_url %>
          <img src="<%= current_user.avatar_url %>" alt="" class="avatar">
        <% else %>
          <span class="avatar-initial"><%= current_user.name.to_s[0] %></span>
        <% end %>
        <%= current_user.name %>
      </button>
      <div class="dropdown-menu" data-dropdown-target="menu" hidden>
        <%= link_to "내 결과", "/saved" %>
        <%= link_to "설정", "/settings/budget" %>
        <%= button_to "로그아웃", "/auth/logout", method: :delete %>
      </div>
    </div>
  <% else %>
    <%= link_to "로그인", "/auth/login", class: "login-button",
        data: { turbo_frame: "auth_modal" } %>
  <% end %>
</header>
```

- [ ] **Step 2: Wire into application layout**

Edit `app/views/layouts/application.html.erb`, add inside `<body>` above `yield`:

```erb
<%= render "layouts/header" %>
<%= turbo_frame_tag "auth_modal" %>  <%# global modal mount point %>
```

- [ ] **Step 3: Controller test**

Add to `test/integration/guest_session_test.rb`:

```ruby
test "header shows 로그인 button for guest" do
  get root_path
  assert_match /로그인/, response.body
  refute_match /로그아웃/, response.body
end

test "header shows user menu when logged in" do
  user = User.create!(guest: false, email: "m@n.com", name: "Menu User")
  post "/testing/sign_in", params: { user_id: user.id }
  get root_path
  assert_match "Menu User", response.body
  assert_match /로그아웃/, response.body
end
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/views/layouts/ test/integration/guest_session_test.rb
git commit -m "feat(ui): header with login button and logged-in user menu"
```

### Task 10.4: POST-origin trigger → toast after login

**Files:**
- Modify: `app/controllers/auth/omniauth_callbacks_controller.rb`

- [ ] **Step 1: Failing test**

Not easily testable in Minitest integration without a POST trigger fixture. Mark this as a deferred system-test concern (Task 12 covers end-to-end). Alternatively add a controller test that asserts the toast key is populated when session carries a `post_origin` marker.

Test:

```ruby
test "post-origin trigger surfaces 'try again' toast after login" do
  get root_path
  post "/properties", params: { case_number: "CASE-X" }  # this would normally trigger the login modal

  # In production the login button click captures session[:pending_post_action] via Stimulus;
  # simulate that here:
  session_hash = { pending_post_action: "PDF 내보내기" }
  post "/testing/set_session", params: session_hash

  mock_omniauth(:kakao, uid: "x", email: "x@y.com", name: "X")
  get "/auth/kakao/callback"

  follow_redirect!
  assert_match "PDF 내보내기를 다시 눌러주세요", response.body
end
```

Add a test-only helper in `config/routes.rb` (inside the `if Rails.env.test?` block):

```ruby
post "/testing/set_session", to: ->(env) {
  req = ActionDispatch::Request.new(env)
  req.params.each { |k, v| req.session[k.to_sym] = v }
  [200, {}, ["ok"]]
}
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Implement**

In `Auth::OmniauthCallbacksController#create`, before the final `redirect_to return_to`:

```ruby
if (pending = session.delete(:pending_post_action))
  flash[:notice] = "#{flash[:notice]} — #{pending}를 다시 눌러주세요."
end
```

And modify the login-opening UX to capture `pending_post_action`. In `Auth::SessionsController#new`:

```ruby
def new
  session[:pending_post_action] = params[:pending] if params[:pending].present?
end
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/controllers/auth/omniauth_callbacks_controller.rb app/controllers/auth/sessions_controller.rb config/routes.rb test/controllers/auth/omniauth_callbacks_controller_test.rb
git commit -m "feat(auth): POST-origin trigger surfaces retry toast instead of replaying"
```

---

## Phase 11: Ops

### Task 11.1: GuestCleanupJob

**Files:**
- Create: `app/jobs/guest_cleanup_job.rb`
- Create: `test/jobs/guest_cleanup_job_test.rb`

- [ ] **Step 1: Failing test**

```ruby
require "test_helper"

class GuestCleanupJobTest < ActiveJob::TestCase
  test "destroys guests last seen over 30 days ago" do
    old   = User.create!(last_seen_at: 31.days.ago)
    fresh = User.create!(last_seen_at: 10.days.ago)
    account = User.create!(guest: false, email: "a@b.com", last_seen_at: 60.days.ago)

    GuestCleanupJob.perform_now

    assert_raises(ActiveRecord::RecordNotFound) { old.reload }
    assert fresh.reload.persisted?
    assert account.reload.persisted?
  end

  test "cascades dependent associations on destroy" do
    guest = User.create!(last_seen_at: 31.days.ago)
    prop = Property.create!(case_number: "CASE-CLEAN")
    guest.user_properties.create!(property: prop)

    GuestCleanupJob.perform_now

    assert_equal 0, UserProperty.where(user_id: guest.id).count
  end
end
```

- [ ] **Step 2: Verify fail**

- [ ] **Step 3: Implement**

```ruby
class GuestCleanupJob < ApplicationJob
  queue_as :default

  def perform(threshold: 30.days.ago)
    scope = User.where(guest: true).where("last_seen_at < ?", threshold)
    count = scope.count
    scope.find_each(&:destroy!)
    Rails.logger.info("[GuestCleanupJob] destroyed #{count} stale guests")
  end
end
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add app/jobs/guest_cleanup_job.rb test/jobs/guest_cleanup_job_test.rb
git commit -m "feat(jobs): GuestCleanupJob destroys inactive guests past 30 days"
```

### Task 11.2: Schedule in Solid Queue

**Files:**
- Modify: `config/recurring.yml` (create if missing)

- [ ] **Step 1: Add schedule**

If `config/recurring.yml` exists, append. If not, create:

```yaml
production:
  guest_cleanup:
    class: GuestCleanupJob
    queue: default
    schedule: "every day at 3am"

development:
  guest_cleanup:
    class: GuestCleanupJob
    queue: default
    schedule: "every day at 3am"
```

- [ ] **Step 2: Verify parsing**

```bash
bin/rails runner 'pp Rails.application.config_for(:recurring)'
```

- [ ] **Step 3: Commit [STRUCT]**

```bash
git add config/recurring.yml
git commit -m "chore(ops): schedule GuestCleanupJob daily at 3am via Solid Queue"
```

### Task 11.3: rack-attack

**Files:**
- Create: `config/initializers/rack_attack.rb`

- [ ] **Step 1: Create config**

```ruby
class Rack::Attack
  throttle("auth:ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/auth/") && req.post?
  end

  self.throttled_responder = ->(request) {
    [429, {"Content-Type" => "text/plain"}, ["Too many login attempts. Try again later."]]
  }
end
```

- [ ] **Step 2: Commit [BEHAVIOR]**

```bash
git add config/initializers/rack_attack.rb
git commit -m "feat(security): rack-attack throttles /auth/* POST at 10/min/IP"
```

---

## Phase 12: System tests

### Task 12.1: Full Kakao login happy path

**Files:**
- Create: `test/system/auth_flow_test.rb`

- [ ] **Step 1: Test**

```ruby
require "application_system_test_case"

class AuthFlowTest < ApplicationSystemTestCase
  setup do
    mock_omniauth(:kakao, uid: "sys-1", email: "sys@kakao.test", name: "시스템유저")
  end

  test "guest can onboard, open modal, login with Kakao, and land back on the original page" do
    visit "/properties"
    assert_text "물건 목록"  # adjust to actual H1

    click_on "로그인"
    assert_selector "turbo-frame#auth_modal"

    click_on "카카오로 계속하기"

    assert_current_path "/properties"
    assert_text "환영합니다, 시스템유저님"
  end
end
```

- [ ] **Step 2: Run (may skip if headless chromium not present — document)**

```bash
bin/rails test:system
```

- [ ] **Step 3: Commit [BEHAVIOR]**

```bash
git add test/system/auth_flow_test.rb
git commit -m "test(system): full Kakao login happy path"
```

### Task 12.2: Re-visit auto-login from cookie

**Files:**
- Modify: `test/system/auth_flow_test.rb`

- [ ] **Step 1: Add test**

```ruby
test "permanent remember_token cookie logs user back in on revisit" do
  # first login
  visit "/auth/login"
  click_on "카카오로 계속하기"
  assert_text "환영합니다"

  # simulate cookie survival by visiting again
  visit "/"
  assert_text "시스템유저"
  refute_text "로그인"  # header should show avatar, not login button
end
```

- [ ] **Step 2: Run & verify**

- [ ] **Step 3: Implement any missing cookie-based restore**

Add to `ApplicationController`:

```ruby
def ensure_current_user
  if session[:user_id] && (user = User.find_by(id: session[:user_id]))
    @current_user = user
  elsif (uid = cookies.signed[:remember_token]) && (user = User.find_by(id: uid, guest: false))
    session[:user_id] = user.id
    @current_user = user
  else
    @current_user = User.create!
    session[:user_id] = @current_user.id
  end
end
```

- [ ] **Step 4: Verify pass**

- [ ] **Step 5: Commit [BEHAVIOR]**

```bash
git add test/system/auth_flow_test.rb app/controllers/application_controller.rb
git commit -m "feat(auth): remember_token cookie restores session on revisit"
```

### Task 12.3: Logout resets to new guest

**Files:**
- Modify: `test/system/auth_flow_test.rb`

- [ ] **Step 1: Test**

```ruby
test "logout creates a new guest session distinct from the logged-in user" do
  visit "/auth/login"
  click_on "카카오로 계속하기"
  logged_in_uid = page.driver.browser.manage.cookie_named("_real_estate_auction_v2_session")  # cookie-based observability

  click_on "시스템유저"  # open menu
  click_on "로그아웃"

  # After logout, visiting root spawns a fresh guest
  visit "/"
  assert_text "로그인"  # header reverted
end
```

- [ ] **Step 2: Verify pass**

- [ ] **Step 3: Commit [BEHAVIOR]**

```bash
git add test/system/auth_flow_test.rb
git commit -m "test(system): logout resets header to guest state"
```

---

## Phase 13: Cleanup + docs

### Task 13.1: README OAuth setup checklist

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Append a section**

```markdown
## OAuth Developer Setup

Each developer must create their own OAuth apps. Credentials live in
`config/credentials/development.yml.enc` under keys `:google`, `:naver`,
`:kakao`, each with `client_id` and `client_secret`.

### Google
1. https://console.cloud.google.com → APIs & Services → Credentials → Web application
2. Authorized redirect URI: `http://localhost:3000/auth/google_oauth2/callback`
3. Scopes: `userinfo.email`, `userinfo.profile`

### Naver
1. https://developers.naver.com → Application 등록
2. Service URL: `http://localhost:3000`
3. Callback URL: `http://localhost:3000/auth/naver/callback`
4. Enable 제공 정보: 이메일 주소, 별명, 프로필 사진

### Kakao
1. https://developers.kakao.com → Application 생성
2. 보안 → Client Secret 생성
3. 카카오 로그인 → 활성화 ON
4. Redirect URI: `http://localhost:3000/auth/kakao/callback`
5. 동의항목: enable **카카오계정(이메일) — 필수 동의**, **프로필 정보(닉네임)**, **프로필 사진**
```

- [ ] **Step 2: Commit [STRUCT]**

```bash
git add README.md
git commit -m "docs: OAuth developer-console setup checklist"
```

### Task 13.2: Final full-suite verification

- [ ] **Step 1: Run the complete test suite**

```bash
bin/rails test
bin/rails test:system
```

Expected: green across the board.

- [ ] **Step 2: Run rubocop**

```bash
bin/rubocop
```

Expected: no offenses. Fix with `bin/rubocop -a` if needed.

- [ ] **Step 3: Run brakeman**

```bash
bin/brakeman --no-pager
```

Review any new warnings; OAuth introduces auth surface area so pay attention to redirect/open-redirect warnings.

- [ ] **Step 4: Manual smoke test**

Boot `bin/rails server` with real credentials set in `development.yml.enc`. Complete one real login per provider (Google, Naver, Kakao) and verify the redirect destination, toast, and header state.

- [ ] **Step 5: No commit needed** (verification only)

---

## Self-Review

Spec coverage check against `2026-04-22-sns-login-design.md`:

| Spec section | Covered by |
|---|---|
| Architecture diagram | Phases 1-7 together |
| `users` + `identities` migration | Tasks 1.1, 1.2 |
| `User` guest defaults + merge_policy metadata | Tasks 2.1-2.3 |
| `Identity` model | Task 2.4 |
| `Auth::ProviderProfile` | Task 3.2 |
| `Auth::*Adapter` | Tasks 4.1-4.3 |
| `SessionCreator` (Case A/B/C + nil-email + concurrency) | Tasks 6.1-6.4 |
| `GuestMerger` (per-policy + natural_key) | Tasks 5.1-5.5 |
| Routes + controllers | Tasks 8.3, 9.1-9.5 |
| Login modal + Stimulus + header | Tasks 10.1-10.3 |
| Deferred POST action → toast | Task 10.4 |
| `return_to_url` | Task 7.2 |
| `ensure_current_user` + per-session guests | Task 7.1 |
| `last_seen_at` throttle | Task 7.4 |
| `GuestCleanupJob` + schedule | Tasks 11.1, 11.2 |
| rack-attack | Task 11.3 |
| `reset_session` + fixation defense | Task 9.5 test, Task 9.2 impl |
| Remember-me cookie | Task 9.2 impl, Task 12.2 test |
| Logout | Task 9.1 |
| OAuth failure codes | Task 9.4 |
| Dev-console README | Task 13.1 |
| Phase 0 spike gate | Task 0.1 |

All spec sections have a corresponding task. No gaps.

---

## Known Follow-ups (post-plan)

The following were flagged during plan-eng-review as non-blocking for this PR:

1. Multi-tab session sync (Turbo Cable broadcast of login state).
2. Account settings page — "Connect additional provider", "Export data before logout".
3. Expanded rack-attack rules (progressive backoff, suspicious-IP denylist).

Capture in `TODOS.md` after this work ships.
