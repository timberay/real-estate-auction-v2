# F03. Automated Rights Analysis Report — Design Spec

## 1. Overview

### Purpose

Automatically analyze extinguishment base rights, tenant opposing power, and assumed amounts from registry transcripts and sale property descriptions, and deliver a structured report. The AI report must always be shown alongside the original document to prevent overconfidence. HUG opportunity property detection is a key differentiator.

### SRS Reference

- Feature: F03 (P0, MVP — 3rd deploy)
- Pain Point: P1 (Rights analysis is difficult and frightening)
- Upstream: F02 (property data feed, checklist results)
- Downstream: F04 (assumed amount feeds profit calculation), F10 (dividend simulation feeds eviction difficulty)

### Scope

This spec covers all four SRS sub-requirements in a single design:

| Sub-Requirement | Description |
|---|---|
| **(A) Core Analysis** | Extinguishment base right extraction, opposing power determination, assumed amount calculation, dividend simulation |
| **(B) Overconfidence Prevention** | Source document viewer, disclaimer text, confirmation popup |
| **(C) Opportunity Detection** | HUG waiver auto-detection, full-dividend opportunity detection with accuracy disclaimer |
| **(D) Report Output** | 1-page summary card + detailed analysis page (timeline, dividend table, source docs) |

---

## 2. Key Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Registry data source | Mock first (MockRegistryAdapter) | Same pattern as F02's MockCourtAuctionAdapter. Real API (인터넷등기소) integration later |
| Design scope | All A–D in one spec | Implementation plan will break into phases |
| Dividend simulation depth | Standard — major creditor priority table + expected bid calculation | Full court-level calculation (안분배당, 흡수설) is out of scope for MVP |
| Source document viewer | UI structure first, raw_data formatted display | Replace with PDF viewer when real API is connected |
| Report placement | Separate tab with numbered guide (①②③④) | Independent access + sequential guidance for beginners |
| HUG + opportunity detection | Dividend simulation integration + accuracy disclaimer | Even imperfect simulation provides valuable guidance with proper disclaimers |
| Checklist relationship | Complementary — F03 engine references checklist results for comprehensive analysis | Checklist = "risk yes/no check", F03 engine = "structural analysis + calculation" |

---

## 3. Data Model

### New Table: `rights_analysis_reports`

Per-user, per-property rights analysis results.

| Column | Type | Notes |
|---|---|---|
| `user_id` | references | FK to users, not null |
| `property_id` | references | FK to properties, not null |
| `base_right_type` | string | Extinguishment base right type (근저당/가압류/압류/강제경매개시결정). nil if no rights exist |
| `base_right_date` | date | Base right establishment date |
| `base_right_holder` | string | Rights holder name |
| `assumed_amount` | integer | Assumed amount in KRW (낙찰자 인수 금액) |
| `total_risk_amount` | integer | Total risk amount (assumed + unconfirmed) |
| `verdict` | integer (enum) | safe(0) / caution(1) / danger(2). Independent from UserProperty.safety_rating — this is the rights-only verdict |
| `verdict_summary` | text | 3-line key basis summary |
| `opportunity_type` | string | nil / "hug_waiver" / "full_dividend" |
| `opportunity_reason` | text | Plain-language explanation of why it's an opportunity |
| `source_doc_reviewed` | boolean | Whether user viewed source document before proceeding, default: false |
| `analyzed_at` | datetime | When analysis was executed |
| `report_data` | json | Full structured analysis result (timeline, dividend table, etc.) |

**Constraints:** Unique index on `(user_id, property_id)`.

### `report_data` JSON Structure

```json
{
  "registry_timeline": [
    {
      "date": "2024-01-15",
      "type": "근저당",
      "holder": "국민은행",
      "amount": 180000000,
      "rank": 1,
      "is_base_right": true
    }
  ],
  "tenants": [
    {
      "name": "임차인A",
      "deposit": 50000000,
      "move_in_date": "2024-03-01",
      "confirmed_date": "2024-03-05",
      "has_opposing_power": true,
      "dividend_requested": true,
      "is_small_sum_tenant": false,
      "estimated_dividend": 50000000
    }
  ],
  "dividend_simulation": {
    "expected_bid": null,
    "distribution": []
  },
  "bidder_burden": {
    "assumed_amount": 0,
    "unconfirmed_risk": 0,
    "total_burden": 0,
    "verdict": "safe"
  },
  "checklist_references": ["rights-003", "rights-006", "rights-009"]
}
```

### `raw_data` Extension: `registry_transcript` Key

MockRegistryAdapter generates this structure within `Property.raw_data`:

```json
{
  "registry_transcript": {
    "rights": [
      {
        "type": "근저당",
        "date": "2024-01-15",
        "holder": "국민은행",
        "amount": 180000000,
        "status": "active",
        "registry_section": "을구"
      }
    ],
    "tenants": [
      {
        "name": "임차인A",
        "deposit": 50000000,
        "move_in_date": "2024-03-01",
        "confirmed_date": "2024-03-05",
        "dividend_requested": true,
        "is_small_sum_tenant": false
      }
    ],
    "hug_waiver": false,
    "seizures": [
      {
        "type": "압류",
        "date": "2024-06-01",
        "holder": "관할세무서",
        "amount": 5000000
      }
    ]
  }
}
```

### Model Relationships

```
User has_many :rights_analysis_reports
Property has_many :rights_analysis_reports
RightsAnalysisReport belongs_to :user, :property
```

---

## 4. Service Architecture

### Orchestrator: `RightsAnalysisService`

```ruby
RightsAnalysisService.call(property:, user:)
```

Follows the same pattern as `PropertyAnalysisService` → `AutoCheckRunner`.

### Sub-Modules (5)

| # | Module | Input | Output | Responsibility |
|---|---|---|---|---|
| 1 | `ExtinguishmentBaseRightExtractor` | `registry_transcript.rights` | `base_right_type`, `base_right_date`, `base_right_holder` | Extract the earliest mortgage/provisional seizure/seizure as the extinguishment base right |
| 2 | `OpposingPowerDeterminer` | `registry_transcript.tenants` + base right date | Per-tenant `has_opposing_power` (bool) | Compare each tenant's move-in date (next day 00:00) against base right date to determine opposing power |
| 3 | `AssumedAmountCalculator` | Opposing power results + confirmed date / dividend request status | `assumed_amount`, `total_risk_amount` | Sum of deposits with opposing power that won't receive dividend = amount bidder must assume |
| 4 | `DividendSimulator` | All rights + tenants + expected bid | `distribution` array (per-creditor dividend amounts) + `bidder_burden` summary | Generate priority-ordered dividend table from expected bid input |
| 5 | `OpportunityDetector` | HUG waiver status + dividend results + checklist results | `opportunity_type`, `opportunity_reason` | Detect HUG waiver properties + full-dividend opportunity properties |

### Execution Flow

```
RightsAnalysisService.call(property, user)
  │
  ├─ 1. registry_data = property.raw_data["registry_transcript"]
  ├─ 2. check_results = PropertyCheckResult.where(property:, user:)
  │
  ├─ 3. base_right = ExtinguishmentBaseRightExtractor.call(registry_data)
  ├─ 4. tenants = OpposingPowerDeterminer.call(registry_data, base_right)
  ├─ 5. assumed = AssumedAmountCalculator.call(tenants)
  ├─ 6. opportunity = OpportunityDetector.call(registry_data, tenants, check_results)
  │
  └─ 7. RightsAnalysisReport.upsert (persist results)
```

**DividendSimulator is invoked separately:** Runs in real-time when the user inputs an expected bid amount. At initial report creation, `dividend_simulation.expected_bid` is stored as `null`. Updated via `report#update` when user provides input.

### Dividend Simulation — Priority Order

Standard priority for MVP:

| Priority | Type | Description |
|---|---|---|
| 0 | 경매 비용 | Auction costs (always first) |
| 1 | 소액임차인 최우선변제 | Small-sum tenant priority repayment |
| 2 | 당해세 | Current-year tax |
| 3 | 근저당/전세권 (설정일순) | Mortgage/lease rights by establishment date |
| 4 | 확정일자 임차인 (일자순) | Tenants with confirmed date, by date order |
| 5 | 일반 채권 | General creditors |

### Checklist Reference

The following checklist items are referenced by F03 sub-modules for cross-validation:

- `rights-003` (임차인 존재 여부) → Tenant analysis cross-check
- `rights-006` (배당요구 신청 여부) → Dividend calculation reinforcement
- `rights-009` (HUG 확약서 제출 여부) → Opportunity detection reinforcement
- `rights-011` (유치권/법정지상권) → Verdict determination

Referenced checklist item codes are stored in `report_data.checklist_references`, enabling links like "Verified in ② Checklist tab" on the report page.

### MockRegistryAdapter

Follows F02's `MockCourtAuctionAdapter` pattern:

```ruby
class MockRegistryAdapter < BaseRegistryAdapter
  def fetch_data(case_number)
    return MOCK_DATA[case_number] if MOCK_DATA.key?(case_number)
    generate_random_registry(case_number)  # deterministic random
  end
end
```

- Predefined registry data for existing mock properties (safe_apartment, risky_villa, etc.)
- New case numbers generate deterministic random data (same case_number = same data)
- HUG waiver properties generated at ~10% probability for opportunity detection testing

---

## 5. UI Design

### 5-1. Tab Navigation — Property Detail Page

Restructure `properties/show` with numbered tab navigation:

```
┌──────────────┬──────────────┬──────────────┬──────────────┐
│ ① 기본 정보   │ ② 체크리스트  │ ③ 권리 분석   │ ④ 등급 산정   │
└──────────────┴──────────────┴──────────────┴──────────────┘
```

| Tab | Content | State Management |
|---|---|---|
| ① 기본 정보 | Existing `properties/show` content | Always accessible |
| ② 체크리스트 | Existing `analyses/results/edit` content (renamed) | Pre-analysis: "분석을 시작하세요" prompt |
| ③ 권리 분석 | **New** — F03 report | Pre-analysis: "분석을 시작하세요" prompt |
| ④ 등급 산정 | Existing `analyses/ratings/show` content | Checklist incomplete: "체크리스트를 먼저 완료하세요" prompt |

- Turbo Frame-based tab switching (no full page reload)
- URL changes for direct linking: `/properties/:id/tab/report`
- Completed tabs show checkmark (✓), incomplete show number only

### 5-2. "분석 시작" Action Change

Currently `analyses/start` runs only AutoCheckRunner. With F03:

```
[분석 시작] button click
  ├─ PropertyAnalysisService.call (existing — checklist auto-check)
  └─ RightsAnalysisService.call (new — rights analysis)
Both run, then redirect to → ② 체크리스트 tab
```

### 5-3. Route Changes

```ruby
resources :properties, only: [:index, :show, :create] do
  namespace :analyses do
    resource :start, only: [:create]            # existing (now runs both services)
    resource :checklist, only: [:edit, :update]  # renamed from :result
    resource :report, only: [:show, :update]     # ★ new (F03 report)
    resource :rating, only: [:show]              # existing
  end
end
```

- `results` → `checklist` rename (clearer role)
- `report#show`: View rights analysis report
- `report#update`: Update dividend simulation with expected bid input

### 5-4. Report Page Layout (③ Tab) — 4 Sections

**Section 1 — Summary Card:**

- Verdict badge: 안전(green) / 주의(yellow) / 위험(red)
- 3-line key basis summary
- Assumed amount + total risk amount display
- Opportunity badge (conditional): "안전 기회 물건" with reason and "⚠️ 추정치" marker

**Section 2 — Registry Timeline:**

- Vertical timeline showing rights in chronological order
- Base right highlighted with ★ marker and red styling
- Each tenant shows: opposing power determination result + reasoning ("전입일 다음날 00:00 > 말소기준일 → 후순위")
- Bottom: linked checklist references ("②체크리스트 탭에서 확인됨")

**Section 3 — Dividend Simulation:**

- Expected bid input field + "계산" button
- Priority-ordered distribution table (순위, 채권자, 유형, 채권액, 배당액, 미배당)
- "⚠️ 추정치 — 실제 배당과 다를 수 있습니다. 정확한 배당 결과는 법원 배당표를 확인하세요." disclaimer
- **Bidder burden summary** at bottom:
  - 예상 낙찰가 - 인수 금액 - 미확인 위험 금액 = 실질 부담 총액
  - Color-coded conclusion:
    - Green: "추가 인수 부담이 없는 구조입니다"
    - Yellow: "인수 금액 X원이 발생하나, 배당으로 회수 가능합니다"
    - Red: "인수 금액 X원이 추가 발생하는 구조입니다"

**Section 4 — Source Document Viewer:**

- Sub-tabs: 매각물건명세서 / 등기부등본
- Mock stage: raw_data formatted in readable display
- Real API stage: PDF viewer replacement
- Mock data notice: "Mock 데이터 — 실제 연동 시 원본 문서로 교체됩니다"

---

## 6. Overconfidence Prevention

Three mechanisms implementing the SRS design principle.

### 6-1. Source Document Viewer

See Section 5-4, Section 4 above.

### 6-2. Disclaimer Text (4 locations)

| Location | Text |
|---|---|
| Report Section 1 bottom | "본 분석은 AI가 생성한 참고 자료이며, 법적 효력이 없습니다. 투자 판단에 따른 책임은 이용자 본인에게 있습니다." |
| Dividend simulation badge | "⚠️ 추정치 — 실제 배당과 다를 수 있습니다. 정확한 배당 결과는 법원 배당표를 확인하세요." |
| Source doc viewer bottom | "반드시 매각물건명세서 비고란을 직접 확인하세요. 본 서비스는 분석 결과의 정확성을 보증하지 않습니다." |
| Report page bottom (legal) | See Section 6-3 below |

### 6-3. Legal Disclaimer (Page Bottom)

```
⚖️ 법적 고지

본 서비스의 권리 분석은 등기부등본, 매각물건명세서 등 공적 데이터를
기반으로 대한민국 민사집행법의 배당 원칙에 따라 체계적으로 수행됩니다.
다만 모든 분석 결과는 참고용이며, 법적 자문에 해당하지 않습니다.
실제 경매에서는 법원의 판단, 미공시 권리관계 등 본 서비스가 파악할 수
없는 변수가 존재할 수 있으므로, 분석 결과의 정확성 또는 완전성을
보증하지 않으며, 이를 근거로 한 투자 판단에 대해 법적 책임을 지지
않습니다. 중요한 결정 전에 반드시 법률 전문가의 자문을 받으시기
바랍니다.
```

### 6-4. Source Document Confirmation Popup

When user navigates to ④등급산정 tab without clicking the source document viewer sub-tab in ③:

```
매각물건명세서를 확인하셨습니까?

AI 분석만으로 판단하면 위험합니다.
원문을 직접 확인한 후 진행해 주세요.

[원문 확인하기]    [확인 없이 진행]
```

- Stimulus controller tracks source doc sub-tab click status
- "확인 없이 진행" allows proceeding but records `source_doc_reviewed: false` on `RightsAnalysisReport`

---

## 7. ViewComponents

### New Components

| Component | Role | Key Props |
|---|---|---|
| `PropertyTabsComponent` | ①②③④ tab navigation with numbered guides and completion status | `property`, `user`, `active_tab` |
| `ReportSummaryComponent` | Section 1 — summary card (verdict + 3-line basis + assumed amount + opportunity badge) | `report` |
| `RegistryTimelineComponent` | Section 2 — registry timeline + opposing power determination + checklist links | `report` |
| `DividendSimulatorComponent` | Section 3 — dividend table + bid input + bidder burden summary | `report` |
| `SourceDocViewerComponent` | Section 4 — source doc sub-tabs + formatted raw_data + disclaimer | `property` |
| `LegalDisclaimerComponent` | Legal disclaimer (page bottom) | — |
| `SourceDocConfirmModalComponent` | Confirmation popup when navigating to ④ without viewing source doc | — |

### Modified Components

| Component | Change |
|---|---|
| `RatingResultComponent` | Render within ④등급산정 tab. Existing functionality preserved |

### New Stimulus Controllers

| Controller | Role |
|---|---|
| `property_tabs_controller.js` | Tab switching (Turbo Frame loading), tab completion status display |
| `dividend_simulator_controller.js` | Expected bid input → POST to server → Turbo Stream update for dividend table |
| `source_doc_tracker_controller.js` | Track source doc sub-tab click status, show confirmation popup when navigating to ④ |

---

## 8. Acceptance Criteria

From SRS, mapped to this design:

- [ ] Extinguishment base right is correctly extracted from registry data (ExtinguishmentBaseRightExtractor)
- [ ] Tenant opposing power is correctly determined based on move-in date vs. base right date (OpposingPowerDeterminer)
- [ ] Assumed amount calculation accounts for confirmed date and dividend request deadline (AssumedAmountCalculator)
- [ ] Dividend simulation produces correct priority-ordered distribution table (DividendSimulator)
- [ ] Bidder burden summary clearly shows whether the structure results in additional costs
- [ ] Original document viewer is accessible alongside every AI report (SourceDocViewerComponent)
- [ ] Disclaimer text is displayed at all 4 designated locations
- [ ] Legal disclaimer conveys both analytical value and legal non-liability
- [ ] Skipping original document review triggers a confirmation popup
- [ ] HUG opposing-power waiver properties are auto-detected and labeled (OpportunityDetector)
- [ ] Full-dividend opportunity properties are detected with accuracy disclaimer
- [ ] Opportunity properties include plain-language safety explanations
- [ ] Report includes both 1-page summary (Section 1) and detailed analysis (Sections 2-4)
- [ ] Tab navigation with ①②③④ numbering guides beginners through analysis order
- [ ] Analysis start runs both PropertyAnalysisService and RightsAnalysisService
- [ ] F03 engine references existing checklist results (rights-003, rights-006, rights-009, rights-011) for comprehensive analysis
- [ ] MockRegistryAdapter generates deterministic random registry data for development

---

## 9. Out of Scope

- Real API integration (인터넷등기소, 대법원 경매정보)
- Full court-level dividend calculation (안분배당, 흡수설/비흡수설)
- Changes to existing AutoCheckRunner detection rules
- Changes to SafetyRatingService calculation logic
- Authentication/authorization (deferred per SRS)
- F04 integration (net profit calculator — separate feature)
- F05 integration (process checklist — separate feature)
