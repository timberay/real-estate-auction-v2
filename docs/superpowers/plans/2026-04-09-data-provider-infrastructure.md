# Data Provider Infrastructure Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the common infrastructure for external data source integration — credential management, adapter factory enhancement, error handling, and settings UI.

**Architecture:** Extend the existing Adapter pattern with a `CredentialResolver` that decouples user context from adapters. API keys are stored encrypted in DB via Rails 8 `encrypts`. Settings UI uses Turbo Frames for per-provider cards with async verification via Solid Queue.

**Tech Stack:** Rails 8.1, SQLite, Solid Queue, Turbo Streams, Rails `encrypts`, ViewComponent, Faraday (new dependency)

**Spec:** `docs/superpowers/specs/2026-04-09-data-provider-architecture-design.md`

---

## File Map

### New Files
| File | Responsibility |
|------|---------------|
| `app/models/api_credential.rb` | Encrypted API key storage, PROVIDERS constant, validation |
| `app/services/credential_resolver.rb` | 3-tier resolution: ENV → credential → error |
| `app/errors/data_provider.rb` | Error hierarchy (12 error classes) |
| `app/jobs/credential_verification_job.rb` | Async key verification via Solid Queue |
| `app/controllers/settings/data_sources_controller.rb` | Data source settings page |
| `app/controllers/settings/api_credentials_controller.rb` | CRUD + verify for credentials |
| `app/views/settings/data_sources/show.html.erb` | Data source settings page view |
| `app/components/data_source_card_component.rb` | Provider card ViewComponent |
| `app/components/data_source_card_component.html.erb` | Provider card template |
| `app/components/credential_status_badge_component.rb` | Status badge ViewComponent |
| `app/components/credential_status_badge_component.html.erb` | Status badge template |
| `db/migrate/XXXXXX_create_api_credentials.rb` | Migration |
| `test/models/api_credential_test.rb` | Model tests |
| `test/services/credential_resolver_test.rb` | Resolver tests |
| `test/controllers/settings/data_sources_controller_test.rb` | Controller tests |
| `test/controllers/settings/api_credentials_controller_test.rb` | Controller tests |
| `test/jobs/credential_verification_job_test.rb` | Job tests |
| `test/test_helpers/data_provider_test_helper.rb` | Shared test helpers |

### Modified Files
| File | Change |
|------|--------|
| `app/models/user.rb` | Add `has_many :api_credentials` |
| `app/services/property_data_sync_service.rb` | Accept `user:`, use `CredentialResolver`, partial data handling |
| `app/adapters/court_auction_adapter.rb` | Accept `config` in `.for` |
| `app/adapters/building_ledger_adapter.rb` | Accept `config` in `.for` |
| `app/adapters/registry_transcript_adapter.rb` | Accept `config` in `.for` |
| `app/adapters/loan_policy_adapter.rb` | Accept `config` in `.for` |
| `app/controllers/application_controller.rb` | Add `rescue_from DataProvider::*` handlers |
| `config/routes.rb` | Add settings/data_sources and api_credentials routes |
| `config/initializers/filter_parameter_logging.rb` | Add PII filter params |
| `Gemfile` | Add `faraday` gem |

---

## Task 1: Add Faraday Dependency

**Files:**
- Modify: `Gemfile`

- [ ] **Step 1: Add faraday to Gemfile**

```ruby
# In Gemfile, after the bcrypt line:
gem "faraday"
gem "faraday-retry"
```

- [ ] **Step 2: Bundle install**

Run: `bundle install`
Expected: Successfully installed faraday and faraday-retry

- [ ] **Step 3: Commit**

```bash
git add Gemfile Gemfile.lock
git commit -m "deps: add faraday and faraday-retry for external API calls"
```

---

## Task 2: DataProvider Error Hierarchy

**Files:**
- Create: `app/errors/data_provider.rb`
- Test: `test/errors/data_provider_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/errors/data_provider_test.rb
require "test_helper"

class DataProviderErrorTest < ActiveSupport::TestCase
  test "all errors inherit from DataProvider::Error" do
    error_classes = [
      DataProvider::MissingCredentialError,
      DataProvider::InvalidCredentialError,
      DataProvider::ExpiredCredentialError,
      DataProvider::ConnectionError,
      DataProvider::RateLimitError,
      DataProvider::ServiceUnavailableError,
      DataProvider::DataNotFoundError,
      DataProvider::ParseError,
      DataProvider::ConsentRequiredError,
      DataProvider::SiteStructureChangedError,
      DataProvider::CaptchaError,
      DataProvider::IpBlockedError
    ]

    error_classes.each do |klass|
      assert klass < DataProvider::Error, "#{klass} should inherit from DataProvider::Error"
      assert klass < StandardError, "#{klass} should inherit from StandardError"
    end
  end

  test "errors can be instantiated with a message" do
    error = DataProvider::MissingCredentialError.new("API 키를 설정해주세요.")
    assert_equal "API 키를 설정해주세요.", error.message
  end

  test "rescue DataProvider::Error catches all subclasses" do
    assert_raises(DataProvider::Error) do
      raise DataProvider::ConnectionError, "timeout"
    end
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/errors/data_provider_test.rb`
Expected: FAIL — `NameError: uninitialized constant DataProvider`

- [ ] **Step 3: Write the implementation**

```ruby
# app/errors/data_provider.rb
module DataProvider
  class Error < StandardError; end

  # Credential errors — user action required
  class MissingCredentialError < Error; end
  class InvalidCredentialError < Error; end
  class ExpiredCredentialError < Error; end

  # External service errors — transient, retry may help
  class ConnectionError < Error; end
  class RateLimitError < Error; end
  class ServiceUnavailableError < Error; end

  # Data errors — request-specific
  class DataNotFoundError < Error; end
  class ParseError < Error; end

  # Scraping-specific
  class ConsentRequiredError < Error; end
  class SiteStructureChangedError < Error; end
  class CaptchaError < Error; end
  class IpBlockedError < Error; end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/errors/data_provider_test.rb`
Expected: 3 tests, 0 failures

- [ ] **Step 5: Commit**

```bash
git add app/errors/data_provider.rb test/errors/data_provider_test.rb
git commit -m "feat: add DataProvider error hierarchy with 12 error classes"
```

---

## Task 3: ApiCredential Model

**Files:**
- Create: `db/migrate/XXXXXX_create_api_credentials.rb`
- Create: `app/models/api_credential.rb`
- Modify: `app/models/user.rb`
- Test: `test/models/api_credential_test.rb`

- [ ] **Step 1: Generate migration**

Run: `bin/rails generate migration CreateApiCredentials`

- [ ] **Step 2: Write the migration**

```ruby
# db/migrate/XXXXXX_create_api_credentials.rb
class CreateApiCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :api_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :provider_name, null: false
      t.string :api_key
      t.string :api_secret
      t.boolean :enabled, default: true, null: false
      t.datetime :last_verified_at
      t.timestamps
    end

    add_index :api_credentials, [:user_id, :provider_name], unique: true
  end
end
```

- [ ] **Step 3: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration runs successfully

- [ ] **Step 4: Write the failing tests**

```ruby
# test/models/api_credential_test.rb
require "test_helper"

class ApiCredentialTest < ActiveSupport::TestCase
  setup do
    @user = users(:default)
  end

  test "PROVIDERS constant contains expected providers" do
    expected_keys = %i[court_auction data_go_kr tilko codef iros hyphen]
    assert_equal expected_keys.sort, ApiCredential::PROVIDERS.keys.sort
  end

  test "each provider has required metadata" do
    ApiCredential::PROVIDERS.each do |key, config|
      assert config[:name].present?, "#{key} missing :name"
      assert config[:name_ko].present?, "#{key} missing :name_ko"
      assert_includes [true, false], config[:requires_key], "#{key} missing :requires_key"
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
    ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "key-123")
    duplicate = ApiCredential.new(user: @user, provider_name: "data_go_kr", api_key: "key-456")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:provider_name], "has already been taken"
  end

  test "encrypts api_key" do
    cred = ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "my-secret-key")
    raw_value = ApiCredential.connection.select_value(
      "SELECT api_key FROM api_credentials WHERE id = #{cred.id}"
    )
    assert_not_equal "my-secret-key", raw_value
    assert_equal "my-secret-key", cred.reload.api_key
  end

  test "encrypts api_secret" do
    cred = ApiCredential.create!(user: @user, provider_name: "tilko", api_key: "key", api_secret: "secret-123")
    raw_value = ApiCredential.connection.select_value(
      "SELECT api_secret FROM api_credentials WHERE id = #{cred.id}"
    )
    assert_not_equal "secret-123", raw_value
    assert_equal "secret-123", cred.reload.api_secret
  end

  test "configured? returns true for key-based provider with key and enabled" do
    cred = ApiCredential.new(provider_name: "data_go_kr", api_key: "key-123", enabled: true)
    assert cred.configured?
  end

  test "configured? returns false for key-based provider without key" do
    cred = ApiCredential.new(provider_name: "data_go_kr", api_key: nil, enabled: true)
    assert_not cred.configured?
  end

  test "configured? returns false for disabled provider" do
    cred = ApiCredential.new(provider_name: "data_go_kr", api_key: "key-123", enabled: false)
    assert_not cred.configured?
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
    cred = ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "key-123")
    assert_equal cred, @user.api_credentials.for_provider(:data_go_kr)
  end

  test "for_provider scope returns nil when no match" do
    assert_nil @user.api_credentials.for_provider(:tilko)
  end

  test "active scope excludes disabled credentials" do
    ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "key", enabled: false)
    assert_empty @user.api_credentials.active
  end
end
```

- [ ] **Step 5: Run tests to verify they fail**

Run: `bin/rails test test/models/api_credential_test.rb`
Expected: FAIL — `NameError: uninitialized constant ApiCredential`

- [ ] **Step 6: Create fixture**

```yaml
# test/fixtures/api_credentials.yml
# (empty — tests create records as needed)
```

- [ ] **Step 7: Write the model**

```ruby
# app/models/api_credential.rb
class ApiCredential < ApplicationRecord
  PROVIDERS = {
    court_auction: {
      name: "Court Auction (courtauction.go.kr)",
      name_ko: "법원경매정보",
      requires_key: false,
      requires_consent: true,
      category: :auction,
      description_ko: "법원경매정보 사이트에서 경매 사건정보를 수집합니다."
    },
    data_go_kr: {
      name: "Public Data Portal (data.go.kr)",
      name_ko: "공공데이터포털 (건축물대장)",
      requires_key: true,
      requires_consent: false,
      category: :building_ledger,
      description_ko: "국토교통부 건축물대장정보 API를 조회합니다. data.go.kr에서 무료로 키를 발급받을 수 있습니다."
    },
    tilko: {
      name: "Tilko (tilko.net)",
      name_ko: "틸코블렛 (등기부등본)",
      requires_key: true,
      requires_consent: false,
      category: :registry,
      description_ko: "등기부등본을 조회합니다. 건당 과금이 발생합니다."
    },
    codef: {
      name: "Codef (codef.io)",
      name_ko: "코드에프 (등기부등본)",
      requires_key: true,
      requires_consent: false,
      category: :registry,
      description_ko: "등기부등본을 조회합니다. Tilko 대안으로 안정성이 높다는 평가가 있습니다."
    },
    iros: {
      name: "Registry Information Portal (iros.go.kr)",
      name_ko: "등기정보광장 (무료 미리보기)",
      requires_key: true,
      requires_consent: false,
      category: :registry_preview,
      description_ko: "등기 요약정보를 무료로 조회합니다 (하루 1,000건). 전문 등기부등본을 대체하지 않습니다."
    },
    hyphen: {
      name: "Hyphen (codef.io)",
      name_ko: "하이픈 (권리분석)",
      requires_key: true,
      requires_consent: false,
      category: :rights_analysis,
      description_ko: "권리분석 데이터를 조회합니다. 자체 분석 엔진의 대안으로 사용할 수 있습니다."
    }
  }.freeze

  belongs_to :user

  encrypts :api_key, deterministic: false
  encrypts :api_secret, deterministic: false

  validates :provider_name, presence: true,
    inclusion: { in: PROVIDERS.keys.map(&:to_s) },
    uniqueness: { scope: :user_id }

  scope :for_provider, ->(name) { find_by(provider_name: name.to_s) }
  scope :active, -> { where(enabled: true) }

  def verified?
    last_verified_at.present?
  end

  def configured?
    provider_config = PROVIDERS[provider_name.to_sym]
    if provider_config[:requires_key]
      api_key.present? && enabled?
    else
      enabled?
    end
  end
end
```

- [ ] **Step 8: Update User model**

```ruby
# app/models/user.rb — add after has_many :rights_analysis_reports line:
has_many :api_credentials, dependent: :destroy
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `bin/rails test test/models/api_credential_test.rb`
Expected: All tests pass

- [ ] **Step 10: Commit**

```bash
git add db/migrate/ app/models/api_credential.rb app/models/user.rb test/models/api_credential_test.rb test/fixtures/api_credentials.yml db/schema.rb
git commit -m "feat: add ApiCredential model with encryption and PROVIDERS registry"
```

---

## Task 4: CredentialResolver Service

**Files:**
- Create: `app/services/credential_resolver.rb`
- Test: `test/services/credential_resolver_test.rb`
- Create: `test/test_helpers/data_provider_test_helper.rb`

- [ ] **Step 1: Create test helper first**

```ruby
# test/test_helpers/data_provider_test_helper.rb
module DataProviderTestHelper
  def with_mock_mode(&block)
    original = ENV["USE_MOCK"]
    ENV["USE_MOCK"] = "true"
    yield
  ensure
    ENV["USE_MOCK"] = original
  end

  def with_real_mode(&block)
    original = ENV["USE_MOCK"]
    ENV["USE_MOCK"] = "false"
    yield
  ensure
    ENV["USE_MOCK"] = original
  end

  def create_credential(user:, provider:, api_key: "test-key-123", enabled: true)
    ApiCredential.create!(
      user: user,
      provider_name: provider.to_s,
      api_key: api_key,
      enabled: enabled
    )
  end
end
```

- [ ] **Step 2: Write the failing tests**

```ruby
# test/services/credential_resolver_test.rb
require "test_helper"
require "test_helpers/data_provider_test_helper"

class CredentialResolverTest < ActiveSupport::TestCase
  include DataProviderTestHelper

  setup do
    @user = users(:default)
  end

  # --- Tier 1: Mock mode ---

  test "returns mock when USE_MOCK is not false" do
    with_mock_mode do
      result = CredentialResolver.new(user: @user, provider_name: :data_go_kr).resolve
      assert_equal :mock, result[:adapter]
    end
  end

  test "returns mock when USE_MOCK is unset" do
    original = ENV.delete("USE_MOCK")
    result = CredentialResolver.new(user: @user, provider_name: :data_go_kr).resolve
    assert_equal :mock, result[:adapter]
  ensure
    ENV["USE_MOCK"] = original
  end

  # --- Tier 2: Credential check ---

  test "returns real with api_key when user has configured credential" do
    with_real_mode do
      create_credential(user: @user, provider: :data_go_kr, api_key: "my-key")
      result = CredentialResolver.new(user: @user, provider_name: :data_go_kr).resolve
      assert_equal :real, result[:adapter]
      assert_equal "my-key", result[:api_key]
      assert_equal :data_go_kr, result[:provider]
    end
  end

  test "returns real for consent-only provider when enabled" do
    with_real_mode do
      ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: true)
      result = CredentialResolver.new(user: @user, provider_name: :court_auction).resolve
      assert_equal :real, result[:adapter]
      assert_equal :court_auction, result[:provider]
    end
  end

  test "skips disabled credentials" do
    with_real_mode do
      create_credential(user: @user, provider: :data_go_kr, api_key: "my-key", enabled: false)
      assert_raises(DataProvider::MissingCredentialError) do
        CredentialResolver.new(user: @user, provider_name: :data_go_kr).resolve
      end
    end
  end

  # --- Tier 3: No credential ---

  test "raises MissingCredentialError in production when no credential" do
    with_real_mode do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        assert_raises(DataProvider::MissingCredentialError) do
          CredentialResolver.new(user: @user, provider_name: :data_go_kr).resolve
        end
      end
    end
  end

  test "raises ConsentRequiredError in production for consent-only provider" do
    with_real_mode do
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("production")) do
        assert_raises(DataProvider::ConsentRequiredError) do
          CredentialResolver.new(user: @user, provider_name: :court_auction).resolve
        end
      end
    end
  end

  test "returns mock in development when no credential" do
    with_real_mode do
      result = CredentialResolver.new(user: @user, provider_name: :data_go_kr).resolve
      assert_equal :mock, result[:adapter]
    end
  end

  # --- Category-aware resolution ---

  test "resolves by category when provider_name is nil" do
    with_real_mode do
      create_credential(user: @user, provider: :codef, api_key: "codef-key")
      result = CredentialResolver.new(user: @user, category: :registry).resolve
      assert_equal :real, result[:adapter]
      assert_equal :codef, result[:provider]
      assert_equal "codef-key", result[:api_key]
    end
  end

  test "category resolution prefers first configured credential" do
    with_real_mode do
      create_credential(user: @user, provider: :tilko, api_key: "tilko-key")
      create_credential(user: @user, provider: :codef, api_key: "codef-key")
      result = CredentialResolver.new(user: @user, category: :registry).resolve
      assert_equal :tilko, result[:provider]
    end
  end

  test "category resolution skips disabled providers" do
    with_real_mode do
      create_credential(user: @user, provider: :tilko, api_key: "tilko-key", enabled: false)
      create_credential(user: @user, provider: :codef, api_key: "codef-key")
      result = CredentialResolver.new(user: @user, category: :registry).resolve
      assert_equal :codef, result[:provider]
    end
  end

  # --- Argument validation ---

  test "raises ArgumentError when neither provider_name nor category given" do
    assert_raises(ArgumentError) do
      CredentialResolver.new(user: @user).resolve
    end
  end

  # --- Nil user ---

  test "returns mock when user is nil and mock mode" do
    with_mock_mode do
      result = CredentialResolver.new(user: nil, provider_name: :data_go_kr).resolve
      assert_equal :mock, result[:adapter]
    end
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/services/credential_resolver_test.rb`
Expected: FAIL — `NameError: uninitialized constant CredentialResolver`

- [ ] **Step 4: Write the implementation**

```ruby
# app/services/credential_resolver.rb
class CredentialResolver
  def initialize(user:, provider_name: nil, category: nil)
    @user = user
    @provider_name = provider_name&.to_sym
    @category = category&.to_sym
    raise ArgumentError, "provider_name or category required" unless @provider_name || @category
  end

  def resolve
    return { adapter: :mock } if mock_mode?

    credential = find_credential
    if credential&.configured?
      {
        adapter: :real,
        provider: credential.provider_name.to_sym,
        api_key: credential.api_key,
        api_secret: credential.api_secret
      }
    elsif Rails.env.production?
      raise error_for_provider
    else
      { adapter: :mock }
    end
  end

  private

  def find_credential
    return nil unless @user

    if @provider_name
      @user.api_credentials.active.for_provider(@provider_name)
    else
      providers_in_category = ApiCredential::PROVIDERS
        .select { |_, v| v[:category] == @category }
        .keys.map(&:to_s)
      @user.api_credentials.active
        .where(provider_name: providers_in_category)
        .order(:created_at)
        .first
    end
  end

  def mock_mode?
    ENV["USE_MOCK"] != "false"
  end

  def error_for_provider
    config = if @provider_name
      ApiCredential::PROVIDERS[@provider_name]
    else
      ApiCredential::PROVIDERS.values.find { |v| v[:category] == @category }
    end

    if config&.dig(:requires_consent)
      DataProvider::ConsentRequiredError.new("법원경매 데이터 수집에 동의해주세요.")
    else
      DataProvider::MissingCredentialError.new("#{config&.dig(:name_ko)} API 키를 설정해주세요.")
    end
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/services/credential_resolver_test.rb`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add app/services/credential_resolver.rb test/services/credential_resolver_test.rb test/test_helpers/data_provider_test_helper.rb
git commit -m "feat: add CredentialResolver with 3-tier resolution and category support"
```

---

## Task 5: Update Adapter Factories

**Files:**
- Modify: `app/adapters/court_auction_adapter.rb`
- Modify: `app/adapters/building_ledger_adapter.rb`
- Modify: `app/adapters/registry_transcript_adapter.rb`
- Modify: `app/adapters/loan_policy_adapter.rb`
- Test: `test/adapters/adapter_factory_test.rb`

- [ ] **Step 1: Write the failing tests**

```ruby
# test/adapters/adapter_factory_test.rb
require "test_helper"

class AdapterFactoryTest < ActiveSupport::TestCase
  test "CourtAuctionAdapter.for returns mock by default" do
    adapter = CourtAuctionAdapter.for
    assert_instance_of MockCourtAuctionAdapter, adapter
  end

  test "CourtAuctionAdapter.for returns mock with empty config" do
    adapter = CourtAuctionAdapter.for({})
    assert_instance_of MockCourtAuctionAdapter, adapter
  end

  test "CourtAuctionAdapter.for returns real with real config" do
    adapter = CourtAuctionAdapter.for(adapter: :real)
    assert_instance_of GovernmentCourtAuctionAdapter, adapter
  end

  test "BuildingLedgerAdapter.for returns real with api_key" do
    adapter = BuildingLedgerAdapter.for(adapter: :real, api_key: "test-key")
    assert_instance_of GovernmentBuildingLedgerAdapter, adapter
  end

  test "RegistryTranscriptAdapter.for returns mock by default" do
    adapter = RegistryTranscriptAdapter.for
    assert_instance_of MockRegistryTranscriptAdapter, adapter
  end

  test "LoanPolicyAdapter.for returns mock by default" do
    adapter = LoanPolicyAdapter.for
    assert_instance_of MockLoanPolicyAdapter, adapter
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/adapters/adapter_factory_test.rb`
Expected: FAIL — `ArgumentError: wrong number of arguments`

- [ ] **Step 3: Update CourtAuctionAdapter**

```ruby
# app/adapters/court_auction_adapter.rb
class CourtAuctionAdapter
  def self.for(config = {})
    if config[:adapter] == :real
      GovernmentCourtAuctionAdapter.new
    else
      MockCourtAuctionAdapter.new
    end
  end

  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end
end
```

- [ ] **Step 4: Update BuildingLedgerAdapter**

```ruby
# app/adapters/building_ledger_adapter.rb
class BuildingLedgerAdapter
  def self.for(config = {})
    if config[:adapter] == :real
      GovernmentBuildingLedgerAdapter.new(api_key: config[:api_key])
    else
      MockBuildingLedgerAdapter.new
    end
  end

  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end
end
```

- [ ] **Step 5: Update RegistryTranscriptAdapter**

```ruby
# app/adapters/registry_transcript_adapter.rb
class RegistryTranscriptAdapter
  def self.for(config = {})
    if config[:adapter] == :real
      MockRegistryTranscriptAdapter.new  # Real adapters defined in individual source specs
    else
      MockRegistryTranscriptAdapter.new
    end
  end

  def fetch_data(case_number:)
    raise NotImplementedError, "#{self.class}#fetch_data must be implemented"
  end
end
```

- [ ] **Step 6: Update LoanPolicyAdapter**

```ruby
# app/adapters/loan_policy_adapter.rb
class LoanPolicyAdapter
  def self.for(config = {})
    if config[:adapter] == :real
      GovernmentLoanPolicyAdapter.new
    else
      MockLoanPolicyAdapter.new
    end
  end

  def fetch_policies(property_type_code:)
    raise NotImplementedError, "#{self.class}#fetch_policies must be implemented"
  end
end
```

- [ ] **Step 7: Check GovernmentBuildingLedgerAdapter accepts api_key**

Read `app/adapters/government_building_ledger_adapter.rb`. If its `initialize` doesn't accept `api_key:`, update it to accept and ignore it for now:

```ruby
# If needed, update initialize to accept api_key:
def initialize(api_key: nil)
  @api_key = api_key
end
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `bin/rails test test/adapters/adapter_factory_test.rb`
Expected: All tests pass

- [ ] **Step 9: Run full test suite to check backward compatibility**

Run: `bin/rails test`
Expected: All existing tests pass (adapters still default to mock)

- [ ] **Step 10: Commit**

```bash
git add app/adapters/
git commit -m "refactor: update adapter factories to accept config hash"
```

---

## Task 6: Update PropertyDataSyncService with Partial Data Handling

**Files:**
- Modify: `app/services/property_data_sync_service.rb`
- Test: `test/services/property_data_sync_service_test.rb`

- [ ] **Step 1: Write the failing tests for new behavior**

```ruby
# test/services/property_data_sync_service_test.rb
# Add these tests to the existing test file:
require "test_helper"
require "test_helpers/data_provider_test_helper"

class PropertyDataSyncServiceTest < ActiveSupport::TestCase
  include DataProviderTestHelper

  setup do
    @user = users(:default)
  end

  test "accepts user parameter" do
    with_mock_mode do
      result = PropertyDataSyncService.call(case_number: "2026타경01234", user: @user)
      assert result.court_data.present?
    end
  end

  test "returns Result with court_data, building_data, registry_data, errors" do
    with_mock_mode do
      result = PropertyDataSyncService.call(case_number: "2026타경01234", user: @user)
      assert_respond_to result, :court_data
      assert_respond_to result, :building_data
      assert_respond_to result, :registry_data
      assert_respond_to result, :errors
    end
  end

  test "errors hash is empty on full success" do
    with_mock_mode do
      result = PropertyDataSyncService.call(case_number: "2026타경01234", user: @user)
      assert_empty result.errors
    end
  end

  test "works without user parameter (backward compatibility)" do
    with_mock_mode do
      result = PropertyDataSyncService.call(case_number: "2026타경01234")
      assert result.court_data.present?
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/property_data_sync_service_test.rb`
Expected: FAIL — argument errors or missing methods

- [ ] **Step 3: Rewrite PropertyDataSyncService**

```ruby
# app/services/property_data_sync_service.rb
class PropertyDataSyncService
  Result = Data.define(:court_data, :building_data, :registry_data, :errors, :property)

  def self.call(case_number:, user: nil)
    new(case_number:, user:).call
  end

  def initialize(case_number:, user: nil)
    @case_number = case_number
    @user = user
  end

  def call
    errors = {}

    court_data = fetch_source(:court_auction, errors, :court) { |config|
      CourtAuctionAdapter.for(config).fetch_data(case_number: @case_number)
    }

    building_data = fetch_source(:data_go_kr, errors, :building) { |config|
      BuildingLedgerAdapter.for(config).fetch_data(case_number: @case_number)
    }

    registry_data = fetch_source_by_category(:registry, errors, :registry) { |config|
      RegistryTranscriptAdapter.for(config).fetch_data(case_number: @case_number)
    }

    property = persist_property(court_data, building_data, registry_data) if court_data

    Result.new(
      court_data: court_data,
      building_data: building_data,
      registry_data: registry_data,
      errors: errors,
      property: property
    )
  end

  private

  def fetch_source(provider_name, errors, error_key)
    config = CredentialResolver.new(user: @user, provider_name: provider_name).resolve
    yield(config)
  rescue DataProvider::Error => e
    errors[error_key] = e
    nil
  end

  def fetch_source_by_category(category, errors, error_key)
    config = CredentialResolver.new(user: @user, category: category).resolve
    yield(config)
  rescue DataProvider::Error => e
    errors[error_key] = e
    nil
  end

  def persist_property(court_data, building_data, registry_data)
    property = Property.find_or_initialize_by(case_number: @case_number)
    property.assign_attributes(
      court_name: court_data[:court_name],
      property_type: court_data[:property_type],
      address: court_data[:address],
      appraisal_price: court_data[:appraisal_price],
      min_bid_price: court_data[:min_bid_price],
      raw_data: {
        court_auction: court_data.deep_stringify_keys,
        building_ledger: building_data&.deep_stringify_keys,
        registry_transcript: registry_data&.deep_stringify_keys
      }
    )
    property.save!
    property
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/property_data_sync_service_test.rb`
Expected: All tests pass

- [ ] **Step 5: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass. Check if any existing code calls `PropertyDataSyncService` and update callers to handle the new `Result` return type.

- [ ] **Step 6: Commit**

```bash
git add app/services/property_data_sync_service.rb test/services/property_data_sync_service_test.rb
git commit -m "feat: add partial data handling and user context to PropertyDataSyncService"
```

---

## Task 7: ApplicationController Error Handlers

**Files:**
- Modify: `app/controllers/application_controller.rb`
- Test: `test/controllers/application_controller_error_handling_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/controllers/application_controller_error_handling_test.rb
require "test_helper"

class ApplicationControllerErrorHandlingTest < ActionDispatch::IntegrationTest
  # Test through a real route — property creation triggers data sync
  # which can raise DataProvider errors

  test "MissingCredentialError redirects to settings with alert" do
    PropertiesController.any_instance.stubs(:create).raises(
      DataProvider::MissingCredentialError.new("공공데이터포털 API 키를 설정해주세요.")
    )
    post properties_path, params: { case_number: "2026타경99999" }
    assert_redirected_to settings_data_sources_path
    assert_equal "이 기능을 사용하려면 API 키를 설정해주세요.", flash[:alert]
  end

  test "ConsentRequiredError redirects to settings with alert" do
    PropertiesController.any_instance.stubs(:create).raises(
      DataProvider::ConsentRequiredError.new("동의 필요")
    )
    post properties_path, params: { case_number: "2026타경99999" }
    assert_redirected_to settings_data_sources_path
    assert_equal "법원경매 데이터 수집에 동의해주세요.", flash[:alert]
  end
end
```

> **Note:** These tests require the settings routes (Task 8) to exist for `settings_data_sources_path`. If running in strict TDD order, stub the route helper or implement Task 8 first. Alternatively, test the handler methods directly.

- [ ] **Step 2: Add rescue_from handlers to ApplicationController**

```ruby
# app/controllers/application_controller.rb
# Add after the allow_browser line:

  rescue_from DataProvider::MissingCredentialError, with: :handle_missing_credential
  rescue_from DataProvider::ConsentRequiredError, with: :handle_consent_required
  rescue_from DataProvider::InvalidCredentialError, with: :handle_invalid_credential
  rescue_from DataProvider::ConnectionError, with: :handle_connection_error
  rescue_from DataProvider::RateLimitError, with: :handle_rate_limit
  rescue_from DataProvider::DataNotFoundError, with: :handle_data_not_found
  rescue_from DataProvider::ParseError, with: :handle_parse_error
  rescue_from DataProvider::SiteStructureChangedError, with: :handle_site_changed
  rescue_from DataProvider::ServiceUnavailableError, with: :handle_service_unavailable
  rescue_from DataProvider::Error, with: :handle_generic_provider_error

# Add to private section:

  def handle_missing_credential(_error)
    redirect_to settings_data_sources_path, alert: "이 기능을 사용하려면 API 키를 설정해주세요."
  end

  def handle_consent_required(_error)
    redirect_to settings_data_sources_path, alert: "법원경매 데이터 수집에 동의해주세요."
  end

  def handle_invalid_credential(_error)
    redirect_to settings_data_sources_path, alert: "API 키가 유효하지 않습니다. 확인 후 다시 설정해주세요."
  end

  def handle_connection_error(_error)
    flash.now[:alert] = "외부 서비스에 연결할 수 없습니다. 잠시 후 다시 시도해주세요."
    render "shared/error", status: :service_unavailable
  end

  def handle_rate_limit(_error)
    flash.now[:alert] = "API 호출 한도에 도달했습니다. 잠시 후 다시 시도해주세요."
    render "shared/error", status: :too_many_requests
  end

  def handle_data_not_found(_error)
    flash.now[:notice] = "해당 사건번호의 데이터를 찾을 수 없습니다."
    render "shared/error", status: :not_found
  end

  def handle_parse_error(error)
    Rails.logger.error("[DataProvider::ParseError] #{error.message}")
    flash.now[:alert] = "데이터 형식이 예상과 다릅니다. 관리자에게 문의해주세요."
    render "shared/error", status: :internal_server_error
  end

  def handle_site_changed(error)
    Rails.logger.error("[DataProvider::SiteStructureChangedError] #{error.message}")
    flash.now[:alert] = "법원경매 사이트 구조가 변경되었습니다. 업데이트가 필요합니다."
    render "shared/error", status: :internal_server_error
  end

  def handle_service_unavailable(_error)
    flash.now[:alert] = "외부 서비스가 일시적으로 중단되었습니다. 잠시 후 다시 시도해주세요."
    render "shared/error", status: :service_unavailable
  end

  def handle_generic_provider_error(error)
    Rails.logger.error("[DataProvider::Error] #{error.class}: #{error.message}")
    flash.now[:alert] = "데이터 조회 중 오류가 발생했습니다."
    render "shared/error", status: :internal_server_error
  end
```

- [ ] **Step 3: Create shared error view**

```erb
<%# app/views/shared/error.html.erb %>
<div class="mx-auto max-w-lg px-4 py-16 text-center">
  <h1 class="text-2xl font-bold text-gray-900"><%= flash[:alert] || flash[:notice] %></h1>
  <p class="mt-4 text-gray-600">
    <%= link_to "돌아가기", :back, class: "text-blue-600 hover:underline" %>
  </p>
</div>
```

- [ ] **Step 4: Run test (may need route — see note above)**

Run: `bin/rails test test/controllers/application_controller_error_handling_test.rb`
Expected: Tests pass after Task 8 routes are added

- [ ] **Step 5: Commit**

```bash
git add app/controllers/application_controller.rb app/views/shared/error.html.erb test/controllers/application_controller_error_handling_test.rb
git commit -m "feat: add DataProvider rescue_from handlers to ApplicationController"
```

---

## Task 8: Routes and Settings Controllers

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/settings/data_sources_controller.rb`
- Create: `app/controllers/settings/api_credentials_controller.rb`
- Create: `app/views/settings/data_sources/show.html.erb`
- Test: `test/controllers/settings/data_sources_controller_test.rb`
- Test: `test/controllers/settings/api_credentials_controller_test.rb`

- [ ] **Step 1: Add routes**

```ruby
# config/routes.rb — inside the existing namespace :settings block, add:
  resource :data_sources, only: [:show]
  resources :api_credentials, only: [:create, :update, :destroy] do
    member do
      post :verify
    end
  end
```

- [ ] **Step 2: Write failing controller tests**

```ruby
# test/controllers/settings/data_sources_controller_test.rb
require "test_helper"

class Settings::DataSourcesControllerTest < ActionDispatch::IntegrationTest
  test "show displays all providers" do
    get settings_data_sources_path
    assert_response :success
    assert_select "h1", /데이터 소스 설정/
  end
end
```

```ruby
# test/controllers/settings/api_credentials_controller_test.rb
require "test_helper"

class Settings::ApiCredentialsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:default)
    # Ensure guest session
    get root_path
  end

  test "create saves encrypted credential" do
    assert_difference "ApiCredential.count", 1 do
      post settings_api_credentials_path, params: {
        api_credential: { provider_name: "data_go_kr", api_key: "test-api-key-123" }
      }
    end
    assert_redirected_to settings_data_sources_path
    cred = ApiCredential.last
    assert_equal "data_go_kr", cred.provider_name
    assert_equal "test-api-key-123", cred.api_key
  end

  test "create rejects invalid provider" do
    assert_no_difference "ApiCredential.count" do
      post settings_api_credentials_path, params: {
        api_credential: { provider_name: "invalid", api_key: "key" }
      }
    end
  end

  test "update changes api_key" do
    cred = ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "old-key")
    patch settings_api_credential_path(cred), params: {
      api_credential: { api_key: "new-key" }
    }
    assert_redirected_to settings_data_sources_path
    assert_equal "new-key", cred.reload.api_key
  end

  test "destroy removes credential" do
    cred = ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "key")
    assert_difference "ApiCredential.count", -1 do
      delete settings_api_credential_path(cred)
    end
  end

  test "update for court_auction toggles enabled" do
    cred = ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: false)
    patch settings_api_credential_path(cred), params: {
      api_credential: { enabled: true }
    }
    assert cred.reload.enabled?
  end

  test "verify enqueues CredentialVerificationJob" do
    cred = ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "key")
    assert_enqueued_with(job: CredentialVerificationJob, args: [cred]) do
      post verify_settings_api_credential_path(cred)
    end
  end

  test "cannot access another user's credential" do
    other_user = User.create!(email: "other@test.com", password: "123456")
    cred = ApiCredential.create!(user: other_user, provider_name: "data_go_kr", api_key: "key")
    assert_raises(ActiveRecord::RecordNotFound) do
      patch settings_api_credential_path(cred), params: { api_credential: { api_key: "hacked" } }
    end
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/controllers/settings/data_sources_controller_test.rb test/controllers/settings/api_credentials_controller_test.rb`
Expected: FAIL — controller not found

- [ ] **Step 4: Write DataSourcesController**

```ruby
# app/controllers/settings/data_sources_controller.rb
module Settings
  class DataSourcesController < ApplicationController
    def show
      @providers = ApiCredential::PROVIDERS
      @credentials = current_user.api_credentials.index_by(&:provider_name)
    end
  end
end
```

- [ ] **Step 5: Write ApiCredentialsController**

```ruby
# app/controllers/settings/api_credentials_controller.rb
module Settings
  class ApiCredentialsController < ApplicationController
    def create
      @credential = current_user.api_credentials.build(credential_params)
      if @credential.save
        redirect_to settings_data_sources_path, notice: "데이터 소스가 설정되었습니다."
      else
        redirect_to settings_data_sources_path, alert: "설정에 실패했습니다."
      end
    end

    def update
      credential = find_credential
      if credential.update(credential_params)
        redirect_to settings_data_sources_path, notice: "설정이 업데이트되었습니다."
      else
        redirect_to settings_data_sources_path, alert: "업데이트에 실패했습니다."
      end
    end

    def destroy
      find_credential.destroy!
      redirect_to settings_data_sources_path, notice: "데이터 소스 설정이 삭제되었습니다."
    end

    def verify
      credential = find_credential
      CredentialVerificationJob.perform_later(credential)
      redirect_to settings_data_sources_path, notice: "키 검증을 시작했습니다."
    end

    private

    def find_credential
      current_user.api_credentials.find(params[:id])
    end

    def credential_params
      params.expect(api_credential: [:provider_name, :api_key, :api_secret, :enabled])
    end
  end
end
```

- [ ] **Step 6: Write the view**

```erb
<%# app/views/settings/data_sources/show.html.erb %>
<div class="mx-auto max-w-2xl px-4 py-8">
  <h1 class="text-2xl font-bold text-gray-900 mb-2">데이터 소스 설정</h1>
  <p class="text-gray-600 mb-8">각 데이터 소스의 API 키를 설정하면 실제 데이터를 조회할 수 있습니다.</p>

  <div class="space-y-4">
    <% @providers.each do |key, config| %>
      <% credential = @credentials[key.to_s] %>
      <%= render DataSourceCardComponent.new(
        provider_key: key,
        config: config,
        credential: credential
      ) %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 7: Run tests**

Run: `bin/rails test test/controllers/settings/data_sources_controller_test.rb test/controllers/settings/api_credentials_controller_test.rb`
Expected: Tests pass (some may need the ViewComponent from Task 9 — stub if needed)

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/settings/data_sources_controller.rb app/controllers/settings/api_credentials_controller.rb app/views/settings/data_sources/show.html.erb test/controllers/settings/
git commit -m "feat: add data sources settings page with credential CRUD and verify"
```

---

## Task 9: ViewComponents for Data Source Cards

**Files:**
- Create: `app/components/data_source_card_component.rb`
- Create: `app/components/data_source_card_component.html.erb`
- Create: `app/components/credential_status_badge_component.rb`
- Create: `app/components/credential_status_badge_component.html.erb`
- Test: `test/components/data_source_card_component_test.rb`
- Test: `test/components/credential_status_badge_component_test.rb`

- [ ] **Step 1: Write failing tests for CredentialStatusBadgeComponent**

```ruby
# test/components/credential_status_badge_component_test.rb
require "test_helper"

class CredentialStatusBadgeComponentTest < ViewComponent::TestCase
  test "renders not_configured state" do
    render_inline(CredentialStatusBadgeComponent.new(credential: nil, requires_key: true))
    assert_selector "span", text: "미설정"
    assert_selector "span.text-gray-500"
  end

  test "renders active state when verified recently" do
    cred = ApiCredential.new(api_key: "key", enabled: true, last_verified_at: 1.day.ago)
    render_inline(CredentialStatusBadgeComponent.new(credential: cred, requires_key: true))
    assert_selector "span", text: "활성"
    assert_selector "span.text-green-600"
  end

  test "renders unverified state when never verified" do
    cred = ApiCredential.new(api_key: "key", enabled: true, last_verified_at: nil)
    render_inline(CredentialStatusBadgeComponent.new(credential: cred, requires_key: true))
    assert_selector "span", text: "미검증"
    assert_selector "span.text-yellow-600"
  end

  test "renders disabled state" do
    cred = ApiCredential.new(api_key: "key", enabled: false)
    render_inline(CredentialStatusBadgeComponent.new(credential: cred, requires_key: true))
    assert_selector "span", text: "비활성"
    assert_selector "span.text-gray-500"
  end

  test "renders consent-based active state" do
    cred = ApiCredential.new(enabled: true)
    render_inline(CredentialStatusBadgeComponent.new(credential: cred, requires_key: false))
    assert_selector "span", text: "활성"
  end
end
```

- [ ] **Step 2: Write CredentialStatusBadgeComponent**

```ruby
# app/components/credential_status_badge_component.rb
class CredentialStatusBadgeComponent < ViewComponent::Base
  def initialize(credential:, requires_key:)
    @credential = credential
    @requires_key = requires_key
  end

  def status
    return :not_configured unless @credential

    if !@credential.enabled?
      :disabled
    elsif @requires_key && @credential.api_key.blank?
      :not_configured
    elsif @credential.last_verified_at.present? && @credential.last_verified_at > 30.days.ago
      :active
    elsif @requires_key && @credential.api_key.present?
      :unverified
    else
      :active  # consent-only, enabled
    end
  end

  def label
    { not_configured: "미설정", active: "활성", unverified: "미검증", disabled: "비활성" }[status]
  end

  def color_class
    { not_configured: "text-gray-500", active: "text-green-600", unverified: "text-yellow-600", disabled: "text-gray-500" }[status]
  end
end
```

```erb
<%# app/components/credential_status_badge_component.html.erb %>
<span class="inline-flex items-center gap-1 text-sm font-medium <%= color_class %>">
  <span class="inline-block w-2 h-2 rounded-full bg-current"></span>
  <%= label %>
</span>
```

- [ ] **Step 3: Write DataSourceCardComponent**

```ruby
# app/components/data_source_card_component.rb
class DataSourceCardComponent < ViewComponent::Base
  def initialize(provider_key:, config:, credential:)
    @provider_key = provider_key
    @config = config
    @credential = credential
  end

  def consent_provider?
    @config[:requires_consent] == true
  end

  def key_provider?
    @config[:requires_key] == true
  end

  def credential_exists?
    @credential.present?
  end

  def form_url
    if credential_exists?
      helpers.settings_api_credential_path(@credential)
    else
      helpers.settings_api_credentials_path
    end
  end

  def form_method
    credential_exists? ? :patch : :post
  end

  def verify_url
    helpers.verify_settings_api_credential_path(@credential) if credential_exists?
  end

  def delete_url
    helpers.settings_api_credential_path(@credential) if credential_exists? && key_provider?
  end
end
```

```erb
<%# app/components/data_source_card_component.html.erb %>
<div class="rounded-lg border border-gray-200 p-4">
  <div class="flex items-center justify-between mb-2">
    <h3 class="font-semibold text-gray-900"><%= @config[:name_ko] %></h3>
    <%= render CredentialStatusBadgeComponent.new(
      credential: @credential,
      requires_key: key_provider?
    ) %>
  </div>

  <p class="text-sm text-gray-600 mb-4"><%= @config[:description_ko] %></p>

  <% if consent_provider? %>
    <%# Consent toggle for scraping providers %>
    <%= form_with(
      url: credential_exists? ? form_url : helpers.settings_api_credentials_path,
      method: credential_exists? ? :patch : :post,
      class: "flex items-center gap-3"
    ) do |f| %>
      <% unless credential_exists? %>
        <%= f.hidden_field :provider_name, value: @provider_key %>
      <% end %>
      <label class="relative inline-flex items-center cursor-pointer">
        <%= f.check_box :enabled,
          checked: @credential&.enabled?,
          class: "sr-only peer",
          onchange: "this.form.requestSubmit()" %>
        <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:bg-blue-600 after:content-[''] after:absolute after:top-[2px] after:start-[2px] after:bg-white after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:after:translate-x-full"></div>
      </label>
      <span class="text-sm text-gray-600">데이터 수집 동의</span>
    <% end %>

    <% if consent_provider? %>
      <p class="mt-2 text-xs text-yellow-700 bg-yellow-50 rounded p-2">
        ⚠ 자동 수집은 이용약관에 따라 제한될 수 있습니다. 사용자 책임 하에 활성화해주세요.
      </p>
    <% end %>

  <% elsif key_provider? %>
    <%# API key form %>
    <%= form_with(
      url: form_url,
      method: form_method,
      class: "space-y-3"
    ) do |f| %>
      <% unless credential_exists? %>
        <%= f.hidden_field :provider_name, value: @provider_key %>
      <% end %>

      <div>
        <label class="block text-sm font-medium text-gray-700 mb-1">API 키</label>
        <%= f.text_field :api_key,
          placeholder: credential_exists? ? "새 키를 입력하세요" : "API 키를 입력하세요",
          class: "w-full rounded-md border-gray-300 shadow-sm text-sm" %>
      </div>

      <div class="flex items-center gap-2">
        <%= f.submit credential_exists? ? "업데이트" : "저장",
          class: "px-3 py-1.5 bg-blue-600 text-white text-sm rounded-md hover:bg-blue-700" %>

        <% if credential_exists? %>
          <%= button_to "검증",
            verify_url,
            method: :post,
            class: "px-3 py-1.5 bg-gray-100 text-gray-700 text-sm rounded-md hover:bg-gray-200" %>
          <%= button_to "삭제",
            delete_url,
            method: :delete,
            data: { turbo_confirm: "정말 삭제하시겠습니까?" },
            class: "px-3 py-1.5 text-red-600 text-sm hover:underline" %>
        <% end %>
      </div>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 4: Write DataSourceCardComponent test**

```ruby
# test/components/data_source_card_component_test.rb
require "test_helper"

class DataSourceCardComponentTest < ViewComponent::TestCase
  test "renders consent provider with toggle" do
    config = ApiCredential::PROVIDERS[:court_auction]
    render_inline(DataSourceCardComponent.new(
      provider_key: :court_auction, config: config, credential: nil
    ))
    assert_selector "h3", text: "법원경매정보"
    assert_text "데이터 수집 동의"
  end

  test "renders key provider with API key form" do
    config = ApiCredential::PROVIDERS[:data_go_kr]
    render_inline(DataSourceCardComponent.new(
      provider_key: :data_go_kr, config: config, credential: nil
    ))
    assert_selector "h3", text: "공공데이터포털"
    assert_selector "input[placeholder='API 키를 입력하세요']"
  end

  test "renders verify button when credential exists" do
    user = users(:default)
    cred = ApiCredential.create!(user: user, provider_name: "data_go_kr", api_key: "key")
    config = ApiCredential::PROVIDERS[:data_go_kr]
    render_inline(DataSourceCardComponent.new(
      provider_key: :data_go_kr, config: config, credential: cred
    ))
    assert_selector "button", text: "검증"
    assert_selector "button", text: "삭제"
  end
end
```

- [ ] **Step 5: Run tests**

Run: `bin/rails test test/components/data_source_card_component_test.rb test/components/credential_status_badge_component_test.rb`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add app/components/data_source_card_component* app/components/credential_status_badge_component* test/components/
git commit -m "feat: add DataSourceCard and CredentialStatusBadge ViewComponents"
```

---

## Task 10: CredentialVerificationJob

**Files:**
- Create: `app/jobs/credential_verification_job.rb`
- Test: `test/jobs/credential_verification_job_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/jobs/credential_verification_job_test.rb
require "test_helper"

class CredentialVerificationJobTest < ActiveJob::TestCase
  setup do
    @user = users(:default)
    @credential = ApiCredential.create!(
      user: @user,
      provider_name: "data_go_kr",
      api_key: "test-key"
    )
  end

  test "updates last_verified_at on success" do
    # Mock adapter verification — will be replaced when real adapters exist
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

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/jobs/credential_verification_job_test.rb`
Expected: FAIL — `NameError: uninitialized constant CredentialVerificationJob`

- [ ] **Step 3: Write the job**

```ruby
# app/jobs/credential_verification_job.rb
class CredentialVerificationJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(credential) { "verify_credential_#{credential.id}" }

  def perform(credential)
    return unless credential.persisted?

    # For now, mark as verified. Real verification will be added
    # when individual adapter specs are implemented.
    credential.update!(last_verified_at: Time.current)
  rescue ActiveRecord::RecordNotFound
    # Credential deleted between enqueue and execution — discard
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/jobs/credential_verification_job_test.rb`
Expected: All tests pass

- [ ] **Step 5: Commit**

```bash
git add app/jobs/credential_verification_job.rb test/jobs/credential_verification_job_test.rb
git commit -m "feat: add CredentialVerificationJob with concurrency limit and delete guard"
```

---

## Task 11: PII Filter and Cleanup

**Files:**
- Modify: `config/initializers/filter_parameter_logging.rb`

- [ ] **Step 1: Update filter parameters**

```ruby
# config/initializers/filter_parameter_logging.rb
Rails.application.config.filter_parameters += [
  :passw, :email, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn, :cvv, :cvc,
  :api_key, :api_secret,
  :owner_name, :holder_name, :tenant_name,
  :resident_number, :phone
]
```

- [ ] **Step 2: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass

- [ ] **Step 3: Run linter and security checks**

Run: `bin/rubocop -a && bin/brakeman --quiet --no-pager`
Expected: No new issues

- [ ] **Step 4: Commit**

```bash
git add config/initializers/filter_parameter_logging.rb
git commit -m "security: add PII and API key filtering to log parameters"
```

---

## Task 12: Integration Smoke Test

**Files:**
- Test: `test/integration/data_provider_flow_test.rb`

- [ ] **Step 1: Write end-to-end integration test**

```ruby
# test/integration/data_provider_flow_test.rb
require "test_helper"

class DataProviderFlowTest < ActionDispatch::IntegrationTest
  test "full flow: visit settings, add key, verify, use in property sync" do
    # 1. Visit settings page
    get settings_data_sources_path
    assert_response :success

    # 2. Add a data.go.kr credential
    post settings_api_credentials_path, params: {
      api_credential: { provider_name: "data_go_kr", api_key: "my-test-key" }
    }
    assert_redirected_to settings_data_sources_path
    cred = ApiCredential.last
    assert_equal "data_go_kr", cred.provider_name
    assert_equal "my-test-key", cred.api_key  # decrypted value

    # 3. Verify the credential
    post verify_settings_api_credential_path(cred)
    assert_redirected_to settings_data_sources_path

    # 4. Property sync works with mock mode (default)
    result = PropertyDataSyncService.call(case_number: "2026타경01234", user: cred.user)
    assert result.court_data.present?
    assert_empty result.errors
  end

  test "consent flow for court_auction" do
    # 1. Create consent credential
    post settings_api_credentials_path, params: {
      api_credential: { provider_name: "court_auction", enabled: true }
    }
    cred = ApiCredential.last
    assert_equal "court_auction", cred.provider_name
    assert cred.enabled?
    assert cred.configured?

    # 2. Toggle off
    patch settings_api_credential_path(cred), params: {
      api_credential: { enabled: false }
    }
    assert_not cred.reload.enabled?
    assert_not cred.configured?
  end

  test "credential resolver uses category-aware resolution" do
    user = users(:default)
    ApiCredential.create!(user: user, provider_name: "codef", api_key: "codef-key", enabled: true)

    ENV["USE_MOCK"] = "false"
    result = CredentialResolver.new(user: user, category: :registry).resolve
    assert_equal :real, result[:adapter]
    assert_equal :codef, result[:provider]
  ensure
    ENV.delete("USE_MOCK")
  end
end
```

- [ ] **Step 2: Run integration test**

Run: `bin/rails test test/integration/data_provider_flow_test.rb`
Expected: All tests pass

- [ ] **Step 3: Run full CI pipeline**

Run: `bin/ci`
Expected: All checks pass (rubocop, brakeman, tests, seed check)

- [ ] **Step 4: Commit**

```bash
git add test/integration/data_provider_flow_test.rb
git commit -m "test: add end-to-end integration tests for data provider flow"
```

---

## Summary

| Task | What | Estimated Steps |
|------|------|----------------|
| 1 | Faraday dependency | 3 |
| 2 | DataProvider error hierarchy | 5 |
| 3 | ApiCredential model + migration | 10 |
| 4 | CredentialResolver service | 6 |
| 5 | Update adapter factories | 10 |
| 6 | PropertyDataSyncService partial data | 6 |
| 7 | ApplicationController error handlers | 5 |
| 8 | Routes + Settings controllers | 8 |
| 9 | ViewComponents (cards + badges) | 6 |
| 10 | CredentialVerificationJob | 5 |
| 11 | PII filter cleanup | 4 |
| 12 | Integration smoke test | 4 |
| **Total** | | **72 steps** |
