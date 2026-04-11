# F03 Rights Analysis Enhancement — Design Spec

## Overview

Enhance the F03 rights analysis pipeline with a hybrid LLM + Ruby approach: LLM extracts facts (tenants, rights, dates), Ruby validates and recalculates opposing power (대항력) and priority repayment rights (우선변제권). Adds HUG opportunity detection, source document review tracking, and a rights timeline visualization.

## Motivation

The current implementation delegates opposing power determination entirely to the LLM, which introduces hallucination risk and non-deterministic results. The SRS requires "compare move-in date with base right date to auto-determine opposing power" — a deterministic calculation that belongs in Ruby. Additionally, several SRS features (HUG opportunity detection, source document confirmation, timeline visualization) remain unimplemented.

## Architecture: Layered Pipeline

```
PDF Upload → LLM (fact extraction) → RightsValidator (Ruby recalculation) → Storage
```

### Stage 1: LLM Fact Extraction (PdfPromptBuilder)

LLM extracts raw facts from court documents. It does NOT make final opposing power decisions — those are reference values for cross-validation.

**Tenant fields (updated):**

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Tenant name |
| `deposit` | integer | Deposit amount in KRW |
| `move_in_date` | string (YYYY-MM-DD) | Move-in registration date (전입신고일) |
| `confirmed_date` | string (YYYY-MM-DD) or null | Confirmed date (확정일자), null if absent |
| `opposing_power` | boolean | LLM's reference judgment (Ruby recalculates) |
| `priority_rank` | integer | LLM's reference ranking (Ruby recalculates) |

**HUG opportunity detection (new prompt addition):**

- Detect HUG (주택도시보증공사) related rights in registry: 전세보증금반환채권, HUG 근저당 etc.
- Determine if HUG has submitted a rights report waiver (권리신고 포기)
- Populate `opportunity_type`:
  - `"hug_waiver"` — HUG rights report waiver property
  - `"gap_investment"` — Gap investment opportunity
  - `null` — Not applicable
- Populate `opportunity_reason` with explanation

### Stage 2: RightsValidator Service (New)

`app/services/inspection/rights_validator.rb`

A pure-calculation service that takes LLM-extracted facts and produces validated results.

**Input:** `base_right_date`, `tenants` array, `rights_timeline` array

**Processing logic:**

1. **Opposing power determination (per tenant):**
   ```
   opposing_power = tenant.move_in_date < base_right_date
   ```
   Uses strict `<` (not `<=`) because opposing power takes effect from the day AFTER move-in registration (전입신고 익일 00:00 기준).

2. **Priority repayment rights (per tenant):**
   ```
   has_priority_repayment = opposing_power && confirmed_date != nil
   ```

3. **Priority rank recalculation:**
   Sort tenants with opposing power by `confirmed_date` ascending, assign sequential `priority_rank`.

4. **Amount recalculation:**
   - `assumed_amount` = sum of rights where `extinguished_on_sale == false`
   - `opposing_deposits` = sum of deposits from tenants where `opposing_power == true`
   - `total_risk_amount` = `assumed_amount` + `opposing_deposits`

5. **Discrepancy detection:**
   Compare LLM `opposing_power` vs Ruby `opposing_power` per tenant.
   Record differences in `discrepancies` array:
   ```json
   {
     "tenant_name": "김○○",
     "field": "opposing_power",
     "llm_value": false,
     "ruby_value": true,
     "reason": "move_in_date(2023-06-01) < base_right_date(2024-01-15)"
   }
   ```

**Output:**
- `validated_tenants` — tenants with Ruby-recalculated opposing_power, priority_rank
- `validated_amounts` — { assumed_amount, opposing_deposits, total_risk_amount }
- `discrepancies` — array of mismatches (empty if all agree)

**Interface:** `Inspection::RightsValidator.call(base_right_date:, tenants:, rights_timeline:)`

### Stage 3: Storage (report_data Structure)

**Updated `report_data` JSON schema:**

```json
{
  "llm_raw": {
    "tenants": [],
    "rights_timeline": [],
    "reasoning": "...",
    "checklist_references": []
  },
  "calculated": {
    "tenants": [],
    "assumed_amount": 0,
    "opposing_deposits": 0,
    "total_risk_amount": 50000000
  },
  "discrepancies": [],
  "user_simulation": {}
}
```

- `llm_raw` — LLM's original extraction, preserved for audit
- `calculated` — Ruby's validated results, used by all downstream components
- `discrepancies` — LLM vs Ruby mismatches
- `user_simulation` — dividend simulation results (unchanged)

**Backward compatibility:** If `report_data` lacks `llm_raw` key, treat top-level keys as `llm_raw` (no migration needed for existing data).

### PdfAnalysisService Changes

`create_or_update_report` method updated flow:

1. Extract LLM response into `llm_raw`
2. Call `Inspection::RightsValidator.call()` with extracted facts
3. Store `llm_raw`, `calculated`, `discrepancies` in `report_data`
4. DB columns (`assumed_amount`, `total_risk_amount`) use Ruby-calculated values

## UI Components

### A. RightsTimelineComponent (New)

`app/components/rights_timeline_component.rb`

Pure HTML/CSS horizontal timeline rendered server-side via ViewComponent.

- Rights timeline items sorted by date ascending
- Each item shows: date, type, holder, amount
- **Extinguished rights:** gray text with strikethrough
- **Assumed rights:** red highlight with bold amount
- **Base right marker:** vertical line with label "말소기준권리"
- **Opposing-power tenants:** displayed on timeline with distinct color (blue)
- Responsive: horizontal scroll on mobile

### B. Discrepancy Warning UI

Added to RightsReportSectionComponent.

- Only renders when `discrepancies` array is non-empty
- Warning banner: "⚠️ AI 판단과 자동계산 결과가 다른 항목이 있습니다"
- Table showing: tenant name, AI judgment, auto-calculation result, reason
- Styled as amber/yellow warning box

### C. Source Document Review Tracking

**Stimulus controller:** `source_doc_review_controller.js`

- Tracks when user clicks/opens document viewer tabs
- On tab open: PATCH to update `source_doc_reviewed = true` on RightsAnalysisReport
- When navigating to next step (e.g., market price check):
  - If `source_doc_reviewed == false`: show `confirm()` dialog
  - "원본 서류(매각물건명세서, 등기부등본)를 확인하셨나요?"
  - Cancel prevents navigation; OK allows proceed

**Endpoint:** `PATCH /inspections/:property_id/source_doc_review` (new route + controller action)

### D. HUG Opportunity Label

Added to RightsReportSectionComponent, above verdict summary.

- Renders only when `opportunity_type` is present
- Green badge: "안전 기회물건" with type-specific label
  - `hug_waiver`: "HUG 권리신고 포기"
  - `gap_investment`: "갭투자 기회"
- `opportunity_reason` shown in collapsible details element

## Component Data Flow Changes

All downstream components read from `calculated` namespace instead of top-level:

| Component | Before | After |
|-----------|--------|-------|
| SourceDocViewerComponent | `report_data["tenants"]` | `report_data["calculated"]["tenants"]` |
| DividendSimulatorComponent | `report_data["tenants"]` | `report_data["calculated"]["tenants"]` |
| DividendsController | `report_data["tenants"]` | `report_data["calculated"]["tenants"]` |
| RightsTimelineComponent | N/A (new) | `report_data["llm_raw"]["rights_timeline"]` + `report_data["calculated"]["tenants"]` |

**Backward compatibility helper** in RightsAnalysisReport model:

```ruby
def effective_tenants
  report_data.dig("calculated", "tenants") || report_data["tenants"] || []
end

def effective_rights_timeline
  report_data.dig("llm_raw", "rights_timeline") || report_data["rights_timeline"] || []
end
```

## Test Strategy

### Unit Tests

1. **RightsValidator** (core logic):
   - `move_in_date < base_right_date` → `opposing_power: true`
   - `move_in_date >= base_right_date` → `opposing_power: false`
   - `confirmed_date`-based `priority_rank` sorting
   - `assumed_amount` / `total_risk_amount` calculation accuracy
   - Discrepancy detection: LLM says false, Ruby says true → recorded
   - Edge cases: no tenants, no rights, `confirmed_date: null`

2. **PdfAnalysisService** (integration):
   - `report_data` contains `llm_raw` / `calculated` / `discrepancies` structure
   - DB columns use Ruby-calculated values
   - Backward compatibility with old `report_data` format

3. **PdfPromptBuilder**:
   - `confirmed_date` field present in prompt
   - HUG opportunity instructions present in prompt

### Component Tests

4. **RightsTimelineComponent**:
   - Renders items in date order
   - Extinguished vs assumed rights styled differently
   - Base right marker displayed

5. **Discrepancy warning**:
   - Renders warning when discrepancies present
   - No warning when discrepancies empty

### Fixture Updates

- `ai_inspection_response.json`: add `confirmed_date` to tenant entries
- Add `opportunity_type: "hug_waiver"` with `opportunity_reason`

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Opposing power calculation | Ruby (hybrid) | Deterministic, testable, auditable; LLM value preserved for cross-validation |
| Discrepancy handling | Warning banner in UI | Transparent to user; Ruby is default but LLM edge cases visible |
| Timeline visualization | Pure HTML/CSS | No JS dependencies; project minimizes JS; data is small (5-15 items) |
| report_data structure | llm_raw / calculated split | Clean separation; audit trail; backward compatible |
| HUG detection | LLM prompt enhancement | LLM reads documents; label only, no separate list (insufficient data volume) |
| Source doc tracking | Stimulus + PATCH | Lightweight; leverages existing Stimulus patterns |

## Out of Scope

- Separate "Opportunity Properties" list page (deferred until sufficient data)
- Rights relationship diagram (complex graph visualization — future iteration)
- Tenant eviction difficulty scoring (belongs to F10)
- PDF export of rights report (future enhancement)
