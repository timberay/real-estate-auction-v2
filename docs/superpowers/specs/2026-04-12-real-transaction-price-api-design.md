# Real Transaction Price API Design

## Overview

Fetch real estate transaction prices from the Ministry of Land (국토교통부) APIs on data.go.kr for properties registered in the auction app. Supports apartments, multi-family housing, and officetels. Data is used by F02 Property Inspection (수익분석 tab) for auto-judgment of 4 market analysis items.

## Scope

### In scope

- Real transaction price fetching for 3 property types (apt, multi-house, officetel)
- Background fetching on property registration
- DB storage of transaction records
- Similar-property matching with auto-expansion
- F02 auto-judgment integration (4 items)
- API key management via existing ApiCredential infrastructure

### Out of scope

- F04 Integrated Market Price Dashboard (separate P1 design)
- Rent/lease transaction data (매매 only)
- Commercial/land transaction data
- Real-time price alerts
- Listing prices (KB/Naver)

## Data Source: data.go.kr APIs

### API Endpoints

| Property Type | Service ID | Endpoint | Operation |
|---|---|---|---|
| Apartment (detail) | 15126468 | `apis.data.go.kr/1613000/RTMSDataSvcAptTradeDev/getRTMSDataSvcAptTradeDev` | Apt trade with building unit info |
| Multi-family | 15126467 | `apis.data.go.kr/1613000/RTMSDataSvcRHTrade/getRTMSDataSvcRHTrade` | 연립다세대 trade |
| Officetel | 15126464 | `apis.data.go.kr/1613000/RTMSDataSvcOffiTrade/getRTMSDataSvcOffiTrade` | 오피스텔 trade |

### Common Parameters

| Parameter | Type | Required | Description |
|---|---|---|---|
| `serviceKey` | string | Y | data.go.kr API key (URL-encoded) |
| `LAWD_CD` | string | Y | District code (5 digits: 시도 2 + 시군구 3) |
| `DEAL_YMD` | string | Y | Contract year-month `YYYYMM` |
| `pageNo` | integer | N | Page number (default 1) |
| `numOfRows` | integer | N | Rows per page (max 100 recommended) |

### Response Format

XML only (no JSON support). Key fields across all 3 APIs:

| Field | Description |
|---|---|
| `sggCd` | District code |
| `umdNm` | Legal district name (법정동명) |
| `dealAmount` | Transaction amount (만원, with commas) |
| `dealYear` / `dealMonth` / `dealDay` | Contract date |
| `excluUseAr` | Exclusive area (m2) |
| `floor` | Floor number |
| `buildYear` | Build year |
| `dealingGbn` | Transaction type |
| `cdealType` | Cancellation flag (취소거래) |

Type-specific building name fields:
- Apartment: `aptNm`
- Multi-family: `mhouseNm`
- Officetel: `offiNm`

### Rate Limits

- Free tier: ~1,000 calls/day (dev account)
- Single API key works across all 3 services
- Production tier available with usage registration

### Known Limitations

1. Canceled transactions marked via `cdealType` — must filter out
2. XML-only responses — requires XML parsing
3. Pagination needed for large result sets (some district+month combos have thousands of records)
4. Data refresh delay possible on weekends (server maintenance)
5. Use Decoding key (not Encoding key) for production

## Data Model

### RealTransaction

```ruby
create_table :real_transactions do |t|
  t.references :property, null: false, foreign_key: true
  t.string :property_type, null: false  # apt, multi_house, officetel
  t.string :district_code, null: false  # 법정동코드 5자리
  t.string :district_name               # 법정동명
  t.string :building_name               # 아파트/연립/오피스텔명
  t.decimal :exclusive_area, precision: 8, scale: 2  # 전용면적 m2
  t.integer :floor
  t.integer :build_year
  t.integer :deal_amount, null: false    # 거래금액 (만원)
  t.date :deal_date, null: false         # 계약일
  t.string :deal_type                    # 거래유형
  t.boolean :canceled, default: false    # 취소거래 여부
  t.datetime :fetched_at, null: false    # 조회 시점
  t.timestamps
end

add_index :real_transactions, [:district_code, :property_type, :deal_date]
add_index :real_transactions, [:district_code, :building_name, :exclusive_area]
add_index :real_transactions, [:property_id]
```

### Property additions

```ruby
# Add to Property model
t.datetime :transactions_fetched_at  # Track data freshness
```

### LawdCode lookup

YAML seed file mapping district names to 5-digit codes:

```yaml
# db/seeds/lawd_codes.yml
- code: "11110"
  name: "서울특별시 종로구"
- code: "11680"
  name: "서울특별시 강남구"
# ... all ~250 시군구
```

Loaded into a `LawdCode` model (simple table with `code` and `name` columns). Seeded via `bin/rails db:seed`. Lookup via `LawdCode.find_by_name` with address prefix matching.

## Adapter Architecture

### Class Hierarchy

```
RealTransaction::BaseTradeAdapter
├── RealTransaction::AptTradeAdapter
├── RealTransaction::MultiHouseTradeAdapter
└── RealTransaction::OffiTradeAdapter
```

All adapters live in `app/adapters/real_transaction/`.

### Factory

```ruby
# app/adapters/real_transaction_adapter.rb
module RealTransactionAdapter
  def self.for(property_type)
    case property_type.to_s
    when "apt"          then RealTransaction::AptTradeAdapter.new
    when "multi_house"  then RealTransaction::MultiHouseTradeAdapter.new
    when "officetel"    then RealTransaction::OffiTradeAdapter.new
    else raise DataProvider::ConfigurationError, "Unknown property type: #{property_type}"
    end
  end
end
```

### BaseTradeAdapter

```ruby
# app/adapters/real_transaction/base_trade_adapter.rb
module RealTransaction
  class BaseTradeAdapter
    BASE_URL = "https://apis.data.go.kr/1613000"

    def fetch(district_code:, deal_months:, api_key:)
      # 1. For each month in deal_months, call API with pagination
      # 2. Parse XML responses
      # 3. Filter out canceled transactions (cdealType present)
      # 4. Map to normalized attribute hashes
      # Returns: Array of attribute hashes
    end

    private

    # Subclasses override these:
    def endpoint_path = raise NotImplementedError
    def building_name_field = raise NotImplementedError
    def parse_item(xml_item) = raise NotImplementedError

    # Shared methods:
    def fetch_page(district_code:, deal_ymd:, page:, api_key:)
      # Faraday GET with timeout/retry
      # Returns parsed XML document
    end

    def fetch_all_pages(district_code:, deal_ymd:, api_key:)
      # Auto-paginate until all records fetched
      # Uses totalCount from response header
    end

    def parse_common_fields(item)
      # Extract shared fields: deal_amount, deal_date, area, floor, etc.
    end

    def canceled?(item)
      # Check cdealType field
    end
  end
end
```

### HTTP Client Configuration

- Client: Faraday (standard REST API, no WAF issues)
- Connection timeout: 5 seconds
- Read timeout: 10 seconds
- Retry: max 2 attempts (5xx and timeout only)
- Error mapping to DataProvider error hierarchy:
  - HTTP 4xx → `DataProvider::InvalidCredentialError` (401) or `DataProvider::ConfigurationError`
  - HTTP 5xx → `DataProvider::ServiceUnavailableError`
  - Timeout → `DataProvider::TimeoutError`
  - Rate limit → `DataProvider::RateLimitError`
  - Parse failure → `DataProvider::ParseError`

## Service Layer

### RealTransactionFetchService

```ruby
# app/services/real_transaction_fetch_service.rb
class RealTransactionFetchService
  def self.call(property)
    new(property).call
  end

  def call
    # 1. Resolve district code from property address
    # 2. Determine property type (apt/multi_house/officetel)
    # 3. Resolve API key from ApiCredential
    # 4. Calculate deal_months (recent 3 months)
    # 5. Fetch via adapter
    # 6. Filter similar properties (same district + type)
    # 7. If < 3 results, expand area filter to ±20%
    # 8. Bulk upsert RealTransaction records
    # 9. Update property.transactions_fetched_at
  end
end
```

### District Code Resolution

Extract 시군구 from Property address → lookup in LawdCode:

```ruby
# Property address: "서울특별시 강남구 역삼동 ..."
# → Extract "서울특별시 강남구" → LawdCode lookup → "11680"
```

### Similar Property Matching

1. Primary filter: same `district_code` + same `property_type` (already filtered by API)
2. If results < 3, widen to ±20% of target `exclusive_area`
3. All filtering done in-memory on fetched data (no additional API calls)

## Background Job

### FetchRealTransactionsJob

```ruby
# app/jobs/fetch_real_transactions_job.rb
class FetchRealTransactionsJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(property_id) { "fetch_transactions_#{property_id}" }

  retry_on DataProvider::RateLimitError, wait: 5.minutes, attempts: 3
  retry_on DataProvider::TimeoutError, wait: 30.seconds, attempts: 3
  retry_on DataProvider::ServiceUnavailableError, wait: 1.minute, attempts: 3
  discard_on DataProvider::InvalidCredentialError
  discard_on DataProvider::ConfigurationError

  def perform(property_id)
    property = Property.find(property_id)
    RealTransactionFetchService.call(property)
  end
end
```

Trigger: `Property` after_create callback enqueues the job.

## F02 Auto-Judgment Integration

After `RealTransactionFetchService` completes, trigger auto-judgment for 4 items:

| Item ID | Name | Logic |
|---|---|---|
| `market-001` | 거래량 | Count transactions in last 3 months. >= 5: "활발", < 5: "저조" |
| `market-003` | 비교 대상 선정 | Count similar-area (±10%) transactions. >= 3: "충분", < 3: "부족" |
| `market-004` | 최근 거래 사례 | Most recent transaction: amount, area, floor, date |
| `resale-004` | 감정평가액 vs 실거래가 | Gap rate: (appraisal - avg_transaction) / avg_transaction × 100 |

Implementation: `InspectionAutoJudgeService` reads `RealTransaction` records for the property and updates the corresponding `InspectionResult` items. UI updated via Turbo Stream.

## API Key Management

Add to `ApiCredential::PROVIDERS`:

```ruby
real_transaction: { category: :market_data, requires_key: true }
```

- Single data.go.kr key serves all 3 APIs
- Registered/verified via existing Settings UI
- `CredentialVerificationJob` performs a test API call to verify key validity

## Testing Strategy

- **Unit tests**: BaseTradeAdapter XML parsing, each subclass field mapping, canceled transaction filtering, district code resolution, similar property matching logic
- **Integration tests**: Full fetch flow with stubbed HTTP (Faraday test adapter), RealTransaction record creation, auto-judgment updates
- **Error handling tests**: Each DataProvider error type triggers correct retry/discard behavior
