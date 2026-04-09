# Data Provider Architecture & BYOK Settings System

> **Scope**: Common provider infrastructure — adapter factory pattern, API credential management, error handling, and settings UI framework.
> Individual data source implementations (CourtAuction scraper, DataGoKr API, Tilko API, Hyphen API) are covered in separate specs.

## Context

The application currently uses an Adapter pattern with 4 base adapters (`CourtAuctionAdapter`, `BuildingLedgerAdapter`, `RegistryTranscriptAdapter`, `LoanPolicyAdapter`), each with Mock and Government implementations. A global `ENV["USE_MOCK"]` flag toggles between them.

This works for development but cannot support production scenarios where:
- Different data sources require different API keys (BYOK — Bring Your Own Key)
- Some sources are free (public data portal) while others are per-transaction paid (Tilko)
- One source (courtauction.go.kr) requires user consent rather than an API key
- Users should see which data sources are active and manage their credentials

### Related Specs

- [SRS v1.0](2026-04-05-srs-design.md) — Features F01-F11, design principles
- [F02 Data Acquisition Amendment](2026-04-06-f02-data-acquisition-amendment.md) — Property data flow
- [F03 Rights Analysis](2026-04-06-f03-rights-analysis-report-design.md) — Registry data consumer

### Design Principles Applied

- **Overconfidence Prevention** (SRS): Never silently fall back to mock/sample data. If real data is unavailable, show an explicit error.
- **Adapter Pattern** (STANDARDS.md): Extend existing `BaseAdapter.for(provider)` pattern rather than replacing it.

---

## Decision Summary

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Spec scope | Common infra only; individual sources get separate specs | Each source has distinct complexity (scraping vs REST API vs paid API) |
| BYOK UX | Settings page UI with encrypted DB storage | Target audience is general users, not DevOps; `ENV` vars are too technical |
| Provider switching | Auto-detect based on API key presence | "Enter key, it works" — simplest mental model for users |
| Scraping consent | Explicit user opt-in toggle | Legal risk transparency for open-source project |
| Error handling | Explicit errors only, no mock fallback | Auction data errors can cause financial harm; aligns with overconfidence prevention |
| Architecture approach | Extend existing adapter `.for` factory | Minimal change, 4 adapters don't justify a registry system |
| Credential resolution | Service layer resolves credentials, adapters receive config only | Decouples adapters from user context; supports background jobs (Solid Queue) |
| API key UI security | Write-only — keys never rendered back to browser after save | Prevents XSS-based key exfiltration |
| Key verification | Async via Solid Queue + Turbo Stream status update | Prevents request blocking on external API timeouts |
| Registry providers | Support both Tilko and Codef behind adapter pattern | Gives users choice; Codef has better stability reputation |
| Partial data | Fetch-and-collect pattern — each source independent, partial success allowed | One provider failure should not lose data from other providers |
| Data freshness | Track `data_fetched_at` per source on Property, warn on stale data | Prevents bidding decisions based on outdated legal information |
| Category-aware resolution | CredentialResolver can resolve by category (e.g., any `:registry` provider) | Supports Tilko↔Codef switching and failover |
| HTTP resilience | Common timeout, retry, and circuit breaker configuration for all adapters | Prevents cascade failures from slow external APIs |
| Data normalization | Canonical format for amounts (integer won), addresses, case numbers | Ensures consistency across providers |
| Log safety | Filter PII and API keys from all logs | Korean PIPA compliance |

---

## 1. ApiCredential Model

Stores per-user API credentials with encryption at rest.

### Schema

```ruby
create_table :api_credentials do |t|
  t.references :user, null: false, foreign_key: true
  t.string :provider_name, null: false    # e.g., "court_auction", "data_go_kr", "tilko", "hyphen"
  t.string :api_key                       # encrypted via Rails 8 encrypts
  t.string :api_secret                    # encrypted, nullable (some APIs need both)
  t.boolean :enabled, default: true       # user can temporarily disable
  t.datetime :last_verified_at            # last successful key validation
  t.timestamps

  t.index [:user_id, :provider_name], unique: true
end
```

### Model

```ruby
class ApiCredential < ApplicationRecord
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
      enabled?  # consent-only providers (court_auction)
    end
  end
end
```

### Provider Registry Constant

Defined on `ApiCredential` as the single source of truth for available providers:

```ruby
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
```

### User Association

```ruby
class User < ApplicationRecord
  has_many :api_credentials, dependent: :destroy
end
```

---

## 2. Adapter Factory Enhancement

### Current Pattern

```ruby
class CourtAuctionAdapter
  def self.for
    ENV["USE_MOCK"] == "false" ? GovernmentCourtAuctionAdapter.new : MockCourtAuctionAdapter.new
  end
end
```

### New Pattern

Credential resolution is decoupled from adapters. Adapters are **user-agnostic** — they receive configuration (API keys), not user objects. The service layer is responsible for resolving which adapter and credentials to use.

#### CredentialResolver (new)

A single class that encapsulates the three-tier resolution logic. Supports both **direct provider resolution** (by name) and **category-aware resolution** (find any configured provider in a category, e.g., any `:registry` provider).

```ruby
class CredentialResolver
  def initialize(user:, provider_name: nil, category: nil)
    @user = user
    @provider_name = provider_name
    @category = category
    raise ArgumentError, "provider_name or category required" unless @provider_name || @category
  end

  def resolve
    # Tier 1: ENV override (development/test)
    return { adapter: :mock } if mock_mode?

    # Tier 2: User credential check (by name or category)
    credential = find_credential
    if credential&.configured?
      {
        adapter: :real,
        provider: credential.provider_name.to_sym,
        api_key: credential.api_key,
        api_secret: credential.api_secret
      }
    else
      # Tier 3: No credential — mock (dev) or raise (prod)
      if Rails.env.production?
        raise error_for_provider
      else
        { adapter: :mock }
      end
    end
  end

  private

  def find_credential
    return nil unless @user

    if @provider_name
      # Direct lookup by provider name
      @user.api_credentials.active.for_provider(@provider_name)
    else
      # Category-aware: find any configured provider in this category
      providers_in_category = ApiCredential::PROVIDERS
        .select { |_, v| v[:category] == @category }
        .keys.map(&:to_s)
      @user.api_credentials.active
        .where(provider_name: providers_in_category)
        .order(:created_at)  # prefer the one configured first
        .first
    end
  end

  def mock_mode?
    ENV["USE_MOCK"] != "false"
  end

  def error_for_provider
    config = if @provider_name
      ApiCredential::PROVIDERS[@provider_name.to_sym]
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

**Category-aware resolution** enables:
- User has Codef but not Tilko → `resolve(category: :registry)` returns Codef config
- User switches from Tilko to Codef → just disable Tilko, enable Codef; no code change needed
- Failover is not automatic (too risky for paid APIs), but manual switching is seamless

#### Adapter Factory (simplified)

Adapters no longer know about users or credentials. They receive config:

```ruby
class CourtAuctionAdapter
  PROVIDER_NAME = :court_auction

  def self.for(config = {})
    if config[:adapter] == :real
      GovernmentCourtAuctionAdapter.new
    else
      MockCourtAuctionAdapter.new
    end
  end
end

class BuildingLedgerAdapter
  PROVIDER_NAME = :data_go_kr

  def self.for(config = {})
    if config[:adapter] == :real
      GovernmentBuildingLedgerAdapter.new(api_key: config[:api_key])
    else
      MockBuildingLedgerAdapter.new
    end
  end
end

class RegistryTranscriptAdapter
  PROVIDER_NAME = :tilko  # default; can also be :codef

  def self.for(config = {})
    case config[:adapter]
    when :real then resolve_real_adapter(config)
    else MockRegistryTranscriptAdapter.new
    end
  end

  def self.resolve_real_adapter(config)
    # Multiple real providers for registry — resolve by provider_name
    case config[:provider]
    when :codef then CodefRegistryAdapter.new(api_key: config[:api_key])
    else TilkoRegistryAdapter.new(api_key: config[:api_key])
    end
  end
end
```

### Resolution Priority

```
1. ENV["USE_MOCK"] != "false"  →  MockAdapter (always, for dev/test)
2. User has configured credential  →  RealAdapter (with API key injected)
3. No credential + production  →  Raise DataProvider error
4. No credential + development  →  MockAdapter (graceful fallback in dev)
```

### Credential Injection

Real adapters receive API keys as constructor arguments — no knowledge of User or ApiCredential models:

```ruby
class GovernmentBuildingLedgerAdapter < BuildingLedgerAdapter
  def initialize(api_key:)
    @api_key = api_key
  end

  def fetch_data(case_number:)
    # Use @api_key for API calls
  end
end
```

### Backward Compatibility

- Calling `.for` without arguments returns MockAdapter (preserves existing behavior)
- Existing test code using `USE_MOCK` continues to work unchanged
- Background jobs (Solid Queue) can serialize `user_id`, resolve credentials at execution time

### Service Integration

Services resolve credentials and pass config to adapters. Uses **fetch-and-collect** pattern: each provider is fetched independently, failures are recorded but don't block other providers.

```ruby
class PropertyDataSyncService
  Result = Data.define(:court_data, :building_data, :registry_data, :errors)

  def initialize(case_number:, user: nil)
    @case_number = case_number
    @user = user
  end

  def call
    errors = {}

    court_data = fetch_source(:court_auction) { |config|
      CourtAuctionAdapter.for(config).fetch_data(case_number: @case_number)
    } rescue_to errors, :court

    building_data = fetch_source(:data_go_kr) { |config|
      BuildingLedgerAdapter.for(config).fetch_data(case_number: @case_number)
    } rescue_to errors, :building

    registry_data = fetch_source_by_category(:registry) { |config|
      RegistryTranscriptAdapter.for(config).fetch_data(case_number: @case_number)
    } rescue_to errors, :registry

    Result.new(
      court_data: court_data,
      building_data: building_data,
      registry_data: registry_data,
      errors: errors
    )
  end

  private

  def fetch_source(provider_name)
    config = CredentialResolver.new(user: @user, provider_name: provider_name).resolve
    yield(config)
  rescue DataProvider::Error => e
    nil  # error captured by rescue_to
  end

  def fetch_source_by_category(category)
    config = CredentialResolver.new(user: @user, category: category).resolve
    yield(config)
  rescue DataProvider::Error => e
    nil
  end
end
```

> **Note**: The `rescue_to` pattern above is pseudocode illustrating intent. The actual implementation will use begin/rescue blocks to capture errors per source into the `errors` hash while allowing other sources to proceed.

**Partial result handling in controllers:**

```ruby
def create
  result = PropertyDataSyncService.new(case_number: params[:case_number], user: current_user).call

  if result.court_data.nil? && result.errors[:court]
    # Court data is mandatory — cannot create property without it
    handle_primary_source_error(result.errors[:court])
    return
  end

  # Create/update property with whatever data we have
  property = Property.find_or_initialize_by(case_number: params[:case_number])
  property.update!(build_attributes(result))

  # Show warnings for failed secondary sources
  if result.errors.any?
    flash[:warning] = build_partial_data_warning(result.errors)
  end

  redirect_to property
end
```

---

## 3. Error Handling Standard

### Error Hierarchy

All data provider errors inherit from a common base for unified `rescue_from` handling:

```ruby
module DataProvider
  class Error < StandardError; end

  # Credential errors — user action required
  class MissingCredentialError < Error; end   # No API key configured
  class InvalidCredentialError < Error; end   # Key rejected by API
  class ExpiredCredentialError < Error; end   # Key expired

  # External service errors — transient, retry may help
  class ConnectionError < Error; end          # Network failure
  class RateLimitError < Error; end           # API rate limit hit
  class ServiceUnavailableError < Error; end  # Service down (5xx)

  # Data errors — request-specific
  class DataNotFoundError < Error; end        # No data for given case_number
  class ParseError < Error; end               # Response format unexpected

  # Scraping-specific
  class ConsentRequiredError < Error; end     # User hasn't opted in
  class SiteStructureChangedError < Error; end # Scraping target changed
end
```

### Controller Integration

```ruby
class ApplicationController < ActionController::Base
  rescue_from DataProvider::MissingCredentialError, with: :handle_missing_credential
  rescue_from DataProvider::ConsentRequiredError, with: :handle_consent_required
  rescue_from DataProvider::InvalidCredentialError, with: :handle_invalid_credential
  rescue_from DataProvider::ConnectionError, with: :handle_connection_error
  rescue_from DataProvider::RateLimitError, with: :handle_rate_limit
  rescue_from DataProvider::DataNotFoundError, with: :handle_data_not_found
  rescue_from DataProvider::ParseError, with: :handle_parse_error
  rescue_from DataProvider::SiteStructureChangedError, with: :handle_site_changed
  rescue_from DataProvider::ServiceUnavailableError, with: :handle_service_unavailable
  rescue_from DataProvider::Error, with: :handle_generic_provider_error  # catch-all, must be last

  private

  def handle_missing_credential(error)
    redirect_to settings_data_sources_path,
      alert: "이 기능을 사용하려면 API 키를 설정해주세요."
  end

  def handle_consent_required(error)
    redirect_to settings_data_sources_path,
      alert: "법원경매 데이터 수집에 동의해주세요."
  end

  def handle_invalid_credential(error)
    redirect_to settings_data_sources_path,
      alert: "API 키가 유효하지 않습니다. 확인 후 다시 설정해주세요."
  end

  def handle_connection_error(error)
    flash.now[:alert] = "외부 서비스에 연결할 수 없습니다. 잠시 후 다시 시도해주세요."
    render_error_state
  end

  def handle_rate_limit(error)
    flash.now[:alert] = "API 호출 한도에 도달했습니다. 잠시 후 다시 시도해주세요."
    render_error_state
  end

  def handle_data_not_found(error)
    flash.now[:notice] = "해당 사건번호의 데이터를 찾을 수 없습니다."
    render_error_state
  end

  def handle_parse_error(error)
    flash.now[:alert] = "데이터 형식이 예상과 다릅니다. 관리자에게 문의해주세요."
    Rails.logger.error("[DataProvider::ParseError] #{error.message}")
    render_error_state
  end

  def handle_site_changed(error)
    flash.now[:alert] = "법원경매 사이트 구조가 변경되었습니다. 업데이트가 필요합니다."
    Rails.logger.error("[DataProvider::SiteStructureChangedError] #{error.message}")
    render_error_state
  end

  def handle_service_unavailable(error)
    flash.now[:alert] = "외부 서비스가 일시적으로 중단되었습니다. 잠시 후 다시 시도해주세요."
    render_error_state
  end

  def handle_generic_provider_error(error)
    flash.now[:alert] = "데이터 조회 중 오류가 발생했습니다."
    Rails.logger.error("[DataProvider::Error] #{error.class}: #{error.message}")
    render_error_state
  end
end
```

### Adapter Error Wrapping

Each real adapter wraps external exceptions into `DataProvider` errors:

```ruby
def fetch_data(case_number:)
  response = http_client.get(build_url(case_number))
  parse_response(response)
rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
  raise DataProvider::ConnectionError, "#{self.class.name}: #{e.message}"
rescue Faraday::ClientError => e
  if e.response_status == 429
    raise DataProvider::RateLimitError, "API rate limit exceeded"
  elsif e.response_status == 401
    raise DataProvider::InvalidCredentialError, "API key rejected"
  else
    raise DataProvider::Error, "Unexpected error: #{e.message}"
  end
end
```

---

## 4. Settings UI — Data Source Management

### Route

```ruby
# config/routes.rb
namespace :settings do
  resource :data_sources, only: [:show, :update]
  resources :api_credentials, only: [:create, :update, :destroy] do
    member do
      post :verify
    end
  end
end
```

### Page Layout

Added as a section within the existing Settings page, or as a new tab if the Settings page uses tabs.

```
┌─────────────────────────────────────────────────┐
│ 데이터 소스 설정                                    │
│                                                   │
│ 각 데이터 소스의 API 키를 설정하면 실제 데이터를         │
│ 조회할 수 있습니다.                                  │
├─────────────────────────────────────────────────┤
│                                                   │
│ ┌─ 법원경매정보 ──────────────────────────────┐   │
│ │ courtauction.go.kr                          │   │
│ │ 법원경매정보 사이트에서 경매 사건정보를 수집합니다.│   │
│ │                                              │   │
│ │ ⚠ 주의: 자동 수집은 이용약관에 따라 제한될       │   │
│ │ 수 있습니다. 사용자 책임 하에 활성화해주세요.     │   │
│ │                                              │   │
│ │ [토글: 데이터 수집 동의]     상태: ● 비활성     │   │
│ └──────────────────────────────────────────────┘   │
│                                                   │
│ ┌─ 공공데이터포털 (건축물대장) ─────────────────┐   │
│ │ data.go.kr                                   │   │
│ │ 국토교통부 건축물대장정보 API를 조회합니다.       │   │
│ │ data.go.kr에서 무료로 키를 발급받을 수 있습니다.  │   │
│ │                                              │   │
│ │ API 키: [•••••••••••••••] [검증]             │   │
│ │ 상태: ● 미설정                                │   │
│ └──────────────────────────────────────────────┘   │
│                                                   │
│ ┌─ 틸코블렛 (등기부등본) ──────────────────────┐   │
│ │ tilko.net                                    │   │
│ │ 등기부등본을 조회합니다. 건당 과금이 발생합니다.   │   │
│ │                                              │   │
│ │ API 키: [•••••••••••••••] [검증]             │   │
│ │ 상태: ● 미설정                                │   │
│ └──────────────────────────────────────────────┘   │
│                                                   │
│ ┌─ 하이픈 (권리분석) ─────────────────────────┐    │
│ │ codef.io                                     │   │
│ │ 권리분석 데이터를 조회합니다.                     │   │
│ │ 자체 분석 엔진의 대안으로 사용할 수 있습니다.      │   │
│ │                                              │   │
│ │ API 키: [•••••••••••••••] [검증]             │   │
│ │ 상태: ● 미설정                                │   │
│ └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────┘
```

### Status Indicators

| State | Indicator | Condition |
|-------|-----------|-----------|
| Not configured | `● 미설정` (gray) | No API key entered |
| Active | `● 활성` (green) | Key present and `last_verified_at` within 30 days |
| Unverified | `● 미검증` (yellow) | Key present but never verified or verification expired |
| Error | `● 오류` (red) | Last verification failed |
| Disabled | `● 비활성` (gray) | User toggled off |

### API Key Security: Write-Only

**API keys are never rendered back to the browser after save.** This prevents XSS-based key exfiltration.

- On save: key is encrypted and stored in DB. The raw value is discarded from memory.
- On display: UI shows only status (`설정됨` / `미설정`), never the key itself (not even masked).
- On edit: user must enter the full key again. No "current value" is pre-filled.
- Controller never includes `api_key` or `api_secret` in any JSON or HTML response.

### Verification Flow (Async)

Verification runs as a **Solid Queue background job** to prevent request blocking on external API timeouts.

1. User clicks "검증" button
2. Controller enqueues `CredentialVerificationJob` with `credential.id`
3. Status badge immediately updates to "검증 중..." (yellow spinner) via Turbo Stream
4. Job calls adapter's `verify_credential` class method with the stored key
5. On completion, job broadcasts Turbo Stream to update status badge (green/red)

```ruby
class Settings::ApiCredentialsController < ApplicationController
  def verify
    credential = current_user.api_credentials.find(params[:id])
    CredentialVerificationJob.perform_later(credential)
    # Turbo Stream: update status badge to "검증 중..." spinner
  end
end

class CredentialVerificationJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(credential) { "verify_#{credential.id}" }

  def perform(credential)
    return unless credential.persisted?  # guard: user deleted credential before job ran

    adapter_class = adapter_for(credential.provider_name)
    adapter_class.verify_credential(credential)
    credential.update!(last_verified_at: Time.current)
    broadcast_status(credential, :verified)
  rescue ActiveRecord::RecordNotFound
    # Credential deleted between enqueue and execution — silently discard
  rescue DataProvider::InvalidCredentialError => e
    broadcast_status(credential, :invalid, message: e.message)
  rescue DataProvider::ConnectionError => e
    broadcast_status(credential, :connection_error, message: e.message)
  end

  private

  def broadcast_status(credential, status, message: nil)
    Turbo::StreamsChannel.broadcast_replace_to(
      credential.user, :credential_statuses,  # scoped to user, not credential ID
      target: "credential_status_#{credential.id}",
      partial: "settings/api_credentials/status_badge",
      locals: { status: status, message: message }
    )
  end
end
```

### ViewComponent Structure

```
app/components/
  data_source_card_component.rb      # Single provider card
  data_source_card_component.html.erb
  credential_status_badge_component.rb
  credential_status_badge_component.html.erb
```

---

## 5. Individual Data Source Specs (Separate Documents)

This spec defines the shared infrastructure. Each data source gets its own spec covering source-specific concerns:

### Spec 1: CourtAuction Scraper
- **Provider**: `court_auction`
- **Category**: `:auction`
- **Key concerns**: Playwright-based scraping strategy, site structure change detection, consent UX, rate limiting/politeness, `fetch_data` return schema
- **Adapter**: `GovernmentCourtAuctionAdapter`

### Spec 2: DataGoKr Building Ledger API
- **Provider**: `data_go_kr`
- **Category**: `:building_ledger`
- **Key concerns**: REST API integration, user key provisioning guide, XML/JSON response parsing, `fetch_data` return schema
- **Adapter**: `GovernmentBuildingLedgerAdapter`

### Spec 3: Registry Transcript APIs (Tilko + Codef)
- **Providers**: `tilko`, `codef`
- **Category**: `:registry`
- **Key concerns**: Per-transaction billing model, user cost awareness, registry document parsing, `fetch_data` return schema, provider selection (same category, multiple implementations)
- **Adapters**: `TilkoRegistryAdapter`, `CodefRegistryAdapter` — both behind `RegistryTranscriptAdapter.for(config)`
- **Note**: Codef reportedly has better stability and documentation than Tilko. Spec should evaluate both and recommend a default.

### Spec 4: Registry Information Portal (iros.go.kr) — Free Preview
- **Provider**: `iros`
- **Category**: `:registry_preview`
- **Key concerns**: Free tier (1,000 calls/day), summary-only data (no 을구/갑구 details), use as preview before paid full retrieval
- **Adapter**: `IrosRegistryPreviewAdapter`
- **Note**: Cannot replace full 등기부등본. Useful for showing basic ownership info and flagging whether a paid lookup is needed.

### Spec 5: Hyphen Rights Analysis API
- **Provider**: `hyphen`
- **Category**: `:rights_analysis`
- **Key concerns**: Relationship with built-in `RightsAnalysisService`, when to prefer API vs self-analysis, `fetch_data` return schema
- **Adapter**: New adapter class
- **Note**: Hyphen provides data normalization rather than full rights analysis. Self-implementation remains the core value proposition.

### Implementation Priority

```
Phase 1 (MVP): CourtAuction Scraper + DataGoKr Building Ledger
  → Enables: property search + building info lookup

Phase 2: Tilko/Codef Registry API + iros Preview
  → Enables: real registry transcript for rights analysis
  → iros provides free preview before paid full retrieval

Phase 3: Hyphen Rights Analysis API
  → Enables: alternative to built-in analysis engine
```

Each individual spec follows the adapter contract defined here: implement `fetch_data` (or `fetch_policies`), wrap errors in `DataProvider::*` classes, register in `PROVIDERS` constant, and use `CredentialResolver` for credential lookup.

---

## 6. Testing Strategy

### Unit Tests
- `ApiCredential` model: encryption, validation, `configured?` logic
- Adapter `.for(user:)`: mock mode override, credential-based resolution, error raising
- Error hierarchy: correct inheritance, message formatting

### Integration Tests
- Settings UI: create/update/delete credentials, verify flow
- Adapter resolution: end-to-end from service call through credential lookup to adapter selection
- Error handling: `rescue_from` renders correct flash messages and redirects

### Test Helpers

```ruby
# test/test_helpers/data_provider_test_helper.rb
module DataProviderTestHelper
  def with_mock_mode(&block)
    ClimateControl.modify(USE_MOCK: "true", &block)
  end

  def with_real_mode(&block)
    ClimateControl.modify(USE_MOCK: "false", &block)
  end

  def create_credential(user:, provider:, api_key: "test-key-123")
    ApiCredential.create!(
      user: user,
      provider_name: provider.to_s,
      api_key: api_key,
      enabled: true
    )
  end
end
```

---

## 7. Data Freshness Tracking

### Problem

Registry transcripts and auction status change frequently. Users may make bidding decisions based on data fetched days ago without realizing it's stale.

### Solution

Track when each data source was last fetched per property. Display freshness warnings in the UI.

```ruby
# Add to properties table
add_column :properties, :court_data_fetched_at, :datetime
add_column :properties, :building_data_fetched_at, :datetime
add_column :properties, :registry_data_fetched_at, :datetime
```

**Staleness thresholds:**

| Source | Warning after | Critical after |
|--------|--------------|----------------|
| Court auction | 24 hours | 3 days |
| Building ledger | 7 days | 30 days |
| Registry transcript | 24 hours | 3 days |

**UI behavior:**
- Fresh: no indicator
- Warning: yellow badge "N일 전 데이터" with refresh button
- Critical: red badge "데이터가 오래되었습니다. 새로고침해주세요." with prominent refresh CTA
- Registry critical state blocks rights analysis with: "권리분석 전 최신 등기부등본을 조회해주세요."

**Service update:**
```ruby
# In PropertyDataSyncService, after successful fetch:
property.update!(court_data_fetched_at: Time.current) if court_data
property.update!(building_data_fetched_at: Time.current) if building_data
property.update!(registry_data_fetched_at: Time.current) if registry_data
```

---

## 8. HTTP Resilience Standards

### Problem

No timeout, retry, or concurrency configuration exists. A slow external API can block workers indefinitely.

### HTTP Client Configuration

All adapters must use a shared HTTP client configuration:

```ruby
module DataProvider
  HTTP_CONFIG = {
    connect_timeout: 5,      # seconds
    read_timeout: 30,        # seconds (registry parsing can be slow)
    write_timeout: 5,        # seconds
    max_retries: 2,          # for transient errors (5xx, timeout)
    retry_backoff: 1,        # seconds, exponential (1s, 2s)
    retry_statuses: [502, 503, 504],  # only retry server errors
  }.freeze
end
```

```ruby
# Shared Faraday connection builder
module DataProvider
  def self.build_connection(base_url:)
    Faraday.new(url: base_url) do |f|
      f.request :retry,
        max: HTTP_CONFIG[:max_retries],
        interval: HTTP_CONFIG[:retry_backoff],
        backoff_factor: 2,
        retry_statuses: HTTP_CONFIG[:retry_statuses]
      f.options.timeout = HTTP_CONFIG[:read_timeout]
      f.options.open_timeout = HTTP_CONFIG[:connect_timeout]
    end
  end
end
```

### Scraping Concurrency

Court auction scraping (Playwright) is resource-intensive. Limits:

```ruby
# config/queue.yml — dedicated scraping queue
queues:
  - name: scraping
    threads: 1          # max 1 concurrent Playwright session
    polling_interval: 5
  - name: default
    threads: 3
```

Individual scraper spec must also define:
- Minimum delay between page loads (politeness): 2 seconds
- Maximum pages per session: 50
- Browser context reuse within a session

### Korean Government API Quirks

Individual source specs should handle these common patterns:
- **EUC-KR encoding**: Detect via Content-Type header or BOM; convert to UTF-8 before parsing
- **XML error in JSON endpoint**: Check Content-Type before parsing; if XML, parse as XML error
- **Rate limit via 200 body**: Korean govt APIs often return `{ "resultCode": "99", "resultMsg": "LIMIT_EXCEEDED" }` inside a 200 OK. Adapters must inspect response body, not just HTTP status.
- **SSL/TLS**: Ensure Docker image includes updated Korean government CA certificates

---

## 9. Data Normalization Standards

### Problem

Different providers use different formats for the same data. Without normalization, downstream services (rights analysis, budget calculation) may produce incorrect results.

### Canonical Formats

All adapters must normalize data to these formats before returning:

| Data type | Canonical format | Example |
|-----------|-----------------|---------|
| Monetary amounts | Integer (KRW, 원) | `500000000` (not "5억" or "500,000,000") |
| Dates | `Date` object or ISO 8601 string | `"2026-03-15"` |
| Addresses | Separate fields: `road_address`, `jibun_address` | Both formats preserved |
| Case numbers | Stripped, no spaces, zero-padded | `"2026타경01234"` |
| Area (면적) | Float, square meters (㎡) | `84.95` (not "84.95㎡" or "25.7평") |
| Percentages | Float, 0-100 | `70.0` (not 0.7 or "70%") |

### Case Number Normalization

```ruby
module DataProvider
  def self.normalize_case_number(input)
    input.to_s
      .gsub(/\s+/, "")           # remove spaces
      .gsub(/(\d{4}\D+)(\d+)/) { "#{$1}#{$2.rjust(5, '0')}" }  # zero-pad
  end
end
```

### Address Matching

Properties from court auction use 지번 addresses; building ledger uses 도로명. The `properties` table stores both:

```ruby
# Properties should store both address formats
add_column :properties, :road_address, :string    # 도로명주소
add_column :properties, :jibun_address, :string   # 지번주소
```

Cross-provider matching uses case_number (unique identifier from court), not address.

---

## 10. Deployment & Infrastructure

### Playwright in Docker

Court auction scraping requires Playwright/Chromium. This affects the Docker image:

```dockerfile
# Dockerfile addition for Playwright support
RUN apt-get update && apt-get install -y \
    chromium \
    fonts-nanum \          # Korean font support
    --no-install-recommends && \
    rm -rf /var/lib/apt/lists/*

ENV PLAYWRIGHT_BROWSERS_PATH=/usr/bin
ENV CHROMIUM_PATH=/usr/bin/chromium
```

**Memory budget**: Each Chromium instance uses ~200-500MB. With `scraping` queue limited to 1 thread, peak additional memory is ~500MB. Minimum server RAM recommendation: 2GB (app) + 500MB (Chromium) = 2.5GB.

**Kamal configuration**: Both `web` and `job` roles need the same Playwright-capable image if scraping runs in background jobs. Alternative: run scraping inline in web process (simpler, but blocks request).

### Encryption Key Rotation

If `RAILS_MASTER_KEY` is compromised or needs rotation:

1. Add current key to `config.active_record.encryption.previous` in credentials
2. Set new primary key
3. Run re-encryption rake task:

```ruby
# lib/tasks/credentials.rake
desc "Re-encrypt all API credentials with current master key"
task reencrypt_credentials: :environment do
  ApiCredential.find_each do |cred|
    # Reading decrypts with old/current key; saving re-encrypts with new key
    cred.api_key = cred.api_key
    cred.api_secret = cred.api_secret
    cred.save!
  end
end
```

### SQLite Configuration

Ensure WAL mode and appropriate busy timeout for concurrent credential writes:

```yaml
# config/database.yml
production:
  adapter: sqlite3
  database: storage/production.sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  pragmas:
    journal_mode: wal
    busy_timeout: 5000  # 5 second wait on write contention
```

---

## 11. Log Safety & PII Protection

### Problem

External API calls may log API keys (in headers/params) and PII (property owner names from registry transcripts). Korean PIPA requires protection of personal information.

### Configuration

```ruby
# config/application.rb
config.filter_parameters += [
  :api_key, :api_secret, :password,
  :owner_name, :holder_name, :tenant_name,  # registry PII
  :resident_number, :phone                   # Korean PII
]
```

### HTTP Client Log Filtering

```ruby
# Faraday logger must filter sensitive headers
f.response :logger, Rails.logger, headers: false, bodies: false
```

- **Never log**: Full API response bodies (may contain owner names, resident numbers)
- **Always log**: Request URL (with key params redacted), HTTP status, duration
- **Log on error only**: Truncated response body (first 200 chars) for debugging

### Runtime API Failure → Credential Status Update

When an adapter call fails with `InvalidCredentialError` at runtime (not just during verification), the credential's status should be updated:

```ruby
# In adapter error wrapping:
rescue Faraday::ClientError => e
  if e.response_status == 401
    update_credential_status(credential_id, :invalid) if credential_id
    raise DataProvider::InvalidCredentialError, "API key rejected"
  end
end
```

This ensures the Settings UI reflects actual credential health, not just last manual verification.

---

## 12. Provider Health Monitoring

### Problem

External providers may go down without users noticing until they hit an error.

### Solution

A periodic Solid Queue job checks provider availability:

```ruby
class ProviderHealthCheckJob < ApplicationJob
  queue_as :default

  # Run daily via Solid Queue recurring schedule
  def perform
    ApiCredential::PROVIDERS.each do |name, config|
      next if config[:requires_consent] && !any_user_consented?(name)
      next if config[:requires_key] && !any_user_configured?(name)

      check_provider(name, config)
    end
  end

  private

  def check_provider(name, config)
    # Each adapter implements a lightweight .health_check class method
    adapter_class = adapter_class_for(name)
    adapter_class.health_check
    Rails.logger.info("[HealthCheck] #{name}: OK")
  rescue DataProvider::Error => e
    Rails.logger.warn("[HealthCheck] #{name}: FAILED - #{e.message}")
    # Future: notify admin via email/Slack
  end
end
```

This is a best-effort monitor — it doesn't block users, only logs warnings for operators.
