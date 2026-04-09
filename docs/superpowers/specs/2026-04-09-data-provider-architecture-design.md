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

A single class that encapsulates the three-tier resolution logic:

```ruby
class CredentialResolver
  def initialize(user:, provider_name:)
    @user = user
    @provider_name = provider_name
  end

  def resolve
    # Tier 1: ENV override (development/test)
    return { adapter: :mock } if mock_mode?

    # Tier 2: User credential check
    credential = @user&.api_credentials&.active&.for_provider(@provider_name)
    if credential&.configured?
      { adapter: :real, api_key: credential.api_key, api_secret: credential.api_secret }
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

  def mock_mode?
    ENV["USE_MOCK"] != "false"
  end

  def error_for_provider
    config = ApiCredential::PROVIDERS[@provider_name.to_sym]
    if config&.dig(:requires_consent)
      DataProvider::ConsentRequiredError.new("법원경매 데이터 수집에 동의해주세요.")
    else
      DataProvider::MissingCredentialError.new("#{config&.dig(:name_ko)} API 키를 설정해주세요.")
    end
  end
end
```

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

Services resolve credentials and pass config to adapters:

```ruby
class PropertyDataSyncService
  def initialize(case_number:, user: nil)
    @case_number = case_number
    @user = user
  end

  def call
    court_config = resolve(:court_auction)
    building_config = resolve(:data_go_kr)
    registry_config = resolve(:tilko)

    court_data = CourtAuctionAdapter.for(court_config).fetch_data(case_number: @case_number)
    building_data = BuildingLedgerAdapter.for(building_config).fetch_data(case_number: @case_number)
    registry_data = RegistryTranscriptAdapter.for(registry_config).fetch_data(case_number: @case_number)
    # ... rest unchanged
  end

  private

  def resolve(provider_name)
    CredentialResolver.new(user: @user, provider_name: provider_name).resolve
  end
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

  def perform(credential)
    adapter_class = adapter_for(credential.provider_name)
    adapter_class.verify_credential(credential)
    credential.update!(last_verified_at: Time.current)
    broadcast_status(credential, :verified)
  rescue DataProvider::InvalidCredentialError => e
    broadcast_status(credential, :invalid, message: e.message)
  rescue DataProvider::ConnectionError => e
    broadcast_status(credential, :connection_error, message: e.message)
  end

  private

  def broadcast_status(credential, status, message: nil)
    Turbo::StreamsChannel.broadcast_replace_to(
      "credential_status_#{credential.id}",
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
