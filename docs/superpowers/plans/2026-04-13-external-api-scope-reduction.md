# External API Scope Reduction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove 5 planned-but-unneeded external API integrations and their associated code, keeping only LLM PDF analysis and court auction search.

**Architecture:** Delete the real transaction price design spec and government loan policy stub adapter. Trim `ApiCredential::PROVIDERS` to `court_auction` only. Update all tests that reference removed providers. Simplify `LoanPolicyAdapter` factory to always return `MockLoanPolicyAdapter`.

**Tech Stack:** Rails 8.1, Minitest

---

### Task 1: Delete the real transaction price design spec

**Files:**
- Delete: `docs/superpowers/specs/2026-04-12-real-transaction-price-api-design.md`

- [ ] **Step 1: Delete the file**

```bash
git rm docs/superpowers/specs/2026-04-12-real-transaction-price-api-design.md
```

- [ ] **Step 2: Commit**

```bash
git commit -m "docs: remove real transaction price API design spec

Superseded by 2026-04-13-external-api-scope-reduction-design.md.
This API integration is no longer planned."
```

---

### Task 2: Delete GovernmentLoanPolicyAdapter

**Files:**
- Delete: `app/adapters/government_loan_policy_adapter.rb`
- Modify: `app/adapters/loan_policy_adapter.rb`

- [ ] **Step 1: Run existing tests to confirm green baseline**

```bash
bin/rails test
```

Expected: All tests pass.

- [ ] **Step 2: Delete the stub adapter file**

```bash
git rm app/adapters/government_loan_policy_adapter.rb
```

- [ ] **Step 3: Simplify LoanPolicyAdapter factory**

Edit `app/adapters/loan_policy_adapter.rb` — remove the `:real` branch and always return `MockLoanPolicyAdapter`:

```ruby
class LoanPolicyAdapter
  def self.for(_config = {})
    MockLoanPolicyAdapter.new
  end

  def fetch_policies(property_type_code:)
    raise NotImplementedError, "#{self.class}#fetch_policies must be implemented"
  end
end
```

- [ ] **Step 4: Run tests to verify nothing broke**

```bash
bin/rails test
```

Expected: All tests pass. No code referenced `GovernmentLoanPolicyAdapter` directly except the factory.

- [ ] **Step 5: Commit**

```bash
git add app/adapters/loan_policy_adapter.rb
git commit -m "refactor: remove GovernmentLoanPolicyAdapter and simplify factory

Government loan policy API integration is no longer planned.
LoanPolicyAdapter.for now always returns MockLoanPolicyAdapter."
```

---

### Task 3: Trim ApiCredential::PROVIDERS

**Files:**
- Modify: `app/models/api_credential.rb`

- [ ] **Step 1: Edit PROVIDERS constant**

Edit `app/models/api_credential.rb` — replace the entire `PROVIDERS` hash with only `court_auction`:

```ruby
PROVIDERS = {
  court_auction: {
    name: "Court Auction (courtauction.go.kr)",
    name_ko: "법원경매정보",
    requires_key: false,
    requires_consent: true,
    category: :auction,
    description_ko: "법원경매정보 사이트에서 경매 사건정보를 수집합니다."
  }
}.freeze
```

- [ ] **Step 2: Run tests to see what fails**

```bash
bin/rails test
```

Expected: Several test failures in `test/models/api_credential_test.rb`, `test/controllers/settings/api_credentials_controller_test.rb`, and `test/jobs/credential_verification_job_test.rb` because they reference removed providers like `data_go_kr` and `tilko`.

- [ ] **Step 3: Commit the model change (red state)**

Do NOT commit yet — fix the tests first in the next task.

---

### Task 4: Update ApiCredential tests

**Files:**
- Modify: `test/models/api_credential_test.rb`
- Modify: `test/controllers/settings/api_credentials_controller_test.rb`
- Modify: `test/jobs/credential_verification_job_test.rb`

- [ ] **Step 1: Update api_credential_test.rb**

Replace the full file content with:

```ruby
require "test_helper"

class ApiCredentialTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
  end

  test "PROVIDERS constant contains expected providers" do
    expected_keys = %i[court_auction]
    assert_equal expected_keys.sort, ApiCredential::PROVIDERS.keys.sort
  end

  test "each provider has required metadata" do
    ApiCredential::PROVIDERS.each do |key, config|
      assert config[:name].present?, "#{key} missing :name"
      assert config[:name_ko].present?, "#{key} missing :name_ko"
      assert_includes [ true, false ], config[:requires_key], "#{key} missing :requires_key"
      assert config[:category].present?, "#{key} missing :category"
    end
  end

  test "validates provider_name presence" do
    cred = ApiCredential.new(user: @user, provider_name: nil)
    assert_not cred.valid?
    assert_includes cred.errors[:provider_name], "can't be blank"
  end

  test "validates provider_name inclusion" do
    cred = ApiCredential.new(user: @user, provider_name: "invalid_provider")
    assert_not cred.valid?
    assert_includes cred.errors[:provider_name], "is not included in the list"
  end

  test "validates provider_name uniqueness per user" do
    ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: true)
    duplicate = ApiCredential.new(user: @user, provider_name: "court_auction", enabled: true)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:provider_name], "has already been taken"
  end

  test "encrypts api_key" do
    cred = ApiCredential.create!(user: @user, provider_name: "court_auction", api_key: "my-secret-key", enabled: true)
    raw_value = ApiCredential.connection.select_value(
      "SELECT api_key FROM api_credentials WHERE id = #{cred.id}"
    )
    assert_not_equal "my-secret-key", raw_value
    assert_equal "my-secret-key", cred.reload.api_key
  end

  test "encrypts api_secret" do
    cred = ApiCredential.create!(user: @user, provider_name: "court_auction", api_key: "key", api_secret: "secret-123", enabled: true)
    raw_value = ApiCredential.connection.select_value(
      "SELECT api_secret FROM api_credentials WHERE id = #{cred.id}"
    )
    assert_not_equal "secret-123", raw_value
    assert_equal "secret-123", cred.reload.api_secret
  end

  test "configured? returns true for consent-only provider when enabled" do
    cred = ApiCredential.new(provider_name: "court_auction", api_key: nil, enabled: true)
    assert cred.configured?
  end

  test "configured? returns false for consent-only provider when disabled" do
    cred = ApiCredential.new(provider_name: "court_auction", api_key: nil, enabled: false)
    assert_not cred.configured?
  end

  test "verified? returns true when last_verified_at is present" do
    cred = ApiCredential.new(last_verified_at: 1.day.ago)
    assert cred.verified?
  end

  test "verified? returns false when last_verified_at is nil" do
    cred = ApiCredential.new(last_verified_at: nil)
    assert_not cred.verified?
  end

  test "for_provider scope returns matching credential" do
    cred = ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: true)
    assert_equal cred, @user.api_credentials.for_provider(:court_auction)
  end

  test "for_provider scope returns nil when no match" do
    assert_nil @user.api_credentials.for_provider(:court_auction)
  end

  test "active scope excludes disabled credentials" do
    ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: true)
    assert_equal 1, @user.api_credentials.active.count
  end
end
```

- [ ] **Step 2: Update api_credentials_controller_test.rb**

Replace the full file content with:

```ruby
require "test_helper"

class Settings::ApiCredentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get root_path  # ensure guest session
    @user = User.find(session[:user_id])
  end

  test "consent toggle creates court_auction credential" do
    assert_difference "ApiCredential.count", 1 do
      post settings_api_credentials_path, params: {
        api_credential: { provider_name: "court_auction", enabled: true }
      }
    end
    assert_redirected_to settings_data_sources_path
    cred = ApiCredential.last
    assert_equal "court_auction", cred.provider_name
    assert cred.enabled?
  end

  test "consent toggle updates court_auction credential" do
    cred = ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: false)
    patch settings_api_credential_path(cred), params: {
      api_credential: { enabled: true }
    }
    assert_redirected_to settings_data_sources_path
    assert cred.reload.enabled?
  end

  test "destroy removes credential" do
    cred = ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: true)
    assert_difference "ApiCredential.count", -1 do
      delete settings_api_credential_path(cred)
    end
  end
end
```

- [ ] **Step 3: Update credential_verification_job_test.rb**

Replace the full file content with:

```ruby
require "test_helper"

class CredentialVerificationJobTest < ActiveJob::TestCase
  setup do
    @user = users(:guest)
    @credential = ApiCredential.create!(
      user: @user,
      provider_name: "court_auction",
      enabled: true
    )
  end

  test "updates last_verified_at on success" do
    assert_nil @credential.last_verified_at
    CredentialVerificationJob.perform_now(@credential)
    @credential.reload
    assert_not_nil @credential.last_verified_at
  end

  test "does not crash when credential is deleted before execution" do
    @credential.destroy!
    assert_nothing_raised do
      CredentialVerificationJob.perform_now(@credential)
    end
  end
end
```

- [ ] **Step 4: Run all tests**

```bash
bin/rails test
```

Expected: All tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/models/api_credential.rb test/models/api_credential_test.rb test/controllers/settings/api_credentials_controller_test.rb test/jobs/credential_verification_job_test.rb
git commit -m "refactor: remove unused API providers from ApiCredential

Remove data_go_kr, tilko, codef, iros, hyphen from PROVIDERS.
Only court_auction remains. Update all tests to use court_auction."
```

---

### Task 5: Clean up any stale DB records and run full CI

**Files:**
- No file changes — verification only

- [ ] **Step 1: Check for stale ApiCredential records in development DB**

```bash
bin/rails runner "puts ApiCredential.where.not(provider_name: 'court_auction').count"
```

If count > 0, clean them up:

```bash
bin/rails runner "ApiCredential.where.not(provider_name: 'court_auction').destroy_all"
```

- [ ] **Step 2: Run full CI pipeline**

```bash
bin/ci
```

Expected: All checks pass (rubocop, brakeman, bundler-audit, tests, seed check).

- [ ] **Step 3: Commit only if any seed/migration changes were needed**

If `bin/ci` passes with no code changes, nothing to commit. If a fix was needed, commit it.

---

### Task 6: Update memory and verify final state

**Files:**
- Modify: `~/.claude/projects/-home-tonny-projects-real-estate-auction-v2/memory/project_data_provider_progress.md`

- [ ] **Step 1: Update project memory**

Update the data provider progress memory to reflect that external API integrations (except court auction + LLM) have been removed from scope.

- [ ] **Step 2: Verify final adapter directory**

```bash
ls app/adapters/
```

Expected contents:
- `court_auction/` (directory — retained)
- `llm/` (directory — retained)
- `loan_policy_adapter.rb` (simplified factory)
- `mock_loan_policy_adapter.rb` (seed data source — retained)

No `government_loan_policy_adapter.rb`.

- [ ] **Step 3: Verify Settings UI shows only court_auction**

```bash
bin/rails runner "puts ApiCredential::PROVIDERS.keys"
```

Expected output: `court_auction`
