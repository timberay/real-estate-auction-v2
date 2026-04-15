# Occupant-Type Branching Implementation Plan (Phase 1: junior_tenant)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add occupant-type-based branching to the eviction simulator so that each occupant type gets a completely independent step sequence, starting with the `junior_tenant` pilot.

**Architecture:** Add `occupant_type` column to 3 tables (EvictionSimulation, EvictionStep, EvictionSimulatorQuestion). Extend PathBuilder and DifficultyAssessor to filter by type. Add a type selection screen for standalone simulations and an occupant type selector on the F02 prefill screen. Seed `junior_tenant`-specific steps and questions.

**Tech Stack:** Rails, Minitest, ViewComponent, TailwindCSS, Turbo Frames, JSON seed data, SQLite

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `db/migrate/YYYYMMDD_add_occupant_type_to_eviction_tables.rb` | Migration: add `occupant_type` string column to 3 tables |
| Modify | `app/models/eviction_simulation.rb` | Add `OCCUPANT_TYPES` constant, helper methods |
| Modify | `app/models/eviction_step.rb` | Add `for_occupant_type` scope |
| Modify | `app/models/eviction_simulator_question.rb` | Add `for_occupant_type` scope |
| Modify | `app/services/eviction_guide/path_builder.rb` | Accept `occupant_type:`, filter steps/questions |
| Modify | `app/services/eviction_guide/difficulty_assessor.rb` | Accept `occupant_type:`, base difficulty per type |
| Modify | `app/services/eviction_guide/f02_data_extractor.rb` | Normalize `occupant_type` to valid enum |
| Modify | `app/controllers/eviction_guide/simulations_controller.rb` | Type param handling, new `select_type` action |
| Modify | `app/controllers/eviction_guide/simulator_controller.rb` | Pass occupant_type badge to question view |
| Create | `app/components/eviction_guide/occupant_type_selector_component.rb` | Type selection card UI |
| Create | `app/components/eviction_guide/occupant_type_selector_component.html.erb` | Type selection card template |
| Create | `app/views/eviction_guide/simulator/select_type.html.erb` | Type selection page |
| Modify | `app/components/eviction_guide/f02_prefill_component.rb` | Add occupant type selector field |
| Modify | `app/components/eviction_guide/f02_prefill_component.html.erb` | Render occupant type selector |
| Modify | `app/components/eviction_guide/simulator_question_component.rb` | Progress uses main steps only |
| Modify | `app/components/eviction_guide/simulator_question_component.html.erb` | Show occupant type badge |
| Modify | `app/components/eviction_guide/simulator_result_component.rb` | Show type summary + badge |
| Modify | `app/components/eviction_guide/simulator_result_component.html.erb` | Render type summary |
| Modify | `config/routes.rb` | Add `select_type` route |
| Modify | `db/seeds/eviction_steps.json` | Add JT-S1~JT-S6, JT-B1, JT-B2 with `occupant_type` field |
| Modify | `db/seeds/eviction_simulator_questions.json` | Add JT-Q1~JT-Q6+ with `occupant_type` field |
| Modify | `db/seeds.rb` | Seed `occupant_type` field |
| Modify | `test/fixtures/eviction_simulations.yml` | Add typed fixture |
| Modify | `test/fixtures/eviction_steps.yml` | Add JT-prefixed fixtures |
| Modify | `test/fixtures/eviction_simulator_questions.yml` | Add JT-prefixed fixtures |

---

### Task 1: Migration — Add `occupant_type` to 3 Tables

**Files:**
- Create: `db/migrate/YYYYMMDD_add_occupant_type_to_eviction_tables.rb`
- Test: `bin/rails db:migrate` + schema verification

- [ ] **Step 1: Generate migration**

Run: `bin/rails generate migration AddOccupantTypeToEvictionTables`

- [ ] **Step 2: Write migration**

```ruby
class AddOccupantTypeToEvictionTables < ActiveRecord::Migration[8.0]
  def change
    add_column :eviction_simulations, :occupant_type, :string
    add_column :eviction_steps, :occupant_type, :string
    add_column :eviction_simulator_questions, :occupant_type, :string

    add_index :eviction_steps, :occupant_type
    add_index :eviction_simulator_questions, :occupant_type
  end
end
```

- [ ] **Step 3: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration succeeds, `db/schema.rb` shows new columns on all 3 tables.

- [ ] **Step 4: Verify schema**

Confirm `db/schema.rb` contains:
- `t.string "occupant_type"` in `eviction_simulations`
- `t.string "occupant_type"` in `eviction_steps` with index
- `t.string "occupant_type"` in `eviction_simulator_questions` with index

- [ ] **Step 5: Commit**

```bash
git add db/migrate/*_add_occupant_type_to_eviction_tables.rb db/schema.rb
git commit -m "db: add occupant_type column to eviction_simulations, steps, and questions"
```

---

### Task 2: Model — EvictionSimulation Occupant Type Support

**Files:**
- Modify: `app/models/eviction_simulation.rb`
- Test: `test/models/eviction_simulation_test.rb`
- Modify: `test/fixtures/eviction_simulations.yml`

- [ ] **Step 1: Add typed fixture**

Add to `test/fixtures/eviction_simulations.yml`:

```yaml
junior_tenant_sim:
  session_id: "jt_session_123"
  occupant_type: "junior_tenant"
  answers: '{}'
  result_path: '[]'
  difficulty_level: ~
  completed: false
```

- [ ] **Step 2: Write failing tests**

Add to `test/models/eviction_simulation_test.rb`:

```ruby
test "OCCUPANT_TYPES contains the 4 valid types" do
  assert_equal %w[junior_tenant senior_tenant debtor_owner illegal_occupant],
               EvictionSimulation::OCCUPANT_TYPES
end

test "valid_occupant_type? returns true for valid types" do
  sim = EvictionSimulation.new(occupant_type: "junior_tenant")
  assert sim.valid_occupant_type?
end

test "valid_occupant_type? returns false for invalid types" do
  sim = EvictionSimulation.new(occupant_type: "unknown_type")
  assert_not sim.valid_occupant_type?
end

test "valid_occupant_type? returns true for nil (legacy)" do
  sim = EvictionSimulation.new(occupant_type: nil)
  assert sim.valid_occupant_type?
end

test "occupant_type_label returns Korean label" do
  sim = EvictionSimulation.new(occupant_type: "junior_tenant")
  assert_equal "후순위 임차인 (배당 수령)", sim.occupant_type_label
end

test "occupant_type_label returns nil for legacy simulation" do
  sim = EvictionSimulation.new(occupant_type: nil)
  assert_nil sim.occupant_type_label
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/models/eviction_simulation_test.rb`
Expected: FAIL — `OCCUPANT_TYPES` not defined, `valid_occupant_type?` not defined, `occupant_type_label` not defined.

- [ ] **Step 4: Implement model changes**

Replace the full content of `app/models/eviction_simulation.rb`:

```ruby
class EvictionSimulation < ApplicationRecord
  OCCUPANT_TYPES = %w[junior_tenant senior_tenant debtor_owner illegal_occupant].freeze

  OCCUPANT_TYPE_LABELS = {
    "junior_tenant" => "후순위 임차인 (배당 수령)",
    "senior_tenant" => "선순위 임차인 (대항력 有)",
    "debtor_owner" => "채무자 (소유자) 본인",
    "illegal_occupant" => "불법 점유자 / 제3자"
  }.freeze

  BASE_DIFFICULTY = {
    "junior_tenant" => "low",
    "senior_tenant" => "high",
    "debtor_owner" => "medium",
    "illegal_occupant" => "high"
  }.freeze

  belongs_to :property, optional: true

  validates :property_id, uniqueness: true, allow_nil: true

  scope :stale, -> {
    where(property_id: nil)
      .where(created_at: ...24.hours.ago)
  }

  def record_answer(question_code, value)
    self.answers ||= {}
    self.answers[question_code] = value
  end

  def answer_for(question_code)
    answers&.dig(question_code)
  end

  def property_linked?
    property_id.present?
  end

  def valid_occupant_type?
    occupant_type.nil? || OCCUPANT_TYPES.include?(occupant_type)
  end

  def occupant_type_label
    OCCUPANT_TYPE_LABELS[occupant_type]
  end

  def base_difficulty
    BASE_DIFFICULTY[occupant_type]
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/models/eviction_simulation_test.rb`
Expected: All tests PASS.

- [ ] **Step 6: Commit**

```bash
git add app/models/eviction_simulation.rb test/models/eviction_simulation_test.rb test/fixtures/eviction_simulations.yml
git commit -m "feat(model): add occupant type support to EvictionSimulation"
```

---

### Task 3: Model Scopes — EvictionStep and EvictionSimulatorQuestion

**Files:**
- Modify: `app/models/eviction_step.rb`
- Modify: `app/models/eviction_simulator_question.rb`
- Test: `test/models/eviction_step_test.rb`
- Test: `test/models/eviction_simulator_question_test.rb`
- Modify: `test/fixtures/eviction_steps.yml`
- Modify: `test/fixtures/eviction_simulator_questions.yml`

- [ ] **Step 1: Add JT-prefixed fixtures**

Add to `test/fixtures/eviction_steps.yml`:

```yaml
jt_s1_dividend_check:
  code: "JT-S1"
  step_type: 0
  name: "배당표 확인"
  description: "배당 수령 여부와 금액을 확인"
  completion_condition: "배당 수령 확인 완료"
  failure_condition: "배당 미수령"
  required_documents: '["배당표"]'
  estimated_duration: "1~2주"
  position: 1
  next_step_code: "JT-S2"
  branch_codes: '["JT-B1"]'
  occupant_type: "junior_tenant"

jt_b1_no_dividend:
  code: "JT-B1"
  step_type: 1
  name: "배당 미수령"
  description: "임차인이 배당을 수령하지 않은 경우"
  trigger_step_code: "JT-S1"
  problem_summary: "임차인 배당 미수령으로 퇴거 의무 불명확"
  root_cause: "배당요구 미신청 또는 배당금 미수령"
  action_steps: '["배당요구 여부 재확인", "임차인과 직접 협의"]'
  return_step_code: "JT-S2"
  position: 101
  estimated_duration: "2~4주"
  occupant_type: "junior_tenant"
```

Add to `test/fixtures/eviction_simulator_questions.yml`:

```yaml
jt_q1_dividend:
  code: "JT-Q1"
  phase: 0
  step_code: "JT-S1"
  question: "배당표에서 임차인이 배당을 수령했나요?"
  help_text: "배당 수령 여부에 따라 협상 전략이 달라집니다."
  yes_next_code: "JT-Q2"
  no_next_code: "JT-Q1G"
  occupant_type: "junior_tenant"
```

- [ ] **Step 2: Write failing tests for EvictionStep scope**

Add to `test/models/eviction_step_test.rb`:

```ruby
test "for_occupant_type filters by occupant_type" do
  results = EvictionStep.for_occupant_type("junior_tenant")
  assert results.all? { |s| s.occupant_type == "junior_tenant" }
  assert_not results.any? { |s| s.occupant_type.nil? }
end

test "for_occupant_type with nil returns legacy steps" do
  results = EvictionStep.for_occupant_type(nil)
  assert results.all? { |s| s.occupant_type.nil? }
end
```

- [ ] **Step 3: Write failing tests for EvictionSimulatorQuestion scope**

Add to `test/models/eviction_simulator_question_test.rb`:

```ruby
test "for_occupant_type filters by occupant_type" do
  results = EvictionSimulatorQuestion.for_occupant_type("junior_tenant")
  assert results.all? { |q| q.occupant_type == "junior_tenant" }
  assert_not results.any? { |q| q.occupant_type.nil? }
end

test "for_occupant_type with nil returns legacy questions" do
  results = EvictionSimulatorQuestion.for_occupant_type(nil)
  assert results.all? { |q| q.occupant_type.nil? }
end
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `bin/rails test test/models/eviction_step_test.rb test/models/eviction_simulator_question_test.rb`
Expected: FAIL — `for_occupant_type` not defined.

- [ ] **Step 5: Add scope to EvictionStep**

In `app/models/eviction_step.rb`, add after the existing scopes (line 11):

```ruby
scope :for_occupant_type, ->(type) { where(occupant_type: type) }
```

- [ ] **Step 6: Add scope to EvictionSimulatorQuestion**

In `app/models/eviction_simulator_question.rb`, add after the existing scopes (line 9):

```ruby
scope :for_occupant_type, ->(type) { where(occupant_type: type) }
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bin/rails test test/models/eviction_step_test.rb test/models/eviction_simulator_question_test.rb`
Expected: All tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/models/eviction_step.rb app/models/eviction_simulator_question.rb \
  test/models/eviction_step_test.rb test/models/eviction_simulator_question_test.rb \
  test/fixtures/eviction_steps.yml test/fixtures/eviction_simulator_questions.yml
git commit -m "feat(model): add for_occupant_type scope to EvictionStep and EvictionSimulatorQuestion"
```

---

### Task 4: Service — PathBuilder Occupant Type Filtering

**Files:**
- Modify: `app/services/eviction_guide/path_builder.rb`
- Test: `test/services/eviction_guide/path_builder_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/services/eviction_guide/path_builder_test.rb`:

```ruby
test "filters steps by occupant_type when provided" do
  answers = { "JT-Q1" => true }
  path = EvictionGuide::PathBuilder.call(answers, occupant_type: "junior_tenant")
  assert_kind_of Array, path
  step_codes = path.map { |e| e[:code] }
  step_codes.each do |code|
    step = EvictionStep.find_by(code: code)
    assert_equal "junior_tenant", step.occupant_type, "Step #{code} should be junior_tenant"
  end
end

test "legacy behavior unchanged when occupant_type is nil" do
  answers = { "Q1" => true, "Q2" => true }
  path = EvictionGuide::PathBuilder.call(answers, occupant_type: nil)
  assert_kind_of Array, path
  step_codes = path.map { |e| e[:code] }
  step_codes.each do |code|
    step = EvictionStep.find_by(code: code)
    assert_nil step.occupant_type, "Step #{code} should be legacy (nil)"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/eviction_guide/path_builder_test.rb`
Expected: FAIL — `PathBuilder.call` does not accept `occupant_type:` keyword.

- [ ] **Step 3: Implement PathBuilder changes**

Replace the full content of `app/services/eviction_guide/path_builder.rb`:

```ruby
module EvictionGuide
  class PathBuilder
    def self.call(answers, occupant_type: nil)
      new(answers, occupant_type).call
    end

    def initialize(answers, occupant_type)
      @answers = answers || {}
      @occupant_type = occupant_type
      @questions = EvictionSimulatorQuestion.for_occupant_type(occupant_type).index_by(&:code)
      @steps = EvictionStep.for_occupant_type(occupant_type).index_by(&:code)
    end

    def call
      return [] if @answers.empty?

      path = []
      visited_steps = Set.new

      @answers.each do |code, answer|
        question = @questions[code]
        next unless question

        step = @steps[question.step_code]
        next unless step
        next if visited_steps.include?(step.code)

        visited_steps << step.code

        if answer
          path << { code: step.code, name: step.name, status: "completed" }
        else
          path << { code: step.code, name: step.name, status: "needed" }
          add_branch_to_path(path, question, visited_steps)
        end
      end

      path
    end

    private

    def add_branch_to_path(path, question, visited_steps)
      next_code = question.no_next_code
      return unless next_code && next_code != "END"

      next_q = @questions[next_code]
      return unless next_q

      branch_step = @steps[next_q.step_code]
      return unless branch_step&.branch?
      return if visited_steps.include?(branch_step.code)

      visited_steps << branch_step.code
      path << {
        code: branch_step.code,
        name: branch_step.name,
        status: "branch",
        return_step: branch_step.return_step_code
      }
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/eviction_guide/path_builder_test.rb`
Expected: All tests PASS (including existing tests — they call `PathBuilder.call(answers)` which defaults `occupant_type: nil`).

- [ ] **Step 5: Commit**

```bash
git add app/services/eviction_guide/path_builder.rb test/services/eviction_guide/path_builder_test.rb
git commit -m "feat(service): add occupant_type filtering to PathBuilder"
```

---

### Task 5: Service — DifficultyAssessor Base Difficulty

**Files:**
- Modify: `app/services/eviction_guide/difficulty_assessor.rb`
- Test: `test/services/eviction_guide/difficulty_assessor_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/services/eviction_guide/difficulty_assessor_test.rb`:

```ruby
test "returns base difficulty for junior_tenant with all-yes answers" do
  answers = { "JT-Q1" => true }
  result = EvictionGuide::DifficultyAssessor.call(answers, occupant_type: "junior_tenant")
  assert_equal "low", result
end

test "returns base difficulty for senior_tenant with all-yes answers" do
  answers = { "ST-Q1" => true }
  result = EvictionGuide::DifficultyAssessor.call(answers, occupant_type: "senior_tenant")
  assert_equal "high", result
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
  assert_equal "high", result
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
  assert_equal "medium", result
end

test "legacy behavior unchanged when occupant_type is nil" do
  answers = { "Q1" => true }
  result = EvictionGuide::DifficultyAssessor.call(answers, occupant_type: nil)
  assert_equal "low", result
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/eviction_guide/difficulty_assessor_test.rb`
Expected: FAIL — `DifficultyAssessor.call` does not accept `occupant_type:`.

- [ ] **Step 3: Implement DifficultyAssessor changes**

Replace the full content of `app/services/eviction_guide/difficulty_assessor.rb`:

```ruby
module EvictionGuide
  class DifficultyAssessor
    LEVELS = { "high" => 3, "medium" => 2, "low" => 1 }.freeze
    LEVEL_FROM_SCORE = LEVELS.invert.freeze

    def self.call(answers, occupant_type: nil, questions: nil)
      new(answers, occupant_type, questions).call
    end

    def initialize(answers, occupant_type, questions)
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

      LEVEL_FROM_SCORE[max_score] || "low"
    end

    private

    def load_questions
      EvictionSimulatorQuestion.for_occupant_type(@occupant_type).index_by(&:code)
    end
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/eviction_guide/difficulty_assessor_test.rb`
Expected: All tests PASS (existing tests use positional arg `DifficultyAssessor.call(answers)` which still works — `occupant_type` defaults to nil, `questions` defaults to nil).

Note: Existing tests use `DifficultyAssessor.call(answers, questions: questions)`. The new signature `def self.call(answers, occupant_type: nil, questions: nil)` is fully backward-compatible since `questions:` was already a keyword arg.

- [ ] **Step 5: Commit**

```bash
git add app/services/eviction_guide/difficulty_assessor.rb test/services/eviction_guide/difficulty_assessor_test.rb
git commit -m "feat(service): add base difficulty per occupant type to DifficultyAssessor"
```

---

### Task 6: Service — F02DataExtractor Occupant Type Normalization

**Files:**
- Modify: `app/services/eviction_guide/f02_data_extractor.rb`
- Test: `test/services/eviction_guide/f02_data_extractor_test.rb`

- [ ] **Step 1: Write failing test**

Add to `test/services/eviction_guide/f02_data_extractor_test.rb`:

```ruby
test "normalizes valid occupant_type from report" do
  report = @property.rights_analysis_reports.last
  next skip("No report fixture") unless report
  report.update!(parsed_data: (report.parsed_data || {}).merge("occupant_type" => "junior_tenant"))

  result = EvictionGuide::F02DataExtractor.call(@property)
  assert_equal "junior_tenant", result[:occupant_type]
end

test "returns nil for unrecognized occupant_type" do
  report = @property.rights_analysis_reports.last
  next skip("No report fixture") unless report
  report.update!(parsed_data: (report.parsed_data || {}).merge("occupant_type" => "some_llm_garbage"))

  result = EvictionGuide::F02DataExtractor.call(@property)
  assert_nil result[:occupant_type]
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/eviction_guide/f02_data_extractor_test.rb`
Expected: The "returns nil for unrecognized" test FAILS — current code returns raw LLM value without validation.

- [ ] **Step 3: Implement normalization**

In `app/services/eviction_guide/f02_data_extractor.rb`, replace the `:occupant_type` case (line 47):

```ruby
when :occupant_type
  raw = @report&.parsed_data&.dig("occupant_type")
  raw if EvictionSimulation::OCCUPANT_TYPES.include?(raw)
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/eviction_guide/f02_data_extractor_test.rb`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/eviction_guide/f02_data_extractor.rb test/services/eviction_guide/f02_data_extractor_test.rb
git commit -m "feat(service): normalize occupant_type in F02DataExtractor"
```

---

### Task 7: Controller — SimulationsController Type Handling

**Files:**
- Modify: `app/controllers/eviction_guide/simulations_controller.rb`
- Modify: `config/routes.rb`
- Test: `test/controllers/eviction_guide_controller_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/controllers/eviction_guide_controller_test.rb`:

```ruby
test "create without occupant_type redirects to type selection" do
  post eviction_guide_simulation_url
  assert_redirected_to eviction_guide_simulator_select_type_path
end

test "create with valid occupant_type starts simulation" do
  post eviction_guide_simulation_url, params: { occupant_type: "junior_tenant" }
  sim = EvictionSimulation.last
  assert_equal "junior_tenant", sim.occupant_type
  assert_redirected_to eviction_guide_simulator_question_path(code: "JT-Q1")
end

test "select_type renders type selection page" do
  sim = EvictionSimulation.create!(session_id: session.id.to_s, answers: {}, completed: false)
  get eviction_guide_simulator_select_type_url
  assert_response :success
end

test "show passes occupant_type to PathBuilder" do
  sim = EvictionSimulation.create!(
    session_id: "show_test", occupant_type: "junior_tenant",
    answers: { "JT-Q1" => true }, completed: false
  )
  # Set session
  post eviction_guide_simulation_url, params: { occupant_type: "junior_tenant" }
  get eviction_guide_simulation_url
  assert_response :success
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/eviction_guide_controller_test.rb`
Expected: FAIL — routes and actions don't exist yet.

- [ ] **Step 3: Add route**

In `config/routes.rb`, add within the `namespace :eviction_guide` block (after line 67):

```ruby
get "simulator/select_type", to: "simulations#select_type", as: :simulator_select_type
```

- [ ] **Step 4: Implement controller changes**

Replace the full content of `app/controllers/eviction_guide/simulations_controller.rb`:

```ruby
module EvictionGuide
  class SimulationsController < ApplicationController
    def create
      property_id = params[:property_id].presence&.to_i
      occupant_type = params[:occupant_type].presence

      @simulation = if property_id
        EvictionSimulation.find_or_initialize_by(property_id: property_id)
      else
        EvictionSimulation.new(session_id: session.id.to_s)
      end

      @simulation.answers = {}
      @simulation.result_path = []
      @simulation.completed = false
      @simulation.difficulty_level = nil
      @simulation.occupant_type = occupant_type
      @simulation.save!

      session[:eviction_simulation_id] = @simulation.id

      if @simulation.property_linked?
        redirect_to eviction_guide_simulator_prefill_path
      elsif occupant_type.blank?
        redirect_to eviction_guide_simulator_select_type_path
      else
        first_question = first_question_code(occupant_type)
        redirect_to eviction_guide_simulator_question_path(code: first_question)
      end
    end

    def select_type
      @simulation = find_simulation
      render "eviction_guide/simulator/select_type"
    end

    def update
      @simulation = find_simulation
      return head(:not_found) unless @simulation

      question_code = params[:question_code]
      answer = params[:answer] == "true"
      next_code = params[:next_code]

      @simulation.record_answer(question_code, answer)
      @simulation.save!

      if next_code == "END" || next_code.blank?
        redirect_to eviction_guide_simulation_path
      else
        redirect_to eviction_guide_simulator_question_path(code: next_code)
      end
    end

    def show
      @simulation = find_simulation
      return redirect_to eviction_guide_simulator_path unless @simulation

      occupant_type = @simulation.occupant_type
      @simulation.result_path = EvictionGuide::PathBuilder.call(
        @simulation.answers, occupant_type: occupant_type
      )
      @simulation.difficulty_level = EvictionGuide::DifficultyAssessor.call(
        @simulation.answers, occupant_type: occupant_type
      )
      @simulation.completed = true
      @simulation.save!

      render "eviction_guide/simulator/result", layout: "application"
    end

    def prefill
      @simulation = find_simulation
      return redirect_to eviction_guide_simulator_path unless @simulation&.property_linked?

      @property = @simulation.property
      @prefill_data = EvictionGuide::F02DataExtractor.call(@property)
      render "eviction_guide/simulator/prefill"
    end

    private

    def find_simulation
      EvictionSimulation.find_by(id: session[:eviction_simulation_id])
    end

    def first_question_code(occupant_type)
      EvictionSimulatorQuestion
        .for_occupant_type(occupant_type)
        .ordered
        .first
        &.code || "Q1"
    end
  end
end
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/controllers/eviction_guide_controller_test.rb`
Expected: All tests PASS (select_type test may fail until Task 8 creates the view — if so, create a minimal placeholder view first).

- [ ] **Step 6: Commit**

```bash
git add app/controllers/eviction_guide/simulations_controller.rb config/routes.rb \
  test/controllers/eviction_guide_controller_test.rb
git commit -m "feat(controller): add occupant_type handling to SimulationsController"
```

---

### Task 8: UI — Occupant Type Selector Component

**Files:**
- Create: `app/components/eviction_guide/occupant_type_selector_component.rb`
- Create: `app/components/eviction_guide/occupant_type_selector_component.html.erb`
- Create: `app/views/eviction_guide/simulator/select_type.html.erb`

- [ ] **Step 1: Create component Ruby file**

Create `app/components/eviction_guide/occupant_type_selector_component.rb`:

```ruby
module EvictionGuide
  class OccupantTypeSelectorComponent < ViewComponent::Base
    CARDS = EvictionSimulation::OCCUPANT_TYPES.map { |type|
      {
        type: type,
        label: EvictionSimulation::OCCUPANT_TYPE_LABELS[type],
        difficulty: EvictionSimulation::BASE_DIFFICULTY[type]
      }
    }.freeze

    def initialize(simulation:)
      @simulation = simulation
    end

    private

    def cards
      CARDS
    end

    def difficulty_classes(level)
      case level
      when "low" then "bg-green-200 text-green-800 dark:bg-green-900/30 dark:text-green-400"
      when "medium" then "bg-yellow-200 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400"
      when "high" then "bg-red-200 text-red-800 dark:bg-red-900/30 dark:text-red-400"
      end
    end

    def difficulty_label(level)
      { "low" => "낮음", "medium" => "중간", "high" => "높음" }[level]
    end
  end
end
```

- [ ] **Step 2: Create component template**

Create `app/components/eviction_guide/occupant_type_selector_component.html.erb`:

```erb
<div class="max-w-2xl mx-auto">
  <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-2">점유자 유형 선택</h3>
  <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
    명도 대상 점유자의 유형을 선택해주세요. 유형에 따라 명도 절차가 달라집니다.
  </p>

  <div class="space-y-3">
    <% cards.each do |card| %>
      <%= form_with url: helpers.eviction_guide_simulation_path, method: :post do |f| %>
        <%= f.hidden_field :occupant_type, value: card[:type] %>
        <button type="submit"
                class="w-full text-left border-2 border-slate-200 dark:border-slate-700 rounded-lg p-4 hover:border-blue-500 dark:hover:border-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/20 transition-colors">
          <div class="flex items-center justify-between">
            <strong class="text-sm text-slate-900 dark:text-slate-100"><%= card[:label] %></strong>
            <span class="text-xs font-medium px-2 py-0.5 rounded-full <%= difficulty_classes(card[:difficulty]) %>">
              난이도: <%= difficulty_label(card[:difficulty]) %>
            </span>
          </div>
        </button>
      <% end %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 3: Create select_type view**

Create `app/views/eviction_guide/simulator/select_type.html.erb`:

```erb
<% content_for(:page_title, "명도 시뮬레이터") %>
<%= render EvictionGuide::TabNavigationComponent.new(active_tab: "simulator") %>

<div class="max-w-3xl mx-auto">
  <%= render EvictionGuide::OccupantTypeSelectorComponent.new(simulation: @simulation) %>
</div>
```

- [ ] **Step 4: Verify in browser**

Run: `bin/rails server`
Navigate to the simulator page, click "직접 입력으로 시뮬레이션".
Expected: Redirects to type selection page showing 4 occupant type cards with difficulty badges.

- [ ] **Step 5: Commit**

```bash
git add app/components/eviction_guide/occupant_type_selector_component.rb \
  app/components/eviction_guide/occupant_type_selector_component.html.erb \
  app/views/eviction_guide/simulator/select_type.html.erb
git commit -m "feat(ui): add occupant type selector component and view"
```

---

### Task 9: UI — F02 Prefill Occupant Type Field

**Files:**
- Modify: `app/components/eviction_guide/f02_prefill_component.rb`
- Modify: `app/components/eviction_guide/f02_prefill_component.html.erb`

- [ ] **Step 1: Add occupant_type_options helper to component**

In `app/components/eviction_guide/f02_prefill_component.rb`, add after the `format_value` method (before the final `end`):

```ruby
def occupant_type_options
  EvictionSimulation::OCCUPANT_TYPES.map { |type|
    [EvictionSimulation::OCCUPANT_TYPE_LABELS[type], type]
  }
end

def extracted_occupant_type
  @prefill_data[:occupant_type]
end
```

- [ ] **Step 2: Update prefill template to include type selector**

Replace the full content of `app/components/eviction_guide/f02_prefill_component.html.erb`:

```erb
<div class="max-w-2xl mx-auto">
  <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-2">AI 분석 결과 확인</h3>
  <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
    물건분석(F02)에서 가져온 결과입니다. 각 항목이 맞는지 확인해주세요.
  </p>

  <div class="space-y-3 mb-6">
    <% fields.each do |field| %>
      <% next if field[:key] == :occupant_type %>
      <div class="border border-slate-200 dark:border-slate-700 rounded-md p-3">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="text-xs bg-blue-600 text-white px-1.5 py-0.5 rounded">AI 분석</span>
            <strong class="text-sm text-slate-900 dark:text-slate-100"><%= field[:label] %></strong>
          </div>
          <span class="text-sm font-medium text-slate-700 dark:text-slate-300"><%= field[:display_value] %></span>
        </div>
      </div>
    <% end %>
  </div>

  <%= form_with url: helpers.eviction_guide_simulation_path, method: :post do |f| %>
    <%= f.hidden_field :property_id, value: @simulation&.property_id %>

    <%# Occupant type selector %>
    <div class="border border-slate-200 dark:border-slate-700 rounded-md p-4 mb-6">
      <div class="flex items-center gap-2 mb-3">
        <% if extracted_occupant_type %>
          <span class="text-xs bg-blue-600 text-white px-1.5 py-0.5 rounded">AI가 권리분석 보고서에서 추출</span>
        <% end %>
        <strong class="text-sm text-slate-900 dark:text-slate-100">점유자 유형</strong>
      </div>
      <div class="space-y-2">
        <% occupant_type_options.each do |label, value| %>
          <label class="flex items-center gap-3 p-2 rounded hover:bg-slate-50 dark:hover:bg-slate-800 cursor-pointer">
            <input type="radio" name="occupant_type" value="<%= value %>"
                   <%= "checked" if value == extracted_occupant_type %>
                   class="text-blue-600" required>
            <span class="text-sm text-slate-700 dark:text-slate-300"><%= label %></span>
          </label>
        <% end %>
      </div>
    </div>

    <div class="text-right">
      <button type="submit"
              class="px-6 py-2 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700">
        확인 완료 → 시뮬레이션 시작
      </button>
    </div>
  <% end %>
</div>
```

- [ ] **Step 3: Verify in browser**

If a property-linked simulation is available, navigate to the prefill page.
Expected: Shows AI analysis fields plus an occupant type radio group. If F02 extracted a type, it's pre-selected with "AI가 권리분석 보고서에서 추출" badge.

- [ ] **Step 4: Commit**

```bash
git add app/components/eviction_guide/f02_prefill_component.rb \
  app/components/eviction_guide/f02_prefill_component.html.erb
git commit -m "feat(ui): add occupant type selector to F02 prefill component"
```

---

### Task 10: UI — Occupant Type Badge in Question and Result Screens

**Files:**
- Modify: `app/components/eviction_guide/simulator_question_component.rb`
- Modify: `app/components/eviction_guide/simulator_question_component.html.erb`
- Modify: `app/components/eviction_guide/simulator_result_component.rb`
- Modify: `app/components/eviction_guide/simulator_result_component.html.erb`

- [ ] **Step 1: Update SimulatorQuestionComponent to show badge and fix progress**

In `app/components/eviction_guide/simulator_question_component.rb`, replace the `progress_percent` and `count_remaining_steps` methods:

```ruby
def occupant_type_label
  @simulation&.occupant_type_label
end

def progress_percent
  answered = @simulation&.answers&.size || 0
  total_main = EvictionStep
    .for_occupant_type(@simulation&.occupant_type)
    .main
    .count
  return 0 if total_main.zero?
  [((answered.to_f / total_main) * 100).round, 100].min
end
```

Remove the `count_remaining_steps` method entirely (no longer needed — progress is based on main step count, not graph traversal).

- [ ] **Step 2: Add badge to question template**

In `app/components/eviction_guide/simulator_question_component.html.erb`, add after the progress bar `<span>` (after line 9, before the step badge):

```erb
<% if occupant_type_label %>
  <span class="text-xs font-medium bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-300 px-2 py-0.5 rounded-full mb-2 inline-block">
    <%= occupant_type_label %>
  </span>
<% end %>
```

- [ ] **Step 3: Update SimulatorResultComponent for type summary**

In `app/components/eviction_guide/simulator_result_component.rb`, add helper methods:

```ruby
def occupant_type_label
  @simulation.occupant_type_label
end

def occupant_type
  @simulation.occupant_type
end
```

- [ ] **Step 4: Add type badge to result template**

In `app/components/eviction_guide/simulator_result_component.html.erb`, add before the difficulty badge (before line 4):

```erb
<% if occupant_type_label %>
  <div class="text-center mb-2">
    <span class="inline-flex items-center rounded-full px-4 py-1.5 text-sm font-semibold bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-300">
      점유자 유형: <%= occupant_type_label %>
    </span>
  </div>
<% end %>
```

- [ ] **Step 5: Verify in browser**

Start a `junior_tenant` simulation, go through a question.
Expected: Occupant type badge visible above the step badge. Progress bar uses main step count.

- [ ] **Step 6: Commit**

```bash
git add app/components/eviction_guide/simulator_question_component.rb \
  app/components/eviction_guide/simulator_question_component.html.erb \
  app/components/eviction_guide/simulator_result_component.rb \
  app/components/eviction_guide/simulator_result_component.html.erb
git commit -m "feat(ui): show occupant type badge in question and result screens"
```

---

### Task 11: Seed Data — junior_tenant Steps, Questions, and Summaries

**Files:**
- Modify: `db/seeds/eviction_steps.json`
- Modify: `db/seeds/eviction_simulator_questions.json`
- Modify: `db/seeds.rb`

- [ ] **Step 1: Add occupant_type field to existing seed entries**

In `db/seeds/eviction_steps.json`, add `"occupant_type": null` to every existing step and branch entry (all S1~S15, B1~B11). This makes the field explicit for legacy data.

- [ ] **Step 2: Add JT steps to eviction_steps.json**

Add inside the `"steps"` array at the end (before the `"branches"` array):

```json
{
  "code": "JT-S1",
  "occupant_type": "junior_tenant",
  "step_type": "main",
  "name": "배당표 확인",
  "description": "법원 배당표에서 임차인의 배당 수령 여부와 금액을 확인한다. 배당을 수령한 후순위 임차인은 퇴거 의무가 명확하므로 협상 레버리지가 된다.",
  "completion_condition": "배당 수령 여부 및 금액 확인 완료",
  "failure_condition": "배당 미수령 / 배당요구 미신청",
  "required_documents": ["배당표", "매각물건명세서"],
  "estimated_duration": "3~5일",
  "estimated_cost": null,
  "legal_basis": [
    {
      "title": "민사집행법 제145조 (배당표)",
      "summary": "배당을 받을 채권자와 배당 순위·금액을 기재",
      "url": "https://law.go.kr"
    }
  ],
  "position": 201,
  "next_step_code": "JT-S2",
  "branch_codes": ["JT-B1"]
},
{
  "code": "JT-S2",
  "occupant_type": "junior_tenant",
  "step_type": "main",
  "name": "잔금 납부 & 인도명령 신청",
  "description": "매각대금 완납과 동시에 인도명령 + 점유이전금지가처분을 세트로 신청한다. 잔금 납부일부터 6개월 이내에만 인도명령 신청이 가능하므로 당일 신청이 실무 정석.",
  "completion_condition": "잔금 납부 + 인도명령·가처분 접수 완료",
  "failure_condition": "6개월 기한 도과",
  "required_documents": ["잔금완납증명서", "인도명령 신청서", "점유이전금지가처분 신청서"],
  "estimated_duration": "잔금 납부일 당일",
  "estimated_cost": "인지대·송달료",
  "legal_basis": [
    {
      "title": "민사집행법 제136조 (인도명령)",
      "summary": "매수인은 매각대금 납부 후 6개월 이내에 인도명령 신청 가능",
      "url": "https://law.go.kr"
    }
  ],
  "position": 202,
  "next_step_code": "JT-S3",
  "branch_codes": []
},
{
  "code": "JT-S3",
  "occupant_type": "junior_tenant",
  "step_type": "main",
  "name": "1차 접촉 & 퇴거 통보",
  "description": "소유권이전등기 후 점유자에게 내용증명 또는 직접 방문으로 새 소유자임을 통보한다. 배당 수령 사실을 근거로 퇴거 의무를 설명하고 이사일정을 협의한다.",
  "completion_condition": "점유자와 연락 성공, 이사일정 협의 시작",
  "failure_condition": "연락 두절 / 퇴거 거부",
  "required_documents": ["소유권이전등기 완료 확인서", "내용증명"],
  "estimated_duration": "1~2주",
  "estimated_cost": "등기비용·취득세",
  "legal_basis": [],
  "position": 203,
  "next_step_code": "JT-S4",
  "branch_codes": ["JT-B2"]
},
{
  "code": "JT-S4",
  "occupant_type": "junior_tenant",
  "step_type": "main",
  "name": "명도확인서 교환 협상",
  "description": "배당받는 임차인은 명도확인서가 있어야 법원에서 배당금 수령이 가능하다. 공실 확인·공과금 정산이 완료된 후에 교부하는 것이 철칙. 선(先)교부는 협상 레버리지 상실.",
  "completion_condition": "공실 확인 + 명도확인서 교부",
  "failure_condition": "명도확인서 선교부 요구 / 이사일 불이행",
  "required_documents": ["명도확인서", "인감증명서"],
  "estimated_duration": "합의 후 1~3일",
  "estimated_cost": null,
  "legal_basis": [],
  "position": 204,
  "next_step_code": "JT-S5",
  "branch_codes": []
},
{
  "code": "JT-S5",
  "occupant_type": "junior_tenant",
  "step_type": "main",
  "name": "관리비 정산",
  "description": "판례상 경매 낙찰자는 공용 관리비만 인수, 전용 부분 관리비는 점유자 부담이 원칙. 관리사무소에 구분 청구서를 요청하여 공용·전용을 분리 납부한다.",
  "completion_condition": "구분 청구서 수령 / 공용 관리비 납부 완료",
  "failure_condition": "관리사무소 일괄 청구·단수·단전 위협",
  "required_documents": ["구분 청구서"],
  "estimated_duration": "1~2주",
  "estimated_cost": "공용 관리비",
  "legal_basis": [],
  "position": 205,
  "next_step_code": "JT-S6",
  "branch_codes": []
},
{
  "code": "JT-S6",
  "occupant_type": "junior_tenant",
  "step_type": "main",
  "name": "인수 완료",
  "description": "시설물 인수 확인. 파손·훼손 여부를 사진·영상으로 채증하고, 잠금장치를 즉시 교체한다.",
  "completion_condition": "시설 정상 확인 / 잠금장치 교체",
  "failure_condition": "고의적 파손 발견",
  "required_documents": [],
  "estimated_duration": "1~3일",
  "estimated_cost": "잠금장치 교체비",
  "legal_basis": [],
  "position": 206,
  "next_step_code": null,
  "branch_codes": []
}
```

- [ ] **Step 3: Add JT branches to eviction_steps.json**

Add inside the `"branches"` array at the end:

```json
{
  "code": "JT-B1",
  "occupant_type": "junior_tenant",
  "step_type": "branch",
  "name": "배당 미수령",
  "description": "임차인이 배당을 수령하지 않은 경우. 배당요구 미신청 또는 배당금 미수령 상태에서는 퇴거 의무 근거가 약화된다.",
  "trigger_step_code": "JT-S1",
  "problem_summary": "임차인 배당 미수령으로 퇴거 의무 불명확",
  "root_cause": "배당요구 미신청 또는 배당금 미수령",
  "action_steps": [
    "배당요구 여부 재확인 (법원 기록 열람)",
    "임차인과 직접 협의하여 배당금 수령 유도",
    "배당금 수령 거부 시 공탁 절차 안내"
  ],
  "legal_basis": [],
  "return_step_code": "JT-S2",
  "estimated_duration": "2~4주",
  "position": 211
},
{
  "code": "JT-B2",
  "occupant_type": "junior_tenant",
  "step_type": "branch",
  "name": "협상 결렬 → 강제집행",
  "description": "임차인이 퇴거를 거부하거나 과도한 이사비를 요구하여 협상이 결렬된 경우. 인도명령 결정문을 근거로 강제집행 절차를 진행한다.",
  "trigger_step_code": "JT-S3",
  "problem_summary": "점유자 퇴거 거부로 협상 교착",
  "root_cause": "점유자의 버티기 전략 또는 과도한 이사비 요구",
  "action_steps": [
    "인도명령 결정문 송달 확인",
    "강제집행 신청 + 예납금 납부",
    "집행관 계고 (1차 방문) 후 2주 대기",
    "계고 불응 시 본집행 실시"
  ],
  "legal_basis": [
    {
      "title": "민사집행법 제136조",
      "summary": "확정된 인도명령은 강제집행 신청의 기초",
      "url": "https://law.go.kr"
    }
  ],
  "return_step_code": "JT-S4",
  "estimated_duration": "1~2개월",
  "position": 212
}
```

- [ ] **Step 4: Add JT questions to eviction_simulator_questions.json**

Add at the end of the JSON array:

```json
{
  "code": "JT-Q1",
  "occupant_type": "junior_tenant",
  "phase": "summary",
  "step_code": "JT-S1",
  "question": "배당표에서 임차인이 배당을 수령했나요?",
  "help_text": "배당 수령 여부에 따라 협상 전략이 달라집니다. 법원 배당표를 확인해주세요.",
  "yes_next_code": "JT-Q2",
  "no_next_code": "JT-Q1G",
  "f02_field_mapping": "is_dividend_requested",
  "difficulty_impact": null
},
{
  "code": "JT-Q1G",
  "occupant_type": "junior_tenant",
  "phase": "summary",
  "step_code": "JT-S1",
  "question": "배당 미수령 상태로 계속 진행하시겠습니까?",
  "help_text": "배당을 수령하지 않은 경우 퇴거 의무 근거가 약해질 수 있습니다.",
  "yes_next_code": "JT-Q2",
  "no_next_code": "END",
  "f02_field_mapping": null,
  "difficulty_impact": "medium"
},
{
  "code": "JT-Q2",
  "occupant_type": "junior_tenant",
  "phase": "summary",
  "step_code": "JT-S2",
  "question": "잔금 납부와 동시에 인도명령을 신청했나요?",
  "help_text": "잔금 납부일부터 6개월 이내에만 인도명령 신청이 가능합니다. 당일 신청이 실무 정석입니다.",
  "yes_next_code": "JT-Q3",
  "no_next_code": "JT-Q2G",
  "f02_field_mapping": null,
  "difficulty_impact": null
},
{
  "code": "JT-Q2G",
  "occupant_type": "junior_tenant",
  "phase": "summary",
  "step_code": "JT-S2",
  "question": "인도명령 6개월 기한이 아직 남아있나요?",
  "help_text": "기한이 지나면 정식 명도소송만 가능하여 4~10개월 추가 소요됩니다.",
  "yes_next_code": "JT-Q3",
  "no_next_code": "END",
  "f02_field_mapping": null,
  "difficulty_impact": "high"
},
{
  "code": "JT-Q3",
  "occupant_type": "junior_tenant",
  "phase": "summary",
  "step_code": "JT-S3",
  "question": "점유자와 1차 접촉에 성공했나요?",
  "help_text": "소유권이전등기 후 내용증명 또는 방문으로 새 소유자임을 통보합니다.",
  "yes_next_code": "JT-Q4",
  "no_next_code": "JT-Q3G",
  "f02_field_mapping": null,
  "difficulty_impact": null
},
{
  "code": "JT-Q3G",
  "occupant_type": "junior_tenant",
  "phase": "summary",
  "step_code": "JT-S3",
  "question": "연락두절/퇴거거부 상태에서도 진행하시겠습니까?",
  "help_text": "인도명령 결정문을 근거로 강제집행 절차를 진행할 수 있습니다.",
  "yes_next_code": "JT-Q4",
  "no_next_code": "END",
  "f02_field_mapping": null,
  "difficulty_impact": "high"
},
{
  "code": "JT-Q4",
  "occupant_type": "junior_tenant",
  "phase": "summary",
  "step_code": "JT-S4",
  "question": "명도확인서 교부 조건이 합의되었나요?",
  "help_text": "공실 확인 + 공과금 정산 완료 후에 명도확인서를 교부하는 것이 철칙입니다.",
  "yes_next_code": "JT-Q5",
  "no_next_code": "JT-Q4G",
  "f02_field_mapping": null,
  "difficulty_impact": null
},
{
  "code": "JT-Q4G",
  "occupant_type": "junior_tenant",
  "phase": "summary",
  "step_code": "JT-S4",
  "question": "명도확인서 교부 없이 계속 진행하시겠습니까?",
  "help_text": "명도확인서는 임차인이 배당금을 수령하기 위해 필요합니다. 강력한 협상 도구입니다.",
  "yes_next_code": "JT-Q5",
  "no_next_code": "END",
  "f02_field_mapping": null,
  "difficulty_impact": "medium"
},
{
  "code": "JT-Q5",
  "occupant_type": "junior_tenant",
  "phase": "summary",
  "step_code": "JT-S5",
  "question": "관리비 정산이 완료되었나요?",
  "help_text": "공용 관리비만 낙찰자 부담, 전용 부분은 점유자 부담이 원칙입니다.",
  "yes_next_code": "JT-Q6",
  "no_next_code": "JT-Q5G",
  "f02_field_mapping": null,
  "difficulty_impact": null
},
{
  "code": "JT-Q5G",
  "occupant_type": "junior_tenant",
  "phase": "summary",
  "step_code": "JT-S5",
  "question": "관리비 문제를 인지한 상태로 계속 진행하시겠습니까?",
  "help_text": "관리사무소가 일괄 청구하거나 단수·단전으로 위협할 수 있습니다.",
  "yes_next_code": "JT-Q6",
  "no_next_code": "END",
  "f02_field_mapping": null,
  "difficulty_impact": "low"
},
{
  "code": "JT-Q6",
  "occupant_type": "junior_tenant",
  "phase": "summary",
  "step_code": "JT-S6",
  "question": "시설물 인수가 완료되었나요?",
  "help_text": "파손·훼손 여부를 사진·영상으로 채증하고 잠금장치를 교체합니다.",
  "yes_next_code": "END",
  "no_next_code": "END",
  "f02_field_mapping": null,
  "difficulty_impact": null
}
```

- [ ] **Step 5: Update seeds.rb to include occupant_type field**

In `db/seeds.rb`, in the eviction steps seeding block (line 152~171), add `occupant_type` assignment. After line 169 (`step.return_step_code = attrs["return_step_code"]`), add:

```ruby
step.occupant_type = attrs["occupant_type"]
```

In the questions seeding block (line 176~187), add after line 185 (`q.difficulty_impact = attrs["difficulty_impact"]`):

```ruby
q.occupant_type = attrs["occupant_type"]
```

- [ ] **Step 6: Add occupant_type: null to all existing step/branch entries in eviction_steps.json**

Add `"occupant_type": null` to every existing entry in `steps` array (S1~S15) and `branches` array (B1~B11).

- [ ] **Step 7: Add occupant_type: null to all existing question entries in eviction_simulator_questions.json**

Add `"occupant_type": null` to every existing entry (Q1~Q15 and sub-questions).

- [ ] **Step 8: Reseed and verify**

Run: `bin/rails db:seed`
Expected: Seed completes successfully. New JT-prefixed steps and questions are created with `occupant_type: "junior_tenant"`.

Verify: `bin/rails runner "puts EvictionStep.where(occupant_type: 'junior_tenant').count"` → should print 8 (6 main + 2 branch).

- [ ] **Step 9: Commit**

```bash
git add db/seeds/eviction_steps.json db/seeds/eviction_simulator_questions.json db/seeds.rb
git commit -m "feat(seed): add junior_tenant steps, branches, and questions"
```

---

### Task 12: Integration — Full Flow Verification

**Files:**
- Test: `test/controllers/eviction_guide_controller_test.rb` (add integration tests)

- [ ] **Step 1: Write integration tests**

Add to `test/controllers/eviction_guide_controller_test.rb`:

```ruby
test "full junior_tenant standalone flow" do
  # Step 1: Create simulation → redirects to type selection
  post eviction_guide_simulation_url
  assert_redirected_to eviction_guide_simulator_select_type_path

  # Step 2: Select junior_tenant type → creates simulation with type, redirects to JT-Q1
  post eviction_guide_simulation_url, params: { occupant_type: "junior_tenant" }
  sim = EvictionSimulation.last
  assert_equal "junior_tenant", sim.occupant_type
  follow_redirect!
  assert_response :success

  # Step 3: Answer JT-Q1 = yes → redirects to JT-Q2
  patch eviction_guide_simulation_url, params: {
    question_code: "JT-Q1", answer: "true", next_code: "JT-Q2"
  }
  follow_redirect!
  assert_response :success

  # Step 4: Answer all remaining questions yes → END → result
  patch eviction_guide_simulation_url, params: {
    question_code: "JT-Q2", answer: "true", next_code: "JT-Q3"
  }
  patch eviction_guide_simulation_url, params: {
    question_code: "JT-Q3", answer: "true", next_code: "JT-Q4"
  }
  patch eviction_guide_simulation_url, params: {
    question_code: "JT-Q4", answer: "true", next_code: "JT-Q5"
  }
  patch eviction_guide_simulation_url, params: {
    question_code: "JT-Q5", answer: "true", next_code: "JT-Q6"
  }
  patch eviction_guide_simulation_url, params: {
    question_code: "JT-Q6", answer: "true", next_code: "END"
  }
  assert_redirected_to eviction_guide_simulation_path

  # Step 5: View result
  get eviction_guide_simulation_url
  assert_response :success

  sim.reload
  assert sim.completed
  assert_equal "low", sim.difficulty_level
  assert_not_empty sim.result_path
end

test "legacy simulation without occupant_type still works" do
  post eviction_guide_simulation_url, params: { property_id: "" }
  assert_redirected_to eviction_guide_simulator_select_type_path
end
```

- [ ] **Step 2: Run integration tests**

Run: `bin/rails test test/controllers/eviction_guide_controller_test.rb`
Expected: All tests PASS.

- [ ] **Step 3: Run full test suite**

Run: `bin/rails test`
Expected: All tests PASS. No regressions.

- [ ] **Step 4: Commit**

```bash
git add test/controllers/eviction_guide_controller_test.rb
git commit -m "test: add integration tests for junior_tenant occupant type flow"
```

---

### Task 13: E2E Verification in Browser

- [ ] **Step 1: Start dev server**

Run: `bin/rails server`

- [ ] **Step 2: Test standalone flow**

1. Navigate to simulator page
2. Click "직접 입력으로 시뮬레이션"
3. Verify type selection screen shows 4 cards with difficulty badges
4. Select "후순위 임차인 (배당 수령)"
5. Verify question screen shows occupant type badge
6. Answer all questions with "네"
7. Verify result screen shows occupant type + difficulty badge
8. Verify result path contains JT-prefixed steps only

- [ ] **Step 3: Test branch flow**

1. Start new `junior_tenant` simulation
2. Answer JT-Q1 with "아니오" (triggers JT-B1 branch)
3. Verify branch question appears
4. Continue through remaining questions
5. Verify result includes branch entry

- [ ] **Step 4: Test legacy flow still works**

1. Navigate to simulator, start legacy flow (if available via existing UI)
2. Verify original S1~S15 questions still work
3. Verify result uses legacy steps

- [ ] **Step 5: Commit any fixes found during E2E**

Fix any issues discovered and commit with descriptive messages.
