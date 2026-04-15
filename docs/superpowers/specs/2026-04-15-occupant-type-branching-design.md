# Occupant-Type Branching Design

## Overview

Eviction simulator currently uses a single linear step sequence (S1~S15) for all cases. This design introduces occupant-type-based branching where the simulator presents a completely independent step sequence based on the occupant type, determined at simulation start.

## Occupant Type Taxonomy

| Code | Name | Description | Base Difficulty |
|------|------|-------------|-----------------|
| `junior_tenant` | 후순위 임차인 (배당 수령) | Tenant after base right, recovers deposit via dividend | low |
| `senior_tenant` | 선순위 임차인 (대항력 有) | Tenant with opposing power, deposit return issue | high |
| `debtor_owner` | 채무자 (소유자) 본인 | Former owner occupying, emotional resistance likely | medium |
| `illegal_occupant` | 불법 점유자 / 제3자 | No legal basis for occupation | high |

## Data Model Changes

### EvictionSimulation

Add `occupant_type` column (string, nullable). Null means legacy simulation without type selection.

### EvictionStep

Add `occupant_type` column (string, nullable). Null means shared/legacy step. Non-null means type-specific step.

### EvictionSimulatorQuestion

Add `occupant_type` column (string, nullable). Same semantics as EvictionStep.

### Seed Data Convention

Type-specific steps use prefixed codes:

| Type | Step Prefix | Question Prefix | Branch Prefix |
|------|-------------|-----------------|---------------|
| `junior_tenant` | `JT-S*` | `JT-Q*` | `JT-B*` |
| `senior_tenant` | `ST-S*` | `ST-Q*` | `ST-B*` |
| `debtor_owner` | `DO-S*` | `DO-Q*` | `DO-B*` |
| `illegal_occupant` | `IO-S*` | `IO-Q*` | `IO-B*` |

Existing S1~S15, Q1~Qn, B1~B11 remain with `occupant_type: null` for backward compatibility.

### Type Summary Seed Data

Each occupant type has a `type_summary` entry in seed data for the result screen:

```json
{
  "occupant_type_summaries": [
    {
      "occupant_type": "junior_tenant",
      "summary": "배당을 수령한 후순위 임차인은 퇴거 의무가 명확합니다. 배당 수령 사실을 활용한 협상이 핵심입니다.",
      "key_warnings": ["인도명령 6개월 기한 관리", "명도확인서 선교부 금지"]
    }
  ]
}
```

## Entry Flow

### Scenario A: Property-Linked (F02 → Simulator)

1. User enters prefill page
2. F02DataExtractor extracts `occupant_type` from RightsAnalysisReport
3. Extracted type displayed on prefill screen, user can confirm or change via select/radio
4. "AI가 권리분석 보고서에서 추출" label shown next to auto-selected type
5. If F02 extraction returns nil (occupant_type not in report), field shows as unselected — user must manually choose before proceeding
6. Confirmed type saved to `EvictionSimulation.occupant_type`
7. Simulator starts with that type's step sequence

### Scenario B: Standalone (No Property)

1. On simulation create, type selection screen shown as first step
2. Four cards displayed vertically: type name + 1-line description + difficulty badge
3. Selection saved to `EvictionSimulation.occupant_type`
4. Simulator starts with that type's step sequence

### Type Immutability

Once the simulator starts, `occupant_type` cannot be changed. To simulate a different type, create a new simulation. Reason: type-specific step sequences are completely independent, so mid-simulation type change would break answer data integrity.

## Service Changes

### PathBuilder

```ruby
PathBuilder.call(answers, occupant_type:)
```

- Receives `occupant_type` parameter
- Filters steps: `EvictionStep.where(occupant_type: occupant_type)` — only that type's steps, no mixing with legacy
- Filters questions: only those linked to filtered steps
- Existing branch logic unchanged — type-specific branches also filtered by `occupant_type`
- When `occupant_type` is nil (legacy), filters `EvictionStep.where(occupant_type: nil)` — behaves exactly as current implementation

### DifficultyAssessor

```ruby
DifficultyAssessor.call(answers, occupant_type:, questions: nil)
```

- Receives `occupant_type` parameter
- Sets base difficulty from type taxonomy:
  - `junior_tenant` → "low"
  - `senior_tenant` → "high"
  - `debtor_owner` → "medium"
  - `illegal_occupant` → "high"
- Applies existing answer-based `difficulty_impact` scoring on top
- Final difficulty = max(base difficulty, answer-based difficulty)
- When `occupant_type` is nil (legacy), behaves exactly as current implementation

## Controller Changes

### SimulationsController

- `create`: Accepts `occupant_type` param. If absent, redirects to type selection screen.
- `prefill`: F02DataExtractor result includes `occupant_type`, displayed with edit capability.
- `update`: Unchanged (records answers).
- `show`: Passes `occupant_type` to PathBuilder and DifficultyAssessor.

## UI/UX

### Type Selection Screen (Standalone)

Four cards stacked vertically:
- **Title**: Type name in Korean
- **Description**: 1-line explanation
- **Difficulty badge**: Color-coded (green=low, yellow=medium, red=high)
- **Selection**: Turbo Frame submit

### Prefill Screen Changes (Property-Linked)

Existing F02PrefillComponent gains occupant type field:
- Select/radio with 4 options
- Auto-selected from F02 extraction
- Label: "AI가 권리분석 보고서에서 추출"

### Simulator Progress

- Occupant type badge displayed at top throughout simulation
- Progress bar calculated against that type's total step count

### Result Screen

- Occupant type + base difficulty shown at top
- Type-specific summary (from seed data `type_summary` field) displayed before step list
- Existing path/branch display unchanged

### Hotwire

- Type selection: wrapped in `turbo_frame_tag`, submits to create action
- Remaining question flow: unchanged

## Content Strategy — Phased Rollout

### Phase 1: junior_tenant (Pilot)

Simplest case, validates entire structure:

| Code | Step | Key Point |
|------|------|-----------|
| JT-S1 | 배당표 확인 | Dividend receipt status, amount |
| JT-S2 | 잔금 납부 & 인도명령 신청 | 6-month deadline management |
| JT-S3 | 1차 접촉 & 퇴거 통보 | Leverage dividend receipt in negotiation |
| JT-S4 | 명도확인서 교환 협상 | Issue after confirmed vacancy only |
| JT-S5 | 관리비 정산 | Public vs private charge separation |
| JT-S6 | 인수 완료 | Facility check, lock change |

Branches: JT-B1 (dividend not received), JT-B2 (negotiation failure → enforcement)

### Phase 2: debtor_owner

Emotional resistance handling, unjust enrichment claim steps.

### Phase 3: senior_tenant

Deposit return linkage, long-term strategy steps.

### Phase 4: illegal_occupant

Immediate legal action, criminal complaint steps.

### Legacy Step Handling

Existing S1~S15 remain with `occupant_type: null`. When no type is selected (backward compatibility), current flow works unchanged. After all type-specific sequences are complete, legacy steps may be deprecated (separate decision).

## Backward Compatibility

- `occupant_type: null` on all existing records and seed data
- PathBuilder/DifficultyAssessor with `occupant_type: nil` behaves identically to current implementation
- No migration needed for existing EvictionSimulation records — they continue to work with legacy steps
