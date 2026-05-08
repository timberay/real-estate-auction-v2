# Eviction Simulator — Difficulty Breakdown Explanation

Date: 2026-05-08
Author: Tonny + Claude
Status: Draft (pending review)

## Problem

The eviction simulator displays a difficulty badge ("높음 / 중간 / 낮음") above the path visualization, but does not explain *why* that level was assigned. Beginners using the simulator cannot tell whether the rating came from the occupant type, from a risky answer they gave, or both. This undermines the educational purpose of the simulator.

## Goal

Show, directly under the difficulty badge, a structured breakdown that lets a beginner read off:

1. The **base difficulty** that comes with their occupant type, and why.
2. Any **additional risk factors** their "no" answers introduced, and why each one matters.
3. How the two combine into the final rating.

## Non-goals

- Changing how difficulty is computed (the algorithm stays the same).
- Showing breakdown anywhere other than the simulator result page.
- Persisting the breakdown to the DB (re-derived on render from `simulation.answers` + occupant type).
- Animations, tooltips, or expand/collapse interactions.

## Background — How difficulty is computed today

Source: [app/services/eviction_guide/difficulty_assessor.rb](../../../app/services/eviction_guide/difficulty_assessor.rb)

```ruby
LEVELS = { "high" => 3, "medium" => 2, "low" => 1 }

base_score = LEVELS[BASE_DIFFICULTY[occupant_type]]   # per-type baseline
max_score  = base_score

answers.each do |code, answer|
  next if answer == true                              # only "no" answers escalate
  impact = questions[code].difficulty_impact          # nil | "low" | "medium" | "high"
  max_score = LEVELS[impact] if LEVELS[impact] > max_score
end

LEVEL_FROM_SCORE[max_score]
```

So the final level is `max(base, all triggered impacts)`. Triggered impacts come only from "아니오" answers on questions that declare a `difficulty_impact`. Examples:

- `Q1G`: 권리분석 리스크 있음 → `high`
- `Q5`: 인도명령+가처분 미신청 → `high`
- `Q3G`: 즉시항고 제기됨 → `medium`
- `Q14G`: 관리비 일괄청구·단수단전 위협 → `medium`

The `BASE_DIFFICULTY` table is in [app/models/eviction_simulation.rb](../../../app/models/eviction_simulation.rb):

| Occupant type | Base | Beginner-friendly reason |
|---|---|---|
| `junior_tenant` (후순위 임차인) | 낮음 | 배당으로 보증금을 회수하므로 명도확인서 협상이 가능하고 인도명령 절차도 표준입니다. |
| `debtor_owner` (채무자 본인) | 중간 | 인도명령 대상이 명확하지만, 자진 퇴거 협상과 강제집행 단계가 남아 있어 1~3개월 소요됩니다. |
| `senior_tenant` (선순위 임차인) | 높음 | 보증금 인수 부담이 있고, 협상이 결렬되면 명도소송으로 6~12개월 추가됩니다. |
| `illegal_occupant` (불법 점유자) | 높음 | 인도명령이 불가능해 명도소송(6~12개월)으로만 진행 가능합니다. |

## Design

### UI

Inserted between the existing `DifficultyBadgeComponent` and the `명도 경로` heading in [app/components/eviction_guide/simulator_result_component.html.erb](../../../app/components/eviction_guide/simulator_result_component.html.erb).

```
[명도 난이도: 중간]                ← existing badge

┌─ 난이도 산정 근거 ─────────────────────────────────────┐
│                                                       │
│  기본 난이도 ㆍ 채무자 본인 → 중간                      │
│    인도명령 대상이 명확하지만, 자진 퇴거 협상과         │
│    강제집행 단계가 남아 있어 1~3개월 소요됩니다.        │
│                                                       │
│  추가 위험 요인 ㆍ 없음                                 │
│    답변상 새로 발생한 리스크가 없어                     │
│    기본 난이도가 그대로 유지됩니다.                     │
│                                                       │
│  ⓘ 기본 난이도와 추가 위험 중 더 높은 쪽이              │
│    최종 난이도가 됩니다.                                │
└───────────────────────────────────────────────────────┘
```

When triggers exist:

```
  추가 위험 요인 ㆍ 1건 (영향도: 높음)
    • S5 인도명령 + 점유이전금지가처분 동시 신청 → +높음
      잔금 납부일 당일 세트로 신청하는 것이 실무 정석입니다.
      6개월 기한을 놓치면 정식 명도소송으로 전환해야 합니다.
```

### Display rules

- Trigger label: use the **step name** (`step.name`) joined with the step code, NOT the question code. Beginners shouldn't see "Q5G".
- Trigger description: reuse the question's existing `help_text` (already beginner-tuned, no duplicate copy).
- "추가 위험 요인" header shows total count + the highest impact among triggers.
- Closing note explains the max() rule in plain Korean — no math notation.
- Print-friendly: included in printed output (no `print:hidden` class).

### Data layer — `DifficultyAssessor`

Extend the existing service to return a breakdown object instead of just the level. Keep a backwards-compatible accessor for callers that only want the level.

```ruby
# app/services/eviction_guide/difficulty_assessor.rb

def call
  # ... existing scoring logic ...
  Result.new(level:, base:, triggers:)
end

Result = Struct.new(:level, :base, :triggers, keyword_init: true) do
  def to_s = level   # so existing callers using string interpolation keep working
end

# base = { level: "medium", occupant_type: "debtor_owner" }
# triggers = [
#   { code: "Q5", step_code: "S5", step_name: "인도명령 + 점유이전금지가처분 동시 신청",
#     impact: "high", help_text: "잔금 납부일 당일..." },
#   ...
# ]
```

Existing callers:

- [app/controllers/eviction_guide/simulations_controller.rb](../../../app/controllers/eviction_guide/simulations_controller.rb) calls `DifficultyAssessor.call(...)` and assigns to `simulation.difficulty_level`. Update to use `result.level`.
- Existing tests rely on string return — update to use `result.level` or `to_s`.

### Component — `DifficultyBreakdownComponent`

New ViewComponent at `app/components/eviction_guide/difficulty_breakdown_component.{rb,html.erb}`.

```ruby
module EvictionGuide
  class DifficultyBreakdownComponent < ViewComponent::Base
    BASE_REASONS = {
      "junior_tenant"    => "배당으로 보증금을 회수하므로 명도확인서 협상이 가능하고 인도명령 절차도 표준입니다.",
      "debtor_owner"     => "인도명령 대상이 명확하지만, 자진 퇴거 협상과 강제집행 단계가 남아 있어 1~3개월 소요됩니다.",
      "senior_tenant"    => "보증금 인수 부담이 있고, 협상이 결렬되면 명도소송으로 6~12개월 추가됩니다.",
      "illegal_occupant" => "인도명령이 불가능해 명도소송(6~12개월)으로만 진행 가능합니다."
    }.freeze

    def initialize(simulation:)
      @simulation = simulation
      @breakdown  = DifficultyAssessor.call(
        simulation.answers,
        occupant_type: simulation.occupant_type
      )
    end

    # ... presenter helpers for level label, trigger list, etc.
  end
end
```

Step name lookup: load `EvictionStep.where(code: step_codes).index_by(&:code)` once. Steps are seeded data, small footprint.

Render call site in `simulator_result_component.html.erb`:

```erb
<%= render EvictionGuide::DifficultyBadgeComponent.new(level: @simulation.difficulty_level || "medium") %>
<%= render EvictionGuide::DifficultyBreakdownComponent.new(simulation: @simulation) %>
```

### Styling

- Same surface treatment as the existing stat cards (`bg-slate-50 dark:bg-slate-800 rounded-lg p-4`)
- Section labels (`기본 난이도`, `추가 위험 요인`) in `text-sm font-semibold text-slate-700 dark:text-slate-200`
- Trigger items as a `<ul>` with subtle bullets, indent for help_text
- Impact badges (`+높음 / +중간 / +낮음`) reuse the same color palette as the main difficulty badge

## Tests (TDD)

### `DifficultyAssessorTest`

- New: returns Result with `level`, `base`, `triggers`
- New: `triggers` is empty when no "no" answers escalate
- New: `triggers` includes step_code/step_name/help_text from joined question rows
- New: `Result#to_s` returns level (for back-compat)
- Existing tests updated to read `.level`

### `DifficultyBreakdownComponentTest` (new)

- Renders base reason for each of 4 occupant types
- "추가 위험 요인 없음" when no triggers
- Lists triggers with step name + impact + help_text when triggers present
- Trigger header shows count and highest impact
- Closing rule note rendered

### `SimulatorResultComponentTest`

- Adds an assertion that the breakdown component is rendered after the badge

## Risks / Edge cases

- **Unknown occupant_type** (data drift): fall back to a generic reason ("점유자 유형이 지정되지 않아 평균적인 난이도로 평가되었습니다.") — same fallback as `BASE_DIFFICULTY[type] || "medium"`.
- **Question deleted from seed but still in `answers`**: skip silently, just like the assessor already does.
- **`answers` is nil** (incomplete simulation reaching results page): empty triggers, base only.

## Out of scope (future)

- Showing the breakdown inline next to each step in the path visualization.
- Letting users hover/click triggers to jump back into the simulator and re-answer.
- Localizing English labels — Korean only for now (consistent with existing simulator UI).

## Open questions for review

- **Closing note styling** — small italic gray? Or a tinted callout? (Current proposal: small gray, no background.)
- **When triggers exist, do we still show the "ⓘ max() rule" closing note?** Current proposal: always show — it's the most important conceptual takeaway.
