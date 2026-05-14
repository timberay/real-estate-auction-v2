# Court Auction Data Collection Pipeline Completion

**Date:** 2026-04-09
**Status:** Approved

## Goal

Complete the end-to-end data collection pipeline: user enters a case number (사건번호) in the UI → app fetches real data from courtauction.go.kr via Ferrum browser automation → stores structured data in the DB.

## Scope

- **In scope:** Court auction data only (courtauction.go.kr)
- **Out of scope:** Building ledger (data.go.kr), registry transcript — to be added later as separate features

## Data Flow

```
User enters case number ("2026타경10001")
  → PropertiesController#create
    → PropertyDataSyncService.call(case_number:, user:)
      → GovernmentCourtAuctionAdapter#fetch_data_with_detail(case_number:)
        → CaseNumberParser.parse → {year: "2026", type: "타경", number: "10001"}
        → RateLimiter.throttle
        → BrowserClient#fetch_with_detail(year:, type:, number:)
          → Ferrum: detail search page → search → capture API response (search)
          → Click first result → capture API response (detail)
        → ResponseParser#parse_with_detail(search_response:, detail_response:)
      → persist_property → Property + sale_detail + auction_schedules + land_details + appraisal_points
    → user_properties association
  → Redirect to list (success/failure message)
```

## Key Decisions

### 1. Remove mock infrastructure

Mock mode (`USE_MOCK` env var, `MockCourtAuctionAdapter`, `CredentialResolver`) is no longer needed. The real adapter is the only path.

**Remove:**
| File/Code | Reason |
|-----------|--------|
| `MockCourtAuctionAdapter` | Mock mode removed |
| `CredentialResolver` | Court auction needs no credentials; other providers removed from scope |
| `CourtAuctionAdapter.for` factory | Always use real adapter directly |
| `PropertyDataSyncService` building/registry calls | Unimplemented providers removed |
| `USE_MOCK` env var references | No longer used |
| `mock_properties.json` seed data | Unnecessary |

### 2. Always fetch search + detail

`PropertyDataSyncService` calls `fetch_data_with_detail` by default (not `fetch_data`). This collects all available data in one pass: property basics, rights analysis, auction schedules, land details, and appraisal points.

### 3. Synchronous processing

The browser fetch (potentially several seconds) runs synchronously in the request cycle. The user sees a loading state until completion. Rationale: case number entry is infrequent, and the 30-second timeout provides a hard upper bound. Async (Solid Queue) can be added later if needed.

### 4. Simplify PropertyDataSyncService

Remove `CredentialResolver`, `with_detail` flag, and multi-provider orchestration. The service directly instantiates `GovernmentCourtAuctionAdapter` and calls `fetch_data_with_detail`.

## Changes Required

### Removals

- `app/adapters/mock_court_auction_adapter.rb` — delete file
- `app/services/credential_resolver.rb` — delete file
- `CourtAuctionAdapter.for` factory method — remove or simplify
- `PropertyDataSyncService` — remove building/registry fetch, remove CredentialResolver usage, remove `with_detail` parameter
- `db/seeds/mock_properties.json` — delete file
- `.env` / `.env.example` — remove `USE_MOCK` variable

### Modifications

**`PropertyDataSyncService`:**
- Directly instantiate `GovernmentCourtAuctionAdapter`
- Always call `fetch_data_with_detail`
- Simplify Result to `Data.define(:court_data, :errors, :property)`
- Remove `fetch_source` / `fetch_source_by_category` helpers

**`PropertiesController#create`:**
- Add error-specific user messages (see Error Handling below)
- Turbo-compatible loading state during fetch

**`CourtAuctionAdapter`:**
- Remove `.for` factory method
- Keep as base class with `fetch_data` and `fetch_data_with_detail` interface definitions
- `GovernmentCourtAuctionAdapter` remains the sole concrete implementation

## Error Handling

| Error | User Message |
|-------|-------------|
| Invalid case number format | "사건번호 형식이 올바르지 않습니다. (예: 2026타경1234)" |
| No search results | "해당 사건번호의 물건을 찾을 수 없습니다." |
| Site unreachable | "법원경매 사이트에 접속할 수 없습니다. 잠시 후 다시 시도해주세요." |
| Browser timeout | "데이터 수집 시간이 초과되었습니다. 다시 시도해주세요." |
| Chromium not installed | "브라우저 실행에 실패했습니다. 시스템 설정을 확인해주세요." |

All errors redirect back to `properties_path` with an `alert` flash message.

## Test Strategy

- **Unit tests:** ResponseParser, CaseNumberParser — existing tests, update as needed
- **Integration tests:** PropertyDataSyncService with stubbed BrowserClient — verify full persist flow
- **Controller tests:** Success, failure, duplicate, and error scenarios
- **Live site testing:** Manual only — not in CI. BrowserClient is stubbed in all automated tests.

## Dependencies

- `ferrum` gem (already in Gemfile)
- Chromium/Chrome binary on the host system
- `BROWSER_PATH` env var (optional, for custom Chromium location)
