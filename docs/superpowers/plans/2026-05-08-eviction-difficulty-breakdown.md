# Eviction Difficulty Breakdown — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show a structured breakdown under the difficulty badge on the eviction simulator result page so beginners can read off (1) the base difficulty for their occupant type, (2) any extra risk factors their "no" answers triggered, and (3) why the final level is what it is.

**Architecture:**
- **Data layer:** `DifficultyAssessor` is refactored to return a `Result` struct (`level`, `base`, `triggers`) instead of a bare string. `Result#to_s` returns `level` so existing string interpolators keep working. The structural rename happens in a dedicated commit (Tidy First).
- **Presentation:** A new `EvictionGuide::DifficultyBreakdownComponent` takes the `Result` directly (no DB access in the component) and renders the breakdown card. `SimulatorResultComponent` builds the `Result` and passes it through.
- **No DB schema changes.** Result is recomputed on every render from `simulation.answers` + `occupant_type`.

**Tech Stack:** Rails 8, ViewComponent, Minitest, Tailwind CSS, Korean copy.

**Open questions resolved (user said "진행" on 2026-05-08):**
- Closing note style: **small gray, italic, no background** (no tinted callout).
- Always show closing note, even when triggers exist.

---

## File Structure

**Modified:**
- `app/services/eviction_guide/difficulty_assessor.rb` — return `Result` struct; add `Result` constant; preserve `to_s` for back-compat.
- `app/controllers/eviction_guide/simulations_controller.rb` — assign `result.to_s` to `simulation.difficulty_level` (back-compat path; also stash the full Result for the view to reuse).
- `app/components/eviction_guide/simulator_result_component.rb` — accept the breakdown, expose to template.
- `app/components/eviction_guide/simulator_result_component.html.erb` — render `DifficultyBreakdownComponent` between badge and "명도 경로" heading.
- `test/services/eviction_guide/difficulty_assessor_test.rb` — switch existing assertions to `.level` / `.to_s`; add new tests for `base` and `triggers` shape.
- `test/components/eviction_guide/simulator_result_component_test.rb` — assert breakdown is rendered.
- `test/fixtures/eviction_simulator_questions.yml` — add `q5_delivery_order` `step_code: "S5"` entry already exists; we'll need step fixture for trigger lookup.

**Created:**
- `app/components/eviction_guide/difficulty_breakdown_component.rb`
- `app/components/eviction_guide/difficulty_breakdown_component.html.erb`
- `test/components/eviction_guide/difficulty_breakdown_component_test.rb`

**Out of scope (explicitly NOT touched):**
- `EvictionStep`, `EvictionSimulatorQuestion`, `EvictionSimulation` models — read only.
- DB migrations — none.
- `DifficultyBadgeComponent`, `PathBuilder` — unchanged.

---

## Tidy First Discipline

This plan splits structural and behavioral changes into separate commits:

| # | Type | What |
|---|------|------|
| 1 | **structural** | Wrap `DifficultyAssessor#call` return in a `Result` struct that has only `level`. Update callers + existing tests to use `.level` / `.to_s`. **Zero behavior change.** |
| 2 | behavioral | Extend `Result` with `base` + `triggers` fields. Compute trigger metadata from questions + steps. New tests for the new shape. |
| 3 | behavioral | Create `DifficultyBreakdownComponent` (presentation only, no DB). |
| 4 | behavioral | Integrate component into `SimulatorResultComponent`. |
| 5 | manual | QA matrix (4 occupant types × triggers yes/no). |
| 6 | release | PR. |

Each behavioral task lands in its own commit. Don't fold structural changes into behavioral commits.

---

## Pre-flight

- [ ] **Confirm worktree + branch**

```bash
git rev-parse --show-toplevel
git branch --show-current
```

Expected: path ending in `.claude/worktrees/eviction-difficulty-breakdown`, branch `worktree-eviction-difficulty-breakdown`.

- [ ] **Confirm test suite is green before changes**

Run: `bin/rails test test/services/eviction_guide/difficulty_assessor_test.rb test/components/eviction_guide/simulator_result_component_test.rb`

Expected: all passing, no errors.

---

## Task 1: Structural — Wrap `DifficultyAssessor#call` return in a `Result` struct

**Files:**
- Modify: `app/services/eviction_guide/difficulty_assessor.rb`
- Modify: `test/services/eviction_guide/difficulty_assessor_test.rb`
- Modify: `app/controllers/eviction_guide/simulations_controller.rb` (one line)

**Goal:** Pure refactor. The assessor now returns `Result.new(level: <string>)`. `Result#to_s` returns `level`. All existing call sites get the same effective behavior. No new computation logic, no new fields beyond `level`.

- [ ] **Step 1.1: Update existing assessor tests to assert via `.level`**

Open `test/services/eviction_guide/difficulty_assessor_test.rb`. Each existing test currently does `assert_equal "low", result`. Change every one of them to `assert_equal "low", result.level` (or whatever string the test asserts). Also add one new assertion that `Result#to_s` returns the level.

After edits, the file should look like this (full replacement; preserve the exact level strings already asserted):

```ruby
require "test_helper"

class EvictionGuide::DifficultyAssessorTest < ActiveSupport::TestCase
  test "returns low when no branches entered" do
    answers = { "Q1" => true, "Q2" => true, "Q3" => true, "Q4" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers)
    assert_equal "low", result.level
  end

  test "returns high when B1 branch entered" do
    answers = { "Q1" => false }
    questions = { "Q1" => EvictionSimulatorQuestion.new(
      code: "Q1", step_code: "S1", no_next_code: "Q1B",
      difficulty_impact: "high"
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)
    assert_equal "high", result.level
  end

  test "returns medium for medium-impact branches" do
    answers = { "Q7" => false }
    questions = { "Q7" => EvictionSimulatorQuestion.new(
      code: "Q7", step_code: "S7", no_next_code: "Q7B",
      difficulty_impact: "medium"
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)
    assert_equal "medium", result.level
  end

  test "highest difficulty wins" do
    answers = { "Q1" => false, "Q7" => false }
    questions = {
      "Q1" => EvictionSimulatorQuestion.new(
        code: "Q1", step_code: "S1", no_next_code: "Q1B", difficulty_impact: "high"
      ),
      "Q7" => EvictionSimulatorQuestion.new(
        code: "Q7", step_code: "S7", no_next_code: "Q7B", difficulty_impact: "medium"
      )
    }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)
    assert_equal "high", result.level
  end

  test "returns base difficulty for junior_tenant with all-yes answers" do
    answers = { "JT-Q1" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers, occupant_type: "junior_tenant")
    assert_equal "low", result.level
  end

  test "returns base difficulty for senior_tenant with all-yes answers" do
    answers = { "ST-Q1" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers, occupant_type: "senior_tenant")
    assert_equal "high", result.level
  end

  test "base difficulty overridden by higher answer-based difficulty" do
    answers = { "JT-Q1" => false }
    questions = {
      "JT-Q1" => EvictionSimulatorQuestion.new(
        code: "JT-Q1", step_code: "JT-S1", no_next_code: "JT-Q1G",
        difficulty_impact: "high", occupant_type: "junior_tenant"
      )
    }
    result = EvictionGuide::DifficultyAssessor.call(
      answers, occupant_type: "junior_tenant", questions: questions
    )
    assert_equal "high", result.level
  end

  test "base difficulty wins when answer-based is lower" do
    answers = { "DO-Q1" => false }
    questions = {
      "DO-Q1" => EvictionSimulatorQuestion.new(
        code: "DO-Q1", step_code: "DO-S1", no_next_code: "DO-Q1G",
        difficulty_impact: "low", occupant_type: "debtor_owner"
      )
    }
    result = EvictionGuide::DifficultyAssessor.call(
      answers, occupant_type: "debtor_owner", questions: questions
    )
    assert_equal "medium", result.level
  end

  test "legacy behavior unchanged when occupant_type is nil" do
    answers = { "Q1" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers, occupant_type: nil)
    assert_equal "low", result.level
  end

  test "Result#to_s returns level for back-compat" do
    answers = { "Q1" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers)
    assert_equal result.level, result.to_s
    assert_equal "low", "#{result}"
  end
end
```

- [ ] **Step 1.2: Run tests — expect failures**

Run: `bin/rails test test/services/eviction_guide/difficulty_assessor_test.rb -v`

Expected: every test fails with `NoMethodError: undefined method 'level' for "low":String` (or similar). The new `to_s` test fails with the same shape.

- [ ] **Step 1.3: Implement `Result` struct in the assessor**

Open `app/services/eviction_guide/difficulty_assessor.rb`. Replace the file with:

```ruby
module EvictionGuide
  class DifficultyAssessor
    LEVELS = { "high" => 3, "medium" => 2, "low" => 1 }.freeze
    LEVEL_FROM_SCORE = LEVELS.invert.freeze

    Result = Struct.new(:level, keyword_init: true) do
      def to_s = level
    end

    def self.call(answers, occupant_type: nil, questions: nil)
      new(answers, occupant_type, questions).call
    end

    def initialize(answers, occupant_type = nil, questions = nil)
      @answers = answers || {}
      @occupant_type = occupant_type
      @questions = questions || load_questions
    end

    def call
      base_score = LEVELS[EvictionSimulation::BASE_DIFFICULTY[@occupant_type]] || 0
      max_score = base_score

      @answers.each do |code, answer|
        next if answer
        question = @questions[code]
        next unless question
        impact = question.respond_to?(:difficulty_impact) ? question.difficulty_impact : question[:difficulty_impact]
        next unless impact
        score = LEVELS[impact] || 0
        max_score = score if score > max_score
      end

      level = LEVEL_FROM_SCORE[max_score] || "low"
      Result.new(level: level)
    end

    private

    def load_questions
      EvictionSimulatorQuestion.for_occupant_type(@occupant_type).index_by(&:code)
    end
  end
end
```

- [ ] **Step 1.4: Run assessor tests — expect pass**

Run: `bin/rails test test/services/eviction_guide/difficulty_assessor_test.rb -v`

Expected: all 10 tests pass.

- [ ] **Step 1.5: Update controller call site**

Open `app/controllers/eviction_guide/simulations_controller.rb` and find this line in the `show` action:

```ruby
@simulation.difficulty_level = EvictionGuide::DifficultyAssessor.call(@simulation.answers, occupant_type: @simulation.occupant_type)
```

`@simulation.difficulty_level` is a string column on the model, but `Result#to_s` already returns the level — so Rails' string-coercion would mostly work. To be explicit (and to avoid double-call later when we extend the Result), change it to capture the Result and use `.level`:

```ruby
@difficulty_assessment = EvictionGuide::DifficultyAssessor.call(@simulation.answers, occupant_type: @simulation.occupant_type)
@simulation.difficulty_level = @difficulty_assessment.level
```

This stashes the full Result on the controller as `@difficulty_assessment` so the view can pass it straight to the breakdown component (Task 4 will use this).

- [ ] **Step 1.6: Run the broader test suite to make sure nothing else broke**

Run: `bin/rails test test/services/ test/controllers/eviction_guide/ test/components/eviction_guide/`

Expected: all pass. If any other call site of `DifficultyAssessor.call` shows up — fix it the same way (`.to_s` or `.level`). No grep is required because `to_s` covers raw string interpolation, but verify with:

```bash
grep -rn "DifficultyAssessor.call" app test
```

Every result should be either using the new `@difficulty_assessment` pattern or relying on `to_s` (string interpolation works automatically).

- [ ] **Step 1.7: Commit (structural)**

```bash
git add app/services/eviction_guide/difficulty_assessor.rb \
        app/controllers/eviction_guide/simulations_controller.rb \
        test/services/eviction_guide/difficulty_assessor_test.rb
git commit -m "refactor(eviction): wrap DifficultyAssessor return in Result struct

Pure structural change. Result has only :level for now; to_s returns
level so any existing string interpolation keeps working. Behavioral
fields (base, triggers) follow in a separate commit."
```

---

## Task 2: Behavioral — Add `base` and `triggers` to `Result`

**Files:**
- Modify: `app/services/eviction_guide/difficulty_assessor.rb`
- Modify: `test/services/eviction_guide/difficulty_assessor_test.rb`
- Modify: `test/fixtures/eviction_steps.yml` (add fixtures the new tests need, only if missing)

**Goal:** Extend `Result` with `base: { level:, occupant_type: }` and `triggers: [{ code, step_code, step_name, impact, help_text }, ...]`. Triggers are derived only from "no" answers whose question declares `difficulty_impact`. Step name is looked up from `EvictionStep` by `step_code`.

- [ ] **Step 2.1: Verify fixture for step `S5` exists**

Run: `grep -n 's5_delivery_order' test/fixtures/eviction_steps.yml`

Expected: a hit with `code: "S5"` and `name: "인도명령 + 점유이전금지가처분 동시 신청"`. If missing, add this fixture entry to `test/fixtures/eviction_steps.yml`:

```yaml
s5_delivery_order:
  code: "S5"
  step_type: 0
  name: "인도명령 + 점유이전금지가처분 동시 신청"
  description: "잔금 납부일 당일 세트로 신청하는 것이 실무 정석"
  completion_condition: "두 신청 모두 접수"
  failure_condition: "6개월 기한 도과"
  required_documents: '["잔금완납증명서", "인도명령 신청서", "가처분 신청서"]'
  estimated_duration: "결정: 1주일 이내"
  legal_basis: '[{"title": "민사집행법 제136조", "summary": "인도명령 신청 근거", "url": "https://law.go.kr"}]'
  position: 5
  next_step_code: "S6"
  branch_codes: '["B6"]'
```

(You already saw this exact entry in the existing fixture. Skip this step if grep finds it.)

- [ ] **Step 2.2: Write failing tests for `base` and `triggers`**

Append these tests to `test/services/eviction_guide/difficulty_assessor_test.rb` (just before the final `end`):

```ruby
  test "base reports level and occupant_type" do
    result = EvictionGuide::DifficultyAssessor.call({}, occupant_type: "debtor_owner")
    assert_equal "medium", result.base[:level]
    assert_equal "debtor_owner", result.base[:occupant_type]
  end

  test "base level is nil when occupant_type is nil" do
    result = EvictionGuide::DifficultyAssessor.call({})
    assert_nil result.base[:level]
    assert_nil result.base[:occupant_type]
  end

  test "triggers is empty when no no-answer escalates difficulty" do
    answers = { "Q1" => true, "Q2" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers, occupant_type: "debtor_owner")
    assert_empty result.triggers
  end

  test "triggers includes code, step_code, step_name, impact, help_text" do
    answers = { "Q5" => false }
    questions = { "Q5" => EvictionSimulatorQuestion.new(
      code: "Q5", step_code: "S5", no_next_code: "Q5B",
      difficulty_impact: "high",
      help_text: "잔금 납부일 당일 세트로 신청하는 것이 실무 정석입니다."
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)

    assert_equal 1, result.triggers.size
    trigger = result.triggers.first
    assert_equal "Q5", trigger[:code]
    assert_equal "S5", trigger[:step_code]
    assert_equal "인도명령 + 점유이전금지가처분 동시 신청", trigger[:step_name]
    assert_equal "high", trigger[:impact]
    assert_equal "잔금 납부일 당일 세트로 신청하는 것이 실무 정석입니다.", trigger[:help_text]
  end

  test "triggers preserves answer order" do
    answers = { "Q5" => false, "Q14G" => false }
    questions = {
      "Q5" => EvictionSimulatorQuestion.new(
        code: "Q5", step_code: "S5", no_next_code: "Q5B",
        difficulty_impact: "high", help_text: "high impact help"
      ),
      "Q14G" => EvictionSimulatorQuestion.new(
        code: "Q14G", step_code: "S14", no_next_code: "Q14R",
        difficulty_impact: "medium", help_text: "medium impact help"
      )
    }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)

    assert_equal %w[Q5 Q14G], result.triggers.map { |t| t[:code] }
  end

  test "triggers uses step_code as step_name fallback when step row is missing" do
    answers = { "QX" => false }
    questions = { "QX" => EvictionSimulatorQuestion.new(
      code: "QX", step_code: "S-NONEXISTENT", no_next_code: "QXB",
      difficulty_impact: "medium", help_text: "no step row"
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)

    trigger = result.triggers.first
    assert_equal "S-NONEXISTENT", trigger[:step_code]
    assert_equal "S-NONEXISTENT", trigger[:step_name]
  end
```

- [ ] **Step 2.3: Run tests — expect failures**

Run: `bin/rails test test/services/eviction_guide/difficulty_assessor_test.rb -v`

Expected: the 6 new tests fail (the original 10 still pass). Failures should be `NoMethodError: undefined method 'base'` / `'triggers'` on the Result.

- [ ] **Step 2.4: Implement `base` + `triggers` in the assessor**

Replace `app/services/eviction_guide/difficulty_assessor.rb` with:

```ruby
module EvictionGuide
  class DifficultyAssessor
    LEVELS = { "high" => 3, "medium" => 2, "low" => 1 }.freeze
    LEVEL_FROM_SCORE = LEVELS.invert.freeze

    Result = Struct.new(:level, :base, :triggers, keyword_init: true) do
      def to_s = level
    end

    def self.call(answers, occupant_type: nil, questions: nil)
      new(answers, occupant_type, questions).call
    end

    def initialize(answers, occupant_type = nil, questions = nil)
      @answers = answers || {}
      @occupant_type = occupant_type
      @questions = questions || load_questions
    end

    def call
      base_level = EvictionSimulation::BASE_DIFFICULTY[@occupant_type]
      base_score = LEVELS[base_level] || 0
      max_score = base_score

      triggers = []
      @answers.each do |code, answer|
        next if answer
        question = @questions[code]
        next unless question
        impact = question.respond_to?(:difficulty_impact) ? question.difficulty_impact : question[:difficulty_impact]
        next unless impact

        score = LEVELS[impact] || 0
        max_score = score if score > max_score

        triggers << build_trigger(question, impact)
      end

      Result.new(
        level: LEVEL_FROM_SCORE[max_score] || "low",
        base: { level: base_level, occupant_type: @occupant_type },
        triggers: triggers
      )
    end

    private

    def build_trigger(question, impact)
      step_code = question_value(question, :step_code)
      {
        code: question_value(question, :code),
        step_code: step_code,
        step_name: step_name_for(step_code),
        impact: impact,
        help_text: question_value(question, :help_text)
      }
    end

    def question_value(question, key)
      question.respond_to?(key) ? question.public_send(key) : question[key]
    end

    def step_name_for(step_code)
      steps[step_code]&.name || step_code
    end

    def steps
      @steps ||= EvictionStep.where(code: trigger_step_codes).index_by(&:code)
    end

    def trigger_step_codes
      @answers.filter_map do |code, answer|
        next if answer
        question = @questions[code]
        next unless question
        impact = question.respond_to?(:difficulty_impact) ? question.difficulty_impact : question[:difficulty_impact]
        next unless impact
        question_value(question, :step_code)
      end.uniq
    end

    def load_questions
      EvictionSimulatorQuestion.for_occupant_type(@occupant_type).index_by(&:code)
    end
  end
end
```

- [ ] **Step 2.5: Run tests — expect pass**

Run: `bin/rails test test/services/eviction_guide/difficulty_assessor_test.rb -v`

Expected: all 16 tests pass (10 original + 6 new).

- [ ] **Step 2.6: Commit (behavioral)**

```bash
git add app/services/eviction_guide/difficulty_assessor.rb \
        test/services/eviction_guide/difficulty_assessor_test.rb
git commit -m "feat(eviction): expose base difficulty and triggers in Result

Result now carries:
  base: { level:, occupant_type: }
  triggers: [{ code, step_code, step_name, impact, help_text }]

Step name comes from EvictionStep lookup with step_code fallback when
no step row matches. Triggers preserve answer order. No DB writes."
```

---

## Task 3: Behavioral — `DifficultyBreakdownComponent` (presentation only)

**Files:**
- Create: `app/components/eviction_guide/difficulty_breakdown_component.rb`
- Create: `app/components/eviction_guide/difficulty_breakdown_component.html.erb`
- Create: `test/components/eviction_guide/difficulty_breakdown_component_test.rb`

**Goal:** A pure-presentation ViewComponent that takes a `DifficultyAssessor::Result` directly and renders the breakdown card. No DB access. No assessor invocation. Easy to test with hand-built Result instances.

- [ ] **Step 3.1: Write failing component test**

Create `test/components/eviction_guide/difficulty_breakdown_component_test.rb`:

```ruby
require "test_helper"

module EvictionGuide
  class DifficultyBreakdownComponentTest < ViewComponent::TestCase
    Result = EvictionGuide::DifficultyAssessor::Result

    def build_breakdown(level: "low", base_level: "low", occupant_type: "junior_tenant", triggers: [])
      Result.new(
        level: level,
        base: { level: base_level, occupant_type: occupant_type },
        triggers: triggers
      )
    end

    test "renders junior_tenant base reason" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(occupant_type: "junior_tenant")
      ))

      assert_text "기본 난이도"
      assert_text "후순위 임차인"
      assert_text "배당으로 보증금을 회수"
    end

    test "renders debtor_owner base reason" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(occupant_type: "debtor_owner", base_level: "medium")
      ))

      assert_text "채무자"
      assert_text "1~3개월 소요"
    end

    test "renders senior_tenant base reason" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(occupant_type: "senior_tenant", base_level: "high", level: "high")
      ))

      assert_text "선순위 임차인"
      assert_text "보증금 인수 부담"
    end

    test "renders illegal_occupant base reason" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(occupant_type: "illegal_occupant", base_level: "high", level: "high")
      ))

      assert_text "불법 점유자"
      assert_text "명도소송"
    end

    test "renders fallback when occupant_type is nil" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(occupant_type: nil, base_level: nil)
      ))

      assert_text "점유자 유형이 지정되지 않아"
    end

    test "shows '추가 위험 요인 없음' when triggers empty" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(triggers: [])
      ))

      assert_text "추가 위험 요인"
      assert_text "없음"
      assert_text "기본 난이도가 그대로 유지"
    end

    test "lists triggers with step name, impact, help_text when present" do
      triggers = [
        { code: "Q5", step_code: "S5",
          step_name: "인도명령 + 점유이전금지가처분 동시 신청",
          impact: "high",
          help_text: "잔금 납부일 당일 세트로 신청하는 것이 실무 정석입니다." }
      ]
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(level: "high", triggers: triggers)
      ))

      assert_text "S5 인도명령 + 점유이전금지가처분 동시 신청"
      assert_text "+높음"
      assert_text "잔금 납부일 당일"
    end

    test "trigger header shows count and highest impact" do
      triggers = [
        { code: "Q5", step_code: "S5", step_name: "인도명령", impact: "high", help_text: "..." },
        { code: "Q14", step_code: "S14", step_name: "관리비", impact: "medium", help_text: "..." }
      ]
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(level: "high", triggers: triggers)
      ))

      assert_text "추가 위험 요인"
      assert_text "2건"
      assert_text "영향도: 높음"
    end

    test "does NOT show question codes (Q5G etc) only step labels" do
      triggers = [
        { code: "Q5G", step_code: "S5", step_name: "인도명령 신청",
          impact: "high", help_text: "도움말" }
      ]
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(level: "high", triggers: triggers)
      ))

      refute_text "Q5G"
    end

    test "renders closing rule note even when triggers exist" do
      triggers = [
        { code: "Q5", step_code: "S5", step_name: "인도명령",
          impact: "high", help_text: "도움말" }
      ]
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(level: "high", triggers: triggers)
      ))

      assert_text "기본 난이도와 추가 위험 중 더 높은 쪽이 최종 난이도"
    end

    test "renders closing rule note when triggers empty" do
      render_inline(DifficultyBreakdownComponent.new(
        breakdown: build_breakdown(triggers: [])
      ))

      assert_text "기본 난이도와 추가 위험 중 더 높은 쪽이 최종 난이도"
    end
  end
end
```

- [ ] **Step 3.2: Run tests — expect "uninitialized constant" failure**

Run: `bin/rails test test/components/eviction_guide/difficulty_breakdown_component_test.rb -v`

Expected: failure on `EvictionGuide::DifficultyBreakdownComponent` (uninitialized constant) for all 11 tests.

- [ ] **Step 3.3: Implement the component class**

Create `app/components/eviction_guide/difficulty_breakdown_component.rb`:

```ruby
module EvictionGuide
  class DifficultyBreakdownComponent < ViewComponent::Base
    BASE_REASONS = {
      "junior_tenant" => {
        label: "후순위 임차인",
        reason: "배당으로 보증금을 회수하므로 명도확인서 협상이 가능하고 인도명령 절차도 표준입니다."
      },
      "debtor_owner" => {
        label: "채무자 본인",
        reason: "인도명령 대상이 명확하지만, 자진 퇴거 협상과 강제집행 단계가 남아 있어 1~3개월 소요됩니다."
      },
      "senior_tenant" => {
        label: "선순위 임차인",
        reason: "보증금 인수 부담이 있고, 협상이 결렬되면 명도소송으로 6~12개월 추가됩니다."
      },
      "illegal_occupant" => {
        label: "불법 점유자",
        reason: "인도명령이 불가능해 명도소송(6~12개월)으로만 진행 가능합니다."
      }
    }.freeze

    LEVEL_LABELS = { "high" => "높음", "medium" => "중간", "low" => "낮음" }.freeze
    LEVEL_RANK = { "high" => 3, "medium" => 2, "low" => 1 }.freeze

    IMPACT_BADGE_CLASSES = {
      "high"   => "bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300",
      "medium" => "bg-yellow-100 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-300",
      "low"    => "bg-green-100 text-green-800 dark:bg-green-900/30 dark:text-green-300"
    }.freeze

    def initialize(breakdown:)
      @breakdown = breakdown
    end

    private

    def base_label
      info = BASE_REASONS[@breakdown.base[:occupant_type]]
      info ? info[:label] : nil
    end

    def base_reason
      info = BASE_REASONS[@breakdown.base[:occupant_type]]
      info ? info[:reason] : "점유자 유형이 지정되지 않아 평균적인 난이도로 평가되었습니다."
    end

    def base_level_label
      LEVEL_LABELS[@breakdown.base[:level]] || "—"
    end

    def triggers
      @breakdown.triggers
    end

    def triggers_present?
      triggers.any?
    end

    def triggers_count
      triggers.size
    end

    def highest_trigger_impact_label
      ranked = triggers.map { |t| t[:impact] }.max_by { |i| LEVEL_RANK[i] || 0 }
      LEVEL_LABELS[ranked] || "—"
    end

    def impact_badge_classes(impact)
      IMPACT_BADGE_CLASSES[impact] || IMPACT_BADGE_CLASSES["medium"]
    end

    def impact_label(impact)
      LEVEL_LABELS[impact] || impact.to_s
    end
  end
end
```

- [ ] **Step 3.4: Implement the component template**

Create `app/components/eviction_guide/difficulty_breakdown_component.html.erb`:

```erb
<div class="bg-slate-50 dark:bg-slate-800 rounded-lg p-4 mb-6 space-y-4">
  <%# 기본 난이도 %>
  <div>
    <div class="text-sm font-semibold text-slate-700 dark:text-slate-200">
      기본 난이도
      <% if base_label %>
        <span class="text-slate-500 dark:text-slate-400 font-normal">ㆍ <%= base_label %> → <%= base_level_label %></span>
      <% end %>
    </div>
    <p class="text-sm text-slate-600 dark:text-slate-300 mt-1 leading-relaxed">
      <%= base_reason %>
    </p>
  </div>

  <%# 추가 위험 요인 %>
  <div>
    <div class="text-sm font-semibold text-slate-700 dark:text-slate-200">
      추가 위험 요인
      <% if triggers_present? %>
        <span class="text-slate-500 dark:text-slate-400 font-normal">
          ㆍ <%= triggers_count %>건 (영향도: <%= highest_trigger_impact_label %>)
        </span>
      <% else %>
        <span class="text-slate-500 dark:text-slate-400 font-normal">ㆍ 없음</span>
      <% end %>
    </div>

    <% if triggers_present? %>
      <ul class="mt-2 space-y-3">
        <% triggers.each do |trigger| %>
          <li>
            <div class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-200">
              <span class="font-medium">
                <%= trigger[:step_code] %> <%= trigger[:step_name] %>
              </span>
              <span class="inline-flex items-center rounded-full px-2 py-0.5 text-xs font-semibold <%= impact_badge_classes(trigger[:impact]) %>">
                +<%= impact_label(trigger[:impact]) %>
              </span>
            </div>
            <p class="text-sm text-slate-600 dark:text-slate-300 mt-1 ml-2 leading-relaxed">
              <%= trigger[:help_text] %>
            </p>
          </li>
        <% end %>
      </ul>
    <% else %>
      <p class="text-sm text-slate-600 dark:text-slate-300 mt-1 leading-relaxed">
        답변상 새로 발생한 리스크가 없어 기본 난이도가 그대로 유지됩니다.
      </p>
    <% end %>
  </div>

  <%# Closing rule note — 작은 회색, 배경 없음 %>
  <p class="text-xs italic text-slate-500 dark:text-slate-400 leading-relaxed">
    ⓘ 기본 난이도와 추가 위험 중 더 높은 쪽이 최종 난이도가 됩니다.
  </p>
</div>
```

- [ ] **Step 3.5: Run component tests — expect pass**

Run: `bin/rails test test/components/eviction_guide/difficulty_breakdown_component_test.rb -v`

Expected: all 11 tests pass.

- [ ] **Step 3.6: Commit**

```bash
git add app/components/eviction_guide/difficulty_breakdown_component.rb \
        app/components/eviction_guide/difficulty_breakdown_component.html.erb \
        test/components/eviction_guide/difficulty_breakdown_component_test.rb
git commit -m "feat(eviction): add DifficultyBreakdownComponent

Pure presentation component that takes a DifficultyAssessor::Result
directly. Renders base difficulty (with per-occupant-type reason copy),
triggers list (step name + impact badge + help_text), and a closing
note explaining the max() rule. Korean copy throughout."
```

---

## Task 4: Behavioral — Integrate breakdown into `SimulatorResultComponent`

**Files:**
- Modify: `app/components/eviction_guide/simulator_result_component.rb`
- Modify: `app/components/eviction_guide/simulator_result_component.html.erb`
- Modify: `test/components/eviction_guide/simulator_result_component_test.rb`

**Goal:** Build the Result inside `SimulatorResultComponent` (so the existing controller-level `@simulation.difficulty_level` flow stays unchanged for back-compat) and render the new component between the badge and the "명도 경로" heading.

- [ ] **Step 4.1: Write failing integration test**

Append to `test/components/eviction_guide/simulator_result_component_test.rb` (just before the final `end`):

```ruby
    test "renders difficulty breakdown card after the difficulty badge" do
      simulation = EvictionSimulation.new(
        occupant_type: "debtor_owner",
        difficulty_level: "medium",
        answers: { "Q1" => true },
        result_path: []
      )

      render_inline(SimulatorResultComponent.new(simulation: simulation))

      assert_text "기본 난이도"
      assert_text "채무자"
      assert_text "추가 위험 요인"
      assert_text "기본 난이도와 추가 위험 중 더 높은 쪽이 최종 난이도"
    end
```

- [ ] **Step 4.2: Run test — expect failure**

Run: `bin/rails test test/components/eviction_guide/simulator_result_component_test.rb -v`

Expected: the new test fails with "expected to find text '기본 난이도'" or similar. Other 3 tests still pass.

- [ ] **Step 4.3: Build the breakdown inside `SimulatorResultComponent`**

Replace `app/components/eviction_guide/simulator_result_component.rb` with:

```ruby
module EvictionGuide
  class SimulatorResultComponent < ViewComponent::Base
    def initialize(simulation:)
      @simulation = simulation
      @path = simulation.result_path || []
      @breakdown = EvictionGuide::DifficultyAssessor.call(
        simulation.answers,
        occupant_type: simulation.occupant_type
      )
    end

    private

    attr_reader :breakdown

    def total_steps
      @path.size
    end

    def branch_count
      @path.count { |e| e["status"] == "branch" }
    end

    STATUS_BADGE = {
      "completed" => { label: "완료", classes: "bg-green-600 text-white" },
      "needed" => { label: "필요", classes: "bg-blue-600 text-white" },
      "branch" => { label: "분기", classes: "bg-red-600 text-white" }
    }.freeze

    def status_badge(status)
      STATUS_BADGE[status] || STATUS_BADGE["needed"]
    end

    def occupant_type_label
      @simulation.occupant_type_label
    end
  end
end
```

- [ ] **Step 4.4: Render the breakdown component in the template**

Open `app/components/eviction_guide/simulator_result_component.html.erb`. Find the existing difficulty badge block:

```erb
  <%# Difficulty badge %>
  <div class="text-center mb-6">
    <%= render EvictionGuide::DifficultyBadgeComponent.new(level: @simulation.difficulty_level || "medium") %>
  </div>

  <%# Path visualization %>
  <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-4">명도 경로</h3>
```

Replace it with:

```erb
  <%# Difficulty badge %>
  <div class="text-center mb-6">
    <%= render EvictionGuide::DifficultyBadgeComponent.new(level: @simulation.difficulty_level || "medium") %>
  </div>

  <%# Difficulty breakdown %>
  <%= render EvictionGuide::DifficultyBreakdownComponent.new(breakdown: breakdown) %>

  <%# Path visualization %>
  <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-4">명도 경로</h3>
```

(Note: `breakdown` is the private accessor on `SimulatorResultComponent`. Templates have access to private methods of their component class.)

- [ ] **Step 4.5: Run tests — expect pass**

Run: `bin/rails test test/components/eviction_guide/simulator_result_component_test.rb -v`

Expected: all 4 tests pass (3 original + 1 new). Note that the existing `EvictionSimulation.new(...)` test setups already work — the Assessor only queries DB if `questions` and `steps` look up rows, but with bare `EvictionSimulation.new` and `answers: nil` or simple yes-only answers, it should be safe. If a test fails because the assessor hits the DB and there are no matching rows, that's still fine: an empty `triggers` list just means "no escalations," and the test will still pass.

- [ ] **Step 4.6: Run the full eviction test suite as a regression check**

Run: `bin/rails test test/services/eviction_guide/ test/components/eviction_guide/ test/controllers/eviction_guide/ test/models/eviction_simulation_test.rb`

Expected: all passing.

- [ ] **Step 4.7: Commit**

```bash
git add app/components/eviction_guide/simulator_result_component.rb \
        app/components/eviction_guide/simulator_result_component.html.erb \
        test/components/eviction_guide/simulator_result_component_test.rb
git commit -m "feat(eviction): render difficulty breakdown card under the badge

SimulatorResultComponent now builds a DifficultyAssessor::Result and
passes it to DifficultyBreakdownComponent, inserted between the
difficulty badge and the '명도 경로' heading."
```

---

## Task 5: Manual QA Matrix

**Goal:** Visually verify the breakdown across the four occupant types and the trigger / no-trigger axis.

- [ ] **Step 5.1: Boot the dev server**

Run: `bin/dev` (in a separate terminal). Wait for server to be ready.

- [ ] **Step 5.2: Walk the matrix**

For each combination, run a fresh simulation, take a screenshot of the result page, and confirm the breakdown card displays correctly:

| # | occupant_type | Trigger | Expected breakdown |
|---|---|---|---|
| 1 | junior_tenant | none (all yes) | 기본: 후순위 임차인 → 낮음, 추가 위험 없음 |
| 2 | junior_tenant | one high (e.g. Q1G no) | 기본: 후순위 임차인 → 낮음, 추가 위험 1건 (높음) |
| 3 | debtor_owner | none | 기본: 채무자 본인 → 중간, 추가 위험 없음 |
| 4 | debtor_owner | one medium | 기본: 채무자 본인 → 중간, 추가 위험 1건 (중간) |
| 5 | senior_tenant | none | 기본: 선순위 임차인 → 높음, 추가 위험 없음 |
| 6 | senior_tenant | one high | 기본: 선순위 임차인 → 높음, 추가 위험 1건 (높음) |
| 7 | illegal_occupant | none | 기본: 불법 점유자 → 높음, 추가 위험 없음 |
| 8 | illegal_occupant | two (high + medium) | 기본: 불법 점유자 → 높음, 추가 위험 2건 (높음) |

For each cell, confirm:
- Closing note "ⓘ 기본 난이도와 추가 위험 중 더 높은 쪽이 최종 난이도가 됩니다." is visible.
- Question codes (e.g. `Q5G`) are NOT visible — only step codes + step names.
- Impact badge color matches level (red/yellow/green for high/medium/low).
- Help text is the same Korean string as the seed JSON.
- Print preview (Ctrl+P) shows the breakdown card.

- [ ] **Step 5.3: Dark mode spot check**

Toggle dark mode (if supported in the dev shell) and confirm contrast on the breakdown card and impact badges is readable.

- [ ] **Step 5.4: Document QA result**

If anything fails, file the bug back into Tasks 3 or 4 and iterate. If everything passes, save 1-2 representative screenshots in the worktree (e.g. `tmp/qa-screenshots/` — gitignored, just for the PR description).

---

## Task 6: PR

- [ ] **Step 6.1: Final test sweep + linter**

Run: `bin/rails test`

Expected: all passing.

Run: `bundle exec rubocop app/services/eviction_guide/difficulty_assessor.rb app/components/eviction_guide/difficulty_breakdown_component.rb app/components/eviction_guide/simulator_result_component.rb` (if rubocop is configured).

Expected: no offenses.

- [ ] **Step 6.2: Create PR via push2gh**

Invoke the `push2gh` skill. The skill auto-applies the `automerge` label (per project memory).

- [ ] **Step 6.3: Telegram milestone update**

Send a milestone message via Telegram once PR is merged.

---

## Self-Review (already performed before save)

- **Spec coverage:** Every section of the design spec maps to a task. UI mock → Tasks 3 + 4. Display rules → Task 3. Data layer Result struct → Tasks 1 + 2. Component → Task 3. Tests TDD section → spread across Tasks 1, 2, 3, 4. Risks (unknown occupant_type, missing question, nil answers) → covered by Step 2.4 (graceful skip) and Step 3.3 (BASE_REASONS fallback).
- **Placeholder scan:** No "TBD" / "implement later" / "similar to Task N" — all code blocks are complete.
- **Type consistency:** `Result` is `Struct.new(:level, :base, :triggers, keyword_init: true)`; the same field names are used in tests and component; `triggers` is always an array of hashes with the same five keys.
- **Tidy First:** Task 1 is purely structural (wrap `level` in `Result`, add `to_s`). Task 2 is the first behavioral commit (new fields). Tasks 3 + 4 are behavioral. Each commit is independent and testable in isolation.

---

## Execution Handoff

Plan saved to `docs/superpowers/plans/2026-05-08-eviction-difficulty-breakdown.md`.

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach?
