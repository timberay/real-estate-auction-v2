# Stepper Flow & UI Improvements Design

**Date:** 2026-04-06
**Status:** Approved
**Scope:** Analysis stepper workflow reordering, rights analysis UI enhancements, currency unit standardization

## Problem Statement

The current analysis stepper has four issues:

1. **No forward navigation from grade result** — After checklist completion, the grade result screen has "다시 분석하기" and "목록으로 돌아가기" but no button to proceed to rights analysis (step 2).
2. **Rights analysis UI issues** — The grade label says "권리 분석 판정" (misleading since rights analysis isn't complete yet), "핵심 근거" sometimes shows "false", missing checklist summary and price info.
3. **Wrong currency unit** — Dividend simulation uses "원" (Won) instead of "만원" (10,000 Won), the application's standard unit.
4. **Rating tab locked** — No completion mechanism on the rights analysis tab, so the rating tab (step 3) stays locked with "이전 단계를 먼저 완료해주세요".

## Approach

**Minimal change** — Keep existing controllers, services, and model structure. Adjust navigation flow, UI labels, and add a user confirmation step to the rights analysis tab.

## Design

### 1. Sequential Flow: Checklist(1) → Rights Analysis(2) → Rating(3)

#### Before

```
Checklist edit → "등급 산정" click → SafetyRatingService → Rating result (end)
Rights analysis tab: independently viewable, no completion concept
Rating tab: unlocked by report.present? (always true after analysis start)
```

#### After

```
[Step 1: Checklist]
  Checklist edit → "물건 등급 확인하기" click
  → SafetyRatingService → Grade result screen
  → "권리 분석 진행" button → navigates to Step 2

[Step 2: Rights Analysis]
  Top: "체크리스트 분석 결과" label + grade card
       + 핵심 근거 + checklist review summary + appraisal price / min bid price
  Middle: Registry timeline, dividend simulation (만원 unit)
  Bottom: Document verification section
       → "예, 동일합니다" click → saves user_confirmed_at → unlocks Step 3

[Step 3: Rating]
  Shows checklist grade + rights analysis verdict side by side
  (Combined scoring logic deferred to future work)
```

#### Stepper Completion Conditions

| Step | Current `step_completed?` | New |
|------|--------------------------|-----|
| Checklist | `user_property.analyzed_at.present?` | **No change** |
| Rights Analysis | `report.present?` | `report&.user_confirmed_at.present?` |
| Rating | `user_property.safety_rating.present?` | **No change** |

#### DB Change

Add `user_confirmed_at:datetime` column to `rights_analysis_reports` table.

### 2. Rights Analysis (Step 2) Screen Changes

#### 2a. Grade Card Label Fix

`ReportSummaryComponent`:
- Label: "권리 분석 판정" → **"체크리스트 분석 결과"**
- Accept `property:` parameter in addition to `report:`
- Display `property.appraisal_price` (감정가) and `property.min_bid_price` (최저매각가) alongside existing 인수 금액 / 총 위험 금액

#### 2b. "false" Bug Fix

In `RightsAnalysisService#compute_verdict`, add nil/false guards when interpolating `base_right` fields and tenant data. Likely cause: mock/seed `raw_data` contains boolean `false` instead of string values for `type`, `holder`, etc.

#### 2c. Checklist Review Summary

Add a summary line below 핵심 근거 showing risk axis results. Source: `report_data["checklist_references"]` mapped to human-readable text.

Format example: "법적 위험: 유치권 신고 있음 / 매도 위험: 없음 / 대출 위험: 없음"

#### 2d. Document Verification Section

New `DocumentVerificationComponent`:

- Displays key analysis findings extracted from `verdict_summary` + `report_data` (tenants, rights)
- Prompt: "아래 분석 내용이 물건명세서 및 건축물대장과 동일한지 확인해주세요."
- Bulleted list of key items (말소기준권리, 임차인 정보, etc.)
- "예, 동일합니다" button → `PATCH reports#confirm` → sets `user_confirmed_at`
- "아니오" button → disabled with tooltip "추후 지원 예정"

#### 2e. Confirm Action

New route and controller action:

```ruby
# config/routes.rb — inside analyses namespace
resource :report, only: [:show, :update] do
  patch :confirm, on: :member
end

# ReportsController#confirm
def confirm
  @report = RightsAnalysisReport.find_by!(property: @property, user: current_user)
  @report.update!(user_confirmed_at: Time.current)
  redirect_to property_analyses_rating_url(@property)
end
```

### 3. Dividend Simulation Currency Unit Change

#### Storage Unit

All amounts in **만원** (10,000 Won) as integers.

#### Input Parsing (Stimulus controller)

The `dividend_simulator_controller.js` parses natural language input to 만원 integer:

| User Input | Parsed (만원) | Display |
|-----------|--------------|---------|
| `12000` | 12000 | 1억 2,000만원 |
| `1억 2000` | 12000 | 1억 2,000만원 |
| `1억2000` | 12000 | 1억 2,000만원 |
| `1억 2천` | 12000 | 1억 2,000만원 |
| `1억2천` | 12000 | 1억 2,000만원 |
| `1억` | 10000 | 1억원 |
| `5000` | 5000 | 5,000만원 |
| `500만원` | 500 | 500만원 |

**Parsing algorithm:**
1. Remove spaces and commas
2. Extract 억 component → multiply by 10000
3. Extract 천 component → multiply by 1000
4. Remove 만원/만 suffix
5. Remaining digits treated as 만원
6. Sum all components

#### Display Format

- ≥ 10000: `X억 Y,000만원` (Y=0 → `X억원`)
- < 10000: `X,XXX만원`
- Unit label next to input: "원" → **"만원"**

#### Server-side

- `ReportsController#update`: parse `params[:expected_bid]` as 만원 integer
- `DividendSimulator`: all internal calculations in 만원
- Distribution table amounts: 만원 unit with readable format

### 4. Stepper UI Changes

#### Always Show Step Numbers

Current: completed steps show `✓` replacing the number.
New: **always show numbers** (`1.`, `2.`, `3.`). Completion indicated by color/style only.

```
Before: ✓ 체크리스트  |  2. 권리 분석  |  3. 등급 산정
After:  1. 체크리스트  |  2. 권리 분석  |  3. 등급 산정
        (completed)      (active)         (pending)
```

#### Button Rename

Checklist submit button: `"등급 산정"` → **`"물건 등급 확인하기"`**

#### Grade Result Screen Buttons

Current: "다시 분석하기" (secondary) + "목록으로 돌아가기" (primary)
New: "다시 분석하기" (secondary) + **"권리 분석 진행" (primary)** + "목록으로 돌아가기" (secondary)

#### Rating Screen (Step 3)

Display two grade cards side by side:

```
┌──────────────────┐  ┌──────────────────┐
│ 🟢 안전           │  │ 🟡 주의           │
│ 체크리스트 등급    │  │ 권리 분석 등급     │
└──────────────────┘  └──────────────────┘
```

Combined scoring logic is deferred to future work.

## Files to Change

| File | Change |
|------|--------|
| `stepper_component.html.erb` | Always show number, remove ✓ logic |
| `stepper_component.rb` | `step_completed?(:report)` → check `user_confirmed_at` |
| `checklists/edit.html.erb` | Button text "물건 등급 확인하기" |
| `ratings/show.html.erb` | Add "권리 분석 진행" button, adjust button styles |
| `report_summary_component.rb` | Accept `property:`, add price display |
| `report_summary_component.html.erb` | Label change, prices, checklist summary |
| `reports/show.html.erb` | Add `DocumentVerificationComponent` |
| `reports_controller.rb` | Add `confirm` action, 만원 parsing in `update` |
| `dividend_simulator_component.rb/.html.erb` | 만원 unit display and labels |
| `dividend_simulator_controller.js` | Natural language parsing + 만원 format |
| `rights_analysis_service.rb` | nil/false guard in `compute_verdict` |
| `ratings/show.html.erb` (step 3) | Dual grade card display |
| `config/routes.rb` | Add `confirm` route |
| **New:** `DocumentVerificationComponent` | Document verification UI |
| **New:** migration | Add `user_confirmed_at` to `rights_analysis_reports` |

## Out of Scope

- "아니오" flow for document verification (requires data editing screen)
- Combined rating logic (체크리스트 + 권리 분석 → single grade)
- Official land price (공시지가) — not in current schema
