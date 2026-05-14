# Feature Restructure: Document-Based Property Analysis (6+1 Tab)

**Date:** 2026-04-07
**Status:** Draft
**Supersedes:** 2026-04-05-f02-safe-property-filtering-design.md, 2026-04-06-f03-rights-analysis-report-design.md, 2026-04-06-stepper-workflow-redesign.md, 2026-04-06-stepper-flow-and-ui-improvements-design.md, 2026-04-06-f03-unified-results-page-design.md

---

## Context

The existing property analysis flow uses a 3-step stepper (체크리스트 → 권리분석 → 등급산정) with 17 checklist items classified by risk axis (legal/resale/loan). This structure doesn't match how users actually work: they review documents one at a time (매각물건명세서 first, then 등기부등본, then 건축물대장), visit the field, check online sources, and finally decide whether to bid.

This redesign restructures the entire analysis around the **document the user is looking at**, not the abstract risk category. It also merges the rights analysis report (F03) into the analysis flow and expands from 17 to 89 inspection items.

## Feature Number Restructure

### Removed Features
- **Old F03 (권리 분석 리포트)** — Merged into new F02's 최종등급 tab
- **Old F05 (프로세스 체크리스트)** — New tab structure replaces the process guide role
- **Old F08 (가상 입찰 시뮬레이션)** — Removed from roadmap
- **Old F09 (온라인 사전 임장)** — Removed from roadmap

### New Feature Map (11 → 7)

#### 핵심기능 (P0 — MVP)

| ID | Old ID | Name | Description | Change |
|----|--------|------|-------------|--------|
| F01 | F01 | 온보딩 예산 설정 | 3-step budget wizard, loan ratio, max bid calculation | No change |
| **F02** | **F02+F03** | **물건분석 (6+1탭)** | **Document-based 89-item inspection with integrated rights analysis and final grade** | **Full redesign** |
| F03 | F04 | 순수익 계산기 | Net profit calculator with tax breakdown, reverse-calculation mode | Renumbered only. Separate screen |

#### 확장기능 (P1 — Early Expansion)

| ID | Old ID | Name | Description | Change |
|----|--------|------|-------------|--------|
| F04 | F06 | 통합 시세 조회 | Integrated market price dashboard with gap-rate warning | Renumbered |
| F05 | F07 | 대출 사전 매칭 | Pre-auction loan matching with consultant network | Renumbered |

#### 성장기능 (P2–P3 — Growth)

| ID | Old ID | Name | Description | Change |
|----|--------|------|-------------|--------|
| F06 | F10 | 명도 시나리오 가이드 | Eviction scenario guide with document auto-generation | Renumbered |
| F07 | F11 | 전문가 멘토링 연결 | Expert 1:1 feedback connection (mentoring marketplace) | Renumbered |

### Feature Dependency Map (Updated)

```
F01 Onboarding Budget Setup
 |
 v
F02 Property Inspection (6+1 Tab) ──→ F04 Market Price Dashboard
 |   (89 items + rights analysis       |
 |    + final grade)                    v
 |                               F03 Net Profit Calculator
 |                                      |
 ├── F06 Eviction Scenario Guide        v
 |                               F05 Pre-Auction Loan Matching
 v
F07 Expert Mentoring Connection
    (callable from any step)
```

---

## New F02: Property Inspection (물건분석)

### Tab Structure

```
Property Inspection Screen
├── [매각물건명세서] 18 items — Court auction site (courtauction.go.kr)
├── [등기부등본]     12 items — Internet Registry (iros.go.kr)
├── [건축물대장]      9 items — Gov24 (gov.kr)
├── [온라인조회]     22 items — Market price sites, tax portals, map services
├── [현장임장]       18 items — Field visit (site + gov office + bank + management)
├── [기타]           10 items — In-app calculation, user judgment
└── [최종등급]       Aggregated results + rights analysis report + bid decision
```

**Total: 89 inspection items + 1 grade summary tab = 7 tabs**

**Navigation:** Free-form tab navigation (not sequential stepper). Users can visit any tab in any order and return to modify. Tab order serves as a recommended workflow guide.

### Item Source (checklist_items_summary.json)

All 89 items are defined in `db/seeds/checklist_items_summary.json` with fields:
- `id`: unique item code (e.g., "rights-001")
- `tab`: tab classification (매각물건명세서, 등기부등본, 건축물대장, 온라인조회, 현장임장, 기타)
- `tab_position`: display order within tab
- `category`: original domain category (권리분석, 물건 기본 필터링, etc.)
- `question`, `description`: item content
- `logic`: auto-check detection rules (JSON)
- `data_source`: where to verify (name + URL)
- `priority`: 상/중/하
- `merged_from`: (optional) ID of item that was merged into this one

### Per-Tab Behavior

Each tab renders its inspection items with identical interaction pattern:

1. **On analysis start:** `InspectionRunner` executes auto-check rules against property `raw_data`
2. **Auto-check succeeds:** Result displayed (위험/안전 badge + reasoning from `logic`)
3. **Auto-check fails or N/A:** Manual input form shown (risk yes/no radio)
4. **Risk detected:** Resolvable toggle (yes/no) + resolution note textarea
5. **Tab completion indicator:** Badge showing `checked/total` count on tab header

### Tab-Specific Details

#### 매각물건명세서 (18 items)
- Primary data source: `raw_data` from court auction API (매각물건명세서 + 현황조사서 + 배당표)
- Most items auto-checkable from API data
- Includes tenant analysis items (rights-003, rights-006, rights-014, rights-015, rights-016)
- Items rights-010 (배당표) feeds into 최종등급's dividend simulation

#### 등기부등본 (12 items)
- Primary data source: registry API (등기부등본 갑구/을구)
- Rights analysis sub-modules extract data from this tab's items:
  - `ExtinguishmentBaseRightExtractor` uses rights-001, rights-004, rights-007, rights-008
  - `OpposingPowerDeterminer` uses rights-012, rights-013
- Item inspect-003 (유사 사례 교차 검증) is manual-only

#### 건축물대장 (9 items)
- Primary data source: building ledger API
- Mostly property filtering items (위반건축물, 용도, 방구조, 주차)
- Item inspect-002 (감정평가서-건축물대장 불일치) requires cross-reference

#### 온라인조회 (22 items)
- No single API — diverse external sources
- Market analysis items (market-001~008, 012) require manual input in MVP
- Tax/regulation items (tax-001, 003~005) partially automatable
- Future: integrate external APIs (네이버 부동산, KB시세, 부동산공시가격 알리미)

#### 현장임장 (18 items)
- All manual input — requires physical site visit
- Includes: field inspection, real estate agent interviews, bank calls, gov office visits
- Item inspect-009 (부동산 소장 매도가 팁) is key for profit estimation
- Item finance-001 (DSR/대출 계획) links to future F05

#### 기타 (10 items)
- In-app calculations: invest-001, invest-003, inspect-011 (수익률 계산)
- User judgment: tax-002 (입찰 명의), bidding-002 (비교 물건 수), bidding-004 (입찰표 검증)
- manual-001 (분묘기지권) — always manual

### 최종등급 Tab

Aggregates all inspection results into a final bid decision.

#### Section 1: Overall Grade

```
┌─────────────────────────────────────┐
│         전체 등급: 주의              │
│  "위험 항목이 있지만 모두 해결 가능"   │
└─────────────────────────────────────┘
```

**Rating logic (InspectionRatingService):**
- **위험 (Danger):** Any item has `has_risk=true` AND `resolvable=false`
- **주의 (Caution):** Any item has `has_risk=true` (but all resolvable)
- **안전 (Safe):** No items have `has_risk=true`
- **미완료:** Any item has `has_risk=null` (unanswered) → warning banner, grade not finalized

#### Section 2: Tab Summary

```
| Tab          | 안전 | 위험 | 미입력 |
|-------------|------|------|--------|
| 매각물건명세서 | 15  |  2   |   1    |
| 등기부등본    | 12  |  0   |   0    |
| 건축물대장    |  8  |  1   |   0    |
| 온라인조회    | 18  |  2   |   2    |
| 현장임장      | 10  |  1   |   7    |
| 기타         |  8  |  0   |   2    |
```

Each row clickable → navigates to that tab filtered by status.

#### Section 3: Risk Items Detail

List all items where `has_risk=true`, grouped by resolvable status:
- **해결 불가능** (red) — items blocking safe bid
- **해결 가능** (yellow) — items with resolution plan
- Each item shows: question, tab source, resolution note

#### Section 4: Rights Analysis Report (Integrated from old F03)

Rendered inline in 최종등급 tab (not a separate page):

**(A) Core Analysis Results:**
- 말소기준권리: type, date, holder (from 등기부등본 tab items)
- 대항력 판단: per-tenant opposing power table
- 인수금액: total assumed amount the bidder must bear
- Verdict: safe/caution/danger with reasoning

**(B) Dividend Simulation:**
- User inputs expected bid amount (만원)
- Priority-ordered distribution table
- Highlights: tenants who won't receive full dividend → assumed amount

**(C) Opportunity Detection:**
- HUG waiver properties → "안전 기회 물건" badge
- Full-dividend opportunities → separate highlight

**(D) Overconfidence Prevention (Maintained):**
- Source document viewer toggle (매각물건명세서 / 등기부등본 원본)
- Disclaimer: "AI 생성 참고 자료입니다. 원본 서류를 직접 확인하세요"
- `source_doc_reviewed` tracking per user

### Data Model (Full Redesign)

#### New Models

```ruby
# InspectionItem — replaces ChecklistItem
# Stores the master list of 89 inspection items
create_table :inspection_items do |t|
  t.string  :code,             null: false, index: { unique: true }
  t.integer :tab,              null: false  # enum: sale_document, registry, building_ledger, online, field_visit, etc
  t.integer :tab_position,     null: false, default: 0
  t.string  :category,         null: false
  t.text    :question,         null: false
  t.text    :description
  t.json    :logic                          # auto-check detection rules
  t.string  :data_source_name
  t.string  :priority,         null: false, default: "상"
  t.string  :merged_from                    # tracks deduplication origin
  t.timestamps
end
add_index :inspection_items, [:tab, :tab_position]

# InspectionResult — replaces PropertyCheckResult
# Per-user, per-property, per-item inspection result
create_table :inspection_results do |t|
  t.references :property,        null: false, foreign_key: true
  t.references :inspection_item, null: false, foreign_key: true
  t.references :user,            null: false, foreign_key: true
  t.integer    :source_type                  # enum: auto, manual (nil = unanswered)
  t.boolean    :has_risk                     # nil=unanswered, true=risk, false=safe
  t.boolean    :resolvable                   # nil if no risk
  t.text       :resolution_note
  t.text       :auto_value                   # raw value from API auto-check
  t.text       :manual_value                 # user-entered value
  t.timestamps
end
add_index :inspection_results, [:property_id, :inspection_item_id, :user_id], unique: true, name: "idx_inspection_results_unique"
```

#### Retained Models (Unchanged)
- `RightsAnalysisReport` — keeps all existing fields, rendered in 최종등급 tab
- `Property` — unchanged
- `UserProperty` — unchanged (safety_rating updated by InspectionRatingService)
- `User` — unchanged

#### Removed Models
- `ChecklistItem` — replaced by `InspectionItem`
- `PropertyCheckResult` — replaced by `InspectionResult`

### Service Layer (Full Redesign)

```
PropertyInspectionService.call(property, user)
├── InspectionRunner.call(property, user)
│   ├── Loads all 89 InspectionItems
│   ├── For each item with detection rules in `logic`:
│   │   ├── Evaluate rule against property.raw_data
│   │   └── Create/update InspectionResult (source_type: auto, has_risk: true/false)
│   └── For items without rules: leave InspectionResult as nil (awaiting manual input)
│
├── RightsAnalysisService.call(property, user)  # Retained from old F03
│   ├── ExtinguishmentBaseRightExtractor
│   ├── OpposingPowerDeterminer
│   ├── AssumedAmountCalculator
│   ├── OpportunityDetector
│   └── Creates/updates RightsAnalysisReport
│
└── InspectionRatingService.call(property, user)
    ├── Queries all InspectionResults for (property, user)
    ├── Applies rating logic: danger > caution > safe
    ├── Checks for unanswered items → incomplete flag
    └── Updates UserProperty.safety_rating + analyzed_at
```

#### New Services
- `InspectionRunner` — replaces `AutoCheckRunner`, handles 89 items
- `InspectionRatingService` — replaces `SafetyRatingService`, works with new model

#### Retained Services
- `RightsAnalysisService` + all sub-services (5 modules) — unchanged
- `PropertyAnalysisService` — renamed to `PropertyInspectionService`

#### Removed Services
- `AutoCheckRunner` — replaced by `InspectionRunner`
- `SafetyRatingService` — replaced by `InspectionRatingService`

### Routes

```ruby
resources :properties do
  namespace :inspections do
    resource :start, only: [:create]
    # Tab routes — each tab is a separate edit/update cycle
    resource :sale_document,   only: [:edit, :update]  # 매각물건명세서
    resource :registry,        only: [:edit, :update]  # 등기부등본
    resource :building_ledger, only: [:edit, :update]  # 건축물대장
    resource :online,          only: [:edit, :update]  # 온라인조회
    resource :field_visit,     only: [:edit, :update]  # 현장임장
    resource :etc,             only: [:edit, :update]  # 기타
    resource :grade,           only: [:show]           # 최종등급
    resource :dividend,        only: [:update]         # 배당 시뮬레이션 (within grade)
  end
end
```

### UI Components

#### New Components
- `InspectionTabsComponent` — 7-tab horizontal navigation with completion badges
- `InspectionItemComponent` — individual item card (auto/manual, risk/safe/unanswered states)
- `InspectionGroupComponent` — groups items within a tab (by category)
- `GradeSummaryComponent` — overall grade display (안전/주의/위험/미완료)
- `TabSummaryTableComponent` — tab-by-tab status table
- `RiskItemsListComponent` — grouped risk items detail
- `RightsReportSectionComponent` — inline rights analysis report in grade tab
- `DividendSimulatorComponent` — reused from old F03 (만원 unit)

#### Removed Components
- `StepperComponent` — replaced by `InspectionTabsComponent`
- `ChecklistGroupComponent` — replaced by `InspectionGroupComponent`
- `ChecklistItemComponent` — replaced by `InspectionItemComponent`

#### Retained Components
- `RatingResultComponent` — reused in `GradeSummaryComponent`
- `ReportSummaryComponent` — reused in `RightsReportSectionComponent`
- `RegistryTimelineComponent` — reused in grade tab
- `SourceDocViewerComponent` — reused for overconfidence prevention
- `DocumentVerificationComponent` — reused
- `LegalDisclaimerComponent` — reused

### Stimulus Controllers

#### New Controllers
- `inspection_tabs_controller.js` — tab switching via Turbo Frames
- `inspection_item_controller.js` — risk/resolution toggle (replaces resolution_input_controller)

#### Removed Controllers
- `stepper_controller.js` — replaced by inspection_tabs_controller
- `resolution_input_controller.js` — replaced by inspection_item_controller

### Seed Data

`db/seeds/checklist_items_summary.json` (already updated) contains all 89 items with `tab` and `tab_position` fields.

Seed script creates `InspectionItem` records from this JSON:
```ruby
checklist_data.each do |attrs|
  InspectionItem.find_or_create_by!(code: attrs["id"]) do |item|
    item.tab = attrs["tab"]
    item.tab_position = attrs["tab_position"]
    item.category = attrs["category"]
    item.question = attrs["question"]
    item.description = attrs["description"]
    item.logic = attrs["logic"]
    item.data_source_name = attrs.dig("data_source", 0, "name") || "수동 입력"
    item.priority = attrs["priority"]
    item.merged_from = attrs["merged_from"]
  end
end
```

---

## Migration Plan

### Database
1. Create `inspection_items` table
2. Create `inspection_results` table
3. Drop `checklist_items` table
4. Drop `property_check_results` table
5. Retain `rights_analysis_reports` table (no changes)

### Code Removal
- Delete: `ChecklistItem`, `PropertyCheckResult` models
- Delete: `AutoCheckRunner`, `SafetyRatingService` services
- Delete: `StepperComponent`, `ChecklistGroupComponent`, `ChecklistItemComponent`
- Delete: `stepper_controller.js`, `resolution_input_controller.js`
- Delete: `analyses/` controllers and views (start, checklists, ratings, reports, results)

### Code Retention
- Keep: `RightsAnalysisService` + 5 sub-modules
- Keep: `RightsAnalysisReport` model
- Keep: `Property`, `UserProperty`, `User` models
- Keep: `RatingResultComponent`, `ReportSummaryComponent`, `RegistryTimelineComponent`, `SourceDocViewerComponent`, `DocumentVerificationComponent`, `LegalDisclaimerComponent`, `DividendSimulatorComponent`

---

## Design Principles (Maintained)

All 3 original SRS design principles still apply:

1. **반복 숙달 유도** — Tab structure with completion badges encourages thorough analysis; cumulative count tracking
2. **과신 방지** — Source document viewer in 최종등급 tab; disclaimers; confirmation when grade viewed without document review
3. **현장 존중** — 현장임장 tab explicitly separates field-only items; cannot achieve "안전" grade without field visit items answered

---

## Verification

### Manual Testing
1. Start analysis → verify all 89 items created as InspectionResults
2. Check each tab shows correct items in tab_position order
3. Verify auto-check results populate for items with detection rules
4. Test manual input flow: risk toggle → resolvable → resolution note
5. Verify 최종등급 tab aggregates all results correctly
6. Test dividend simulation with expected bid input
7. Verify rights analysis report renders inline in 최종등급
8. Test free navigation between tabs (no sequential enforcement)

### Automated Testing (Minitest)
- Model tests: InspectionItem validations, InspectionResult unique constraint
- Service tests: InspectionRunner with mock raw_data, InspectionRatingService rating logic
- Integration tests: full flow from start → tab edits → grade view
- Component tests: each new ViewComponent renders correctly for all states
