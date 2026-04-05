# F02. Safe Property Auto-Filtering & Risk Warnings — Design Spec

## Context

F02 is the second MVP feature (P0, deploy order 2nd) that builds on F01's budget setup. Beginner auction investors frequently bid on properties with hidden legal, resale, or loan risks — resulting in financial loss. F02 addresses this by implementing a checklist-driven safety analysis flow that identifies risky properties and rates them before users can bid.

The core value: **prevent financial loss by detecting dangerous properties before beginners commit.**

## Scope & Boundaries

### In Scope (F02)
- Property list with basic info and analysis status
- API data acquisition from 매각물건명세서 (Court Auction) and 건축물대장 (Building Ledger)
- 17 checklist items across 3 risk axes (legal, resale, loan)
- Interactive analysis flow: auto-check → manual input → resolution input → safety rating
- 3-tier safety rating: Safe / Caution / Danger
- "Show safe only" one-click filter preset

### Out of Scope (deferred to F03+)
- 등기부등본 (Registry) data — deferred to F03
- 시세 (Market price) comparison — deferred to F06
- 선순위 세금 압류 (Senior tax seizure) — requires 등기부등본, deferred to F03
- 대항력 임차인 + 국세청 압류 combination check — 국세청 압류 requires 등기부등본

### SRS Deviation
- Safety rating is NOT based on risk item count. Instead, it's based on whether the user can resolve identified risks:
  - **Danger**: Any unresolvable risk exists
  - **Caution**: Risks exist but all are resolvable
  - **Safe**: No risks detected

## Checklist Items (17)

Source: `db/seeds/checklist_items_summary.json` (moved from `docs/`)

Every item in the JSON has a unique `id` field (e.g., `"rights-011"`). F02 items are identified by the presence of `f02_risk_axis` (legal/resale/loan). 12 items are pre-existing (tagged for F02), 5 are newly added for F02. Items without `f02_risk_axis` are skipped during F02 seeding.

### Legal Risk (법적 위험) — 9 items

| # | f02_code | Question | Detection | Data Source |
|---|---|---|---|---|
| 1 | rights-011 | 매각물건명세서 비고란에 유치권 또는 법정지상권이 적혀 있습니까? | Auto | 매각물건명세서 |
| 2 | rights-002 | 매각물건명세서의 '소멸되지 아니하는 것' 비고란에 기재된 인수 권리(가등기, 가처분, 전세권 등)가 있습니까? | Auto | 매각물건명세서 |
| 3 | rights-019 | (아파트가 아닌 경우) 토지 별도 등기가 있거나 토지와 건물이 따로 매각되는 물건입니까? | Auto | 매각물건명세서 |
| 4 | rights-020 | 현황 조사서에 '유치권 신고 있음'이 표시되어 있습니까? | Auto | 매각물건명세서 |
| 5 | rights-003 | 전입신고가 되어 있는 임차인이 존재합니까? | Auto | 매각물건명세서 |
| 6 | rights-006 | 대항력 있는 임차인이 배당요구 종기일 이전에 배당요구 신청을 하였습니까? | Auto | 매각물건명세서 |
| 7 | rights-014 | 대항력 있는 임차인이 존재하며, 보증금 미상/확정일자 없음/배당 미신청 중 하나라도 해당됩니까? | Auto | 매각물건명세서 |
| 8 | manual-001 | 분묘기지권(묘지 사용 권리)이 존재합니까? | Manual | 수동 입력 |
| 9 | property-001 | 해당 물건이 지분 입찰 물건입니까? | Auto | 대법원 경매정보 |

### Resale Risk (매도 위험) — 5 items

| # | f02_code | Question | Detection | Data Source |
|---|---|---|---|---|
| 10 | property-005 | 건축물대장 상 용도가 '사무소'로 적혀 있습니까? | Auto | 건축물대장 |
| 11 | resale-001 | 빌라의 방 구조가 원룸 또는 1.5룸입니까? | Auto | 건축물대장 |
| 12 | resale-002 | 빌라의 세대수 대비 주차 공간이 부족합니까? | Auto | 건축물대장 |
| 13 | resale-003 | 해당 물건이 반지하 빌라입니까? | Auto | 경매정보지 |
| 14 | resale-004 | 해당 빌라가 준공 2년 이내 신축이면서 감정가가 주변 시세보다 현저히 높습니까? | Manual* | 건축물대장 |

> \* `resale-004`: 시세 비교 데이터가 F06에서 제공될 때까지 manual input으로 처리

### Loan Risk (대출 위험) — 3 items

| # | f02_code | Question | Detection | Data Source |
|---|---|---|---|---|
| 15 | property-004 | 건축물대장에 노란색으로 '위반건축물'이라고 표시되어 있습니까? | Auto | 건축물대장 |
| 16 | rights-005 | 매각물건명세서에 건축법상 사용 승인을 받지 않은 건물 또는 집합건물 대장 미등재라고 기재되어 있습니까? | Auto | 매각물건명세서 |
| 17 | property-002 | 매각물건명세서에 인접 호실과 벽체 구분 없이 하나로 사용 중이라는 기재가 있습니까? | Auto | 매각물건명세서 |

## Data Model

### Property
Core property data, keyed by `case_number` (사건번호) with upsert semantics.

```
Property
├── case_number (string, unique) — 사건번호, primary lookup key
├── court_name (string) — 법원명
├── property_type (string) — 물건 종류
├── address (string) — 소재지
├── appraisal_price (integer) — 감정가
├── min_bid_price (integer) — 최저매각가
├── status (string) — 진행상태
├── safety_rating (enum: nil/safe/caution/danger)
├── raw_data (json) — API 원본 데이터 보존
│   ├── court_auction: {...}
│   └── building_ledger: {...}
├── timestamps
└── belongs_to :user (optional, for per-user analysis)
```

### ChecklistItem
Master table seeded from `db/seeds/checklist_items_summary.json`. Each F02 item is identified by `f02_risk_axis` field in the JSON — items without it are skipped during seeding. The `id` field in JSON becomes the `code` in the database.

```
ChecklistItem
├── code (string, unique) — from JSON id, e.g., "rights-011"
├── category (string) — 권리분석, 물건 기본 필터링
├── risk_axis (enum: legal/resale/loan) — from JSON f02_risk_axis
├── question (text)
├── description (text)
├── logic (json) — answer-to-meaning mapping
├── data_source_name (string) — 매각물건명세서, 건축물대장, etc.
├── priority (string) — 상/중/하
└── position (integer) — display order (set by seed, not in JSON)
```

### PropertyCheckResult
Per-property, per-checklist-item result. Junction table.

```
PropertyCheckResult
├── belongs_to :property
├── belongs_to :checklist_item
├── source_type (enum: auto/manual) — how the value was obtained
├── api_value (text) — raw value from API
├── manual_value (text) — user-entered value
├── has_risk (boolean) — does this item present a risk?
├── resolvable (boolean, nullable) — nil until user inputs; true/false
├── resolution_note (text) — user's explanation of resolution plan
└── timestamps
```

### Safety Rating Calculation

```
if any PropertyCheckResult has (has_risk: true AND resolvable: false)
  → Danger
elsif any PropertyCheckResult has (has_risk: true AND resolvable: true)
  → Caution
else
  → Safe
end
```

## API Integration & Adapter Pattern

Follows the established adapter pattern from F01 (`BaseAdapter.for(provider)`).

### Adapters

```
PropertyDataSyncService.call(case_number)
├── CourtAuctionAdapter (매각물건명세서)
│   ├── MockAdapter — seed JSON fixtures
│   └── RealAdapter — courtauction.go.kr API
├── BuildingLedgerAdapter (건축물대장)
│   ├── MockAdapter — seed JSON fixtures
│   └── RealAdapter — gov.kr API
└── Result → Property.raw_data (upsert by case_number)
```

- `USE_MOCK` env var toggles Mock/Real per adapter
- MVP develops with MockAdapter; RealAdapter swapped in when API access is secured
- Mock data in `db/seeds/` with diverse risk combinations for testing

## Analysis Flow

### Sequence

```
User selects property from list
       │
       ▼
Step 1: PropertyAnalysisService.call(property, user)
       │  AutoCheckRunner iterates 17 ChecklistItems
       │  Extracts values from Property.raw_data
       │  Creates PropertyCheckResult (source_type: "auto", has_risk: T/F)
       │  Items where raw_data has no matching value → source_type: nil
       │
       ▼
Step 2: Manual Input (if any source_type: nil exists)
       │  Show only failed/missing items
       │  User must answer ALL before proceeding
       │  Updates PropertyCheckResult (source_type: "manual", has_risk: T/F)
       │
       ▼
Step 3: Full Results + Resolution Input
       │  Show all 17 items grouped by risk axis
       │  Items with has_risk: true → show resolvable toggle + note field
       │  User inputs resolvable: true/false for each risk item
       │
       ▼
Step 4: Safety Rating
       │  SafetyRatingService.call(property)
       │  Updates Property.safety_rating
       │  Displays rating + justification
```

### AutoCheckRunner Logic
Each ChecklistItem maps to a detection rule that extracts and evaluates data from `Property.raw_data`:

- Example: `rights-011` → `raw_data.dig("court_auction", "remarks")` → scan for "유치권", "법정지상권" keywords
- Detection rules are per-item, individually testable
- Returns `{has_risk: true/false}` or `nil` if data unavailable
- 2 items have no auto-detection rule and always require manual input:
  - `manual-001` (분묘기지권) — no API data source exists
  - `resale-004` (신축빌라 감정가 과대) — requires F06 market price data, deferred to manual input for MVP

## Routes & Controllers

```ruby
# Property list & detail
resources :properties, only: [:index, :show] do
  # Analysis flow (nested, Turbo Frame)
  namespace :analyses do
    resource :start, only: [:create], controller: "start"
    resource :manual_input, only: [:edit, :update], controller: "manual_inputs"
    resource :result, only: [:edit, :update], controller: "results"
    resource :rating, only: [:show], controller: "ratings"
  end
end

# root path change
root "properties#index"
```

### Controller Responsibilities
- `PropertiesController` — index (list with filters), show (detail + analysis entry)
- `Analyses::StartController#create` — triggers PropertyAnalysisService, redirects to next step
- `Analyses::ManualInputsController` — edit/update manual input form
- `Analyses::ResultsController` — edit/update resolution input form
- `Analyses::RatingsController#show` — displays final rating

All analysis steps use Turbo Frame (`turbo_frame_tag "analysis_flow"`) for in-page transitions.

## UI Components

### New ViewComponents

| Component | Purpose |
|---|---|
| `PropertyCardComponent` | Property list card (case number, address, prices, safety badge) |
| `SafetyBadgeComponent` | Safe/Caution/Danger/Unanalyzed badge (reusable) |
| `ChecklistItemComponent` | Single checklist item display (question, result, risk status, resolution input) |
| `ChecklistGroupComponent` | Risk axis group (legal/resale/loan) wrapping ChecklistItemComponents |
| `RatingResultComponent` | Large rating card with justification summary |

### New Stimulus Controllers

| Controller | Purpose |
|---|---|
| `manual-input` | Enables submit button only when all items are answered |
| `resolution-input` | Toggles note field visibility on resolvable selection |
| `property-filter` | "Safe only" preset, budget range filter on property list |

### Reused Existing Components
- `BadgeComponent` → base for SafetyBadgeComponent
- `CardComponent` → wrapper for PropertyCardComponent
- `ButtonComponent` → action buttons throughout flow

## Screens

### 1. Property List (`properties#index`, root path)
- Budget-filtered property cards with basic info
- Safety badge per property (unanalyzed = gray)
- "Safe만 보기" one-click filter preset
- Turbo Frame pagination

### 2. Manual Input (`analyses/manual_inputs#edit`)
- Only shown when API data acquisition failed for some items
- Card-style question list with Yes/No radio buttons
- All items must be answered to proceed
- Skipped entirely if all items have API data

### 3. Results + Resolution (`analyses/results#edit`)
- All 17 items displayed in one screen, grouped by risk axis
- Color coding: no risk (green), risk (red)
- Risk items show resolvable toggle (yes/no) + optional note field
- Color updates on input: resolvable (yellow), unresolvable (red)

### 4. Rating Result (`analyses/ratings#show`)
- Large Safe (green) / Caution (yellow) / Danger (red) badge
- Justification summary listing risk items and resolution status
- Accordion for detailed per-item breakdown
- "다시 분석하기" button to restart from Step 1
- "목록으로 돌아가기" button returns to list (badge updated)

## Dependencies

- **Upstream:** F01 (BudgetSetting provides max_bid_amount and property_type for filtering)
- **Downstream:** F03 (adds 등기부등본 check items to same ChecklistItem/PropertyCheckResult structure), F06 (market price data)

## File Changes Summary

### New Files
- `app/models/property.rb`
- `app/models/checklist_item.rb`
- `app/models/property_check_result.rb`
- `app/controllers/properties_controller.rb`
- `app/controllers/analyses/start_controller.rb`
- `app/controllers/analyses/manual_inputs_controller.rb`
- `app/controllers/analyses/results_controller.rb`
- `app/controllers/analyses/ratings_controller.rb`
- `app/services/property_data_sync_service.rb`
- `app/services/property_analysis_service.rb`
- `app/services/auto_check_runner.rb`
- `app/services/safety_rating_service.rb`
- `app/adapters/court_auction_adapter.rb` (Mock + Real)
- `app/adapters/building_ledger_adapter.rb` (Mock + Real)
- ViewComponents: PropertyCard, SafetyBadge, ChecklistItem, ChecklistGroup, RatingResult
- Stimulus: manual-input, resolution-input, property-filter
- Views: properties/index, properties/show, analyses/*
- Migrations: create_properties, create_checklist_items, create_property_check_results

### Modified Files
- `config/routes.rb` — add property and analysis routes, change root
- `db/seeds.rb` — add ChecklistItem seeding
- `app/views/layouts/application.html.erb` — sidebar navigation update

### Moved Files
- `docs/checklist_items_summary.json` → `db/seeds/checklist_items_summary.json` (all 91 items now have unique `id` field; 17 F02 items tagged with `f02_risk_axis`; 5 new items appended)
