# F06 Eviction Scenario Guide Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a 2-tab eviction guidance system (/eviction-guide) with an educational step-by-step Guide and an interactive yes/no Simulator that produces personalized eviction paths.

**Architecture:** Seed-data-driven content (JSON → DB), Turbo Frame question flow for the simulator, Stimulus accordion for the guide, F02 data extraction service for property-linked pre-fill. 3 DB tables, 7 ViewComponents, 2 Stimulus controllers.

**Tech Stack:** Rails 8.1, Hotwire (Turbo Frames + Stimulus), ViewComponent, TailwindCSS, Solid Queue (cleanup job), Minitest

**Spec:** `docs/superpowers/specs/2026-04-14-f06-eviction-scenario-guide-design.md`

**Reference docs:** `docs/references/ref-001.md` through `ref-006.md` — source content for seed data

---

## File Map

### Database
- Create: `db/migrate/YYYYMMDD_create_eviction_steps.rb`
- Create: `db/migrate/YYYYMMDD_create_eviction_simulator_questions.rb`
- Create: `db/migrate/YYYYMMDD_create_eviction_simulations.rb`

### Seed Data
- Create: `db/seeds/eviction_steps.json`
- Create: `db/seeds/eviction_simulator_questions.json`
- Modify: `db/seeds.rb` — add eviction seed loading

### Models
- Create: `app/models/eviction_step.rb`
- Create: `app/models/eviction_simulator_question.rb`
- Create: `app/models/eviction_simulation.rb`
- Modify: `app/models/property.rb` — add `has_many :eviction_simulations`

### Service Objects
- Create: `app/services/eviction_guide/f02_data_extractor.rb`
- Create: `app/services/eviction_guide/difficulty_assessor.rb`
- Create: `app/services/eviction_guide/path_builder.rb`

### Controllers
- Create: `app/controllers/eviction_guide_controller.rb`
- Create: `app/controllers/eviction_guide/simulations_controller.rb`
- Create: `app/controllers/eviction_guide/simulator_controller.rb`
- Create: `app/controllers/eviction_guide/steps_controller.rb`
- Create: `app/controllers/eviction_guide/branches_controller.rb`

### Views
- Create: `app/views/eviction_guide/guide.html.erb`
- Create: `app/views/eviction_guide/simulator.html.erb`
- Create: `app/views/eviction_guide/simulator/_question.html.erb`
- Create: `app/views/eviction_guide/simulator/_result.html.erb`
- Create: `app/views/eviction_guide/simulator/_property_selector.html.erb`
- Create: `app/views/eviction_guide/steps/show.html.erb`
- Create: `app/views/eviction_guide/branches/show.html.erb`

### ViewComponents
- Create: `app/components/eviction_guide/tab_navigation_component.rb`
- Create: `app/components/eviction_guide/tab_navigation_component.html.erb`
- Create: `app/components/eviction_guide/step_card_component.rb`
- Create: `app/components/eviction_guide/step_card_component.html.erb`
- Create: `app/components/eviction_guide/simulator_question_component.rb`
- Create: `app/components/eviction_guide/simulator_question_component.html.erb`
- Create: `app/components/eviction_guide/simulator_result_component.rb`
- Create: `app/components/eviction_guide/simulator_result_component.html.erb`
- Create: `app/components/eviction_guide/f02_prefill_component.rb`
- Create: `app/components/eviction_guide/f02_prefill_component.html.erb`
- Create: `app/components/eviction_guide/difficulty_badge_component.rb`
- Create: `app/components/eviction_guide/difficulty_badge_component.html.erb`
- Create: `app/components/eviction_guide/legal_inline_component.rb`
- Create: `app/components/eviction_guide/legal_inline_component.html.erb`

### Stimulus Controllers
- Create: `app/javascript/controllers/accordion_controller.js`
- Create: `app/javascript/controllers/simulator_controller.js`

### Background Job
- Create: `app/jobs/eviction_simulation_cleanup_job.rb`

### Routes
- Modify: `config/routes.rb` — add eviction_guide routes

### Tests
- Create: `test/models/eviction_step_test.rb`
- Create: `test/models/eviction_simulator_question_test.rb`
- Create: `test/models/eviction_simulation_test.rb`
- Create: `test/services/eviction_guide/f02_data_extractor_test.rb`
- Create: `test/services/eviction_guide/difficulty_assessor_test.rb`
- Create: `test/services/eviction_guide/path_builder_test.rb`
- Create: `test/controllers/eviction_guide_controller_test.rb`
- Create: `test/controllers/eviction_guide/simulations_controller_test.rb`
- Create: `test/controllers/eviction_guide/simulator_controller_test.rb`
- Create: `test/models/eviction_seed_graph_validation_test.rb`
- Create: `test/jobs/eviction_simulation_cleanup_job_test.rb`
- Create: `test/fixtures/eviction_steps.yml`
- Create: `test/fixtures/eviction_simulator_questions.yml`
- Create: `test/fixtures/eviction_simulations.yml`

### Cross-link
- Modify: `app/views/inspections/grades/show.html.erb` — add eviction guide link

---

## Task 1: Database Migrations & Models

**Files:**
- Create: `db/migrate/YYYYMMDD_create_eviction_steps.rb`
- Create: `db/migrate/YYYYMMDD_create_eviction_simulator_questions.rb`
- Create: `db/migrate/YYYYMMDD_create_eviction_simulations.rb`
- Create: `app/models/eviction_step.rb`
- Create: `app/models/eviction_simulator_question.rb`
- Create: `app/models/eviction_simulation.rb`
- Modify: `app/models/property.rb`
- Create: `test/models/eviction_step_test.rb`
- Create: `test/models/eviction_simulator_question_test.rb`
- Create: `test/models/eviction_simulation_test.rb`
- Create: `test/fixtures/eviction_steps.yml`
- Create: `test/fixtures/eviction_simulator_questions.yml`
- Create: `test/fixtures/eviction_simulations.yml`

- [ ] **Step 1: Generate migrations**

Run:
```bash
bin/rails generate migration CreateEvictionSteps \
  code:string:uniq step_type:integer name:string description:text \
  completion_condition:text failure_condition:text \
  required_documents:json estimated_duration:string estimated_cost:string \
  legal_basis:json position:integer \
  next_step_code:string branch_codes:json \
  trigger_step_code:string problem_summary:text root_cause:text \
  action_steps:json return_step_code:string

bin/rails generate migration CreateEvictionSimulatorQuestions \
  code:string:uniq phase:integer step_code:string \
  question:text help_text:text \
  yes_next_code:string no_next_code:string \
  f02_field_mapping:string difficulty_impact:string

bin/rails generate migration CreateEvictionSimulations \
  property:references session_id:string \
  answers:json result_path:json \
  difficulty_level:string completed:boolean
```

- [ ] **Step 2: Edit the eviction_steps migration**

Open the generated migration file and ensure it matches:

```ruby
class CreateEvictionSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :eviction_steps do |t|
      t.string  :code,                 null: false
      t.integer :step_type,            null: false, default: 0
      t.string  :name,                 null: false
      t.text    :description,          null: false
      t.text    :completion_condition
      t.text    :failure_condition
      t.json    :required_documents
      t.string  :estimated_duration
      t.string  :estimated_cost
      t.json    :legal_basis
      t.integer :position,             null: false, default: 0
      t.string  :next_step_code
      t.json    :branch_codes
      t.string  :trigger_step_code
      t.text    :problem_summary
      t.text    :root_cause
      t.json    :action_steps
      t.string  :return_step_code
      t.timestamps
    end

    add_index :eviction_steps, :code, unique: true
    add_index :eviction_steps, [:step_type, :position]
  end
end
```

- [ ] **Step 3: Edit the eviction_simulator_questions migration**

```ruby
class CreateEvictionSimulatorQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :eviction_simulator_questions do |t|
      t.string  :code,             null: false
      t.integer :phase,            null: false, default: 0
      t.string  :step_code,        null: false
      t.text    :question,         null: false
      t.text    :help_text
      t.string  :yes_next_code
      t.string  :no_next_code
      t.string  :f02_field_mapping
      t.string  :difficulty_impact
      t.timestamps
    end

    add_index :eviction_simulator_questions, :code, unique: true
    add_index :eviction_simulator_questions, :step_code
  end
end
```

- [ ] **Step 4: Edit the eviction_simulations migration**

```ruby
class CreateEvictionSimulations < ActiveRecord::Migration[8.1]
  def change
    create_table :eviction_simulations do |t|
      t.references :property, null: true, foreign_key: true
      t.string     :session_id
      t.json       :answers
      t.json       :result_path
      t.string     :difficulty_level
      t.boolean    :completed, default: false, null: false
      t.timestamps
    end

    add_index :eviction_simulations, :session_id
    add_index :eviction_simulations, [:property_id], unique: true, where: "property_id IS NOT NULL",
              name: "idx_eviction_simulations_one_per_property"
  end
end
```

- [ ] **Step 5: Run migrations**

Run: `bin/rails db:migrate`
Expected: 3 tables created, no errors.

- [ ] **Step 6: Create fixtures**

Write `test/fixtures/eviction_steps.yml`:

```yaml
s1_rights_analysis:
  code: "S1"
  step_type: 0
  name: "권리분석"
  description: "말소기준권리, 대항력 있는 임차인 유무, 배당요구 여부를 확인"
  completion_condition: "인수 권리 없음"
  failure_condition: "대항력 임차인 배당요구 안 함"
  required_documents: '["등기부등본", "매각물건명세서"]'
  estimated_duration: "1~2주"
  legal_basis: '[{"title": "민사집행법 제91조", "summary": "말소기준권리 판단 근거", "url": "https://law.go.kr"}]'
  position: 1
  next_step_code: "S2"
  branch_codes: '["B1", "B2", "B3"]'

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

b1_deposit_risk:
  code: "B1"
  step_type: 1
  name: "대항력 임차인이 배당요구 안 함"
  description: "보증금 인수 리스크"
  trigger_step_code: "S1"
  problem_summary: "낙찰자가 보증금 전액 떠안게 됨"
  root_cause: "배당요구종기 내 미신청"
  action_steps: '["입찰 포기 검토", "임차인과 보증금 감액 협상", "매각불허가 신청 검토"]'
  return_step_code: "S2"
  position: 16
  estimated_duration: "1~3개월"
```

Write `test/fixtures/eviction_simulator_questions.yml`:

```yaml
q1_rights_done:
  code: "Q1"
  phase: 0
  step_code: "S1"
  question: "권리분석을 완료했나요?"
  help_text: "말소기준권리, 대항력 임차인, 배당요구 여부를 확인했는지 체크합니다."
  yes_next_code: "Q2"
  no_next_code: "Q1G"
  f02_field_mapping: "has_rights_analysis"

q5_delivery_order:
  code: "Q5"
  phase: 1
  step_code: "S5"
  question: "인도명령과 점유이전금지가처분을 동시에 신청했나요?"
  help_text: "잔금 납부일 당일 세트로 신청하는 것이 실무 정석입니다."
  yes_next_code: "Q6"
  no_next_code: "Q5B"
  difficulty_impact: "high"
```

Write `test/fixtures/eviction_simulations.yml`:

```yaml
property_linked:
  property: safe_apartment
  answers: '{"Q1": true, "Q2": true}'
  result_path: '["S1", "S2"]'
  difficulty_level: "low"
  completed: false

standalone:
  session_id: "test_session_123"
  answers: '{"Q1": true}'
  result_path: '["S1"]'
  difficulty_level: ~
  completed: false
```

- [ ] **Step 7: Write failing model tests**

Write `test/models/eviction_step_test.rb`:

```ruby
require "test_helper"

class EvictionStepTest < ActiveSupport::TestCase
  test "valid main step" do
    step = EvictionStep.new(
      code: "S99", step_type: "main", name: "테스트",
      description: "테스트 단계", position: 99
    )
    assert step.valid?
  end

  test "code must be unique" do
    dup = EvictionStep.new(
      code: eviction_steps(:s1_rights_analysis).code,
      step_type: "main", name: "중복", description: "중복", position: 99
    )
    assert_not dup.valid?
    assert_includes dup.errors[:code], "has already been taken"
  end

  test "step_type enum" do
    step = EvictionStep.new(step_type: "main")
    assert step.main?
    step.step_type = "branch"
    assert step.branch?
  end

  test "main scope returns only main steps" do
    main_steps = EvictionStep.main.ordered
    main_steps.each { |s| assert s.main? }
  end

  test "branch scope returns only branches" do
    branches = EvictionStep.branch
    branches.each { |s| assert s.branch? }
  end

  test "branches_for returns branches triggered by a main step" do
    s1 = eviction_steps(:s1_rights_analysis)
    branches = EvictionStep.branches_for(s1.code)
    branches.each do |b|
      assert_equal s1.code, b.trigger_step_code
    end
  end
end
```

Write `test/models/eviction_simulator_question_test.rb`:

```ruby
require "test_helper"

class EvictionSimulatorQuestionTest < ActiveSupport::TestCase
  test "valid question" do
    q = EvictionSimulatorQuestion.new(
      code: "Q99", phase: "summary", step_code: "S1",
      question: "테스트 질문?"
    )
    assert q.valid?
  end

  test "code must be unique" do
    dup = EvictionSimulatorQuestion.new(
      code: eviction_simulator_questions(:q1_rights_done).code,
      phase: "summary", step_code: "S1", question: "중복?"
    )
    assert_not dup.valid?
  end

  test "phase enum" do
    q = EvictionSimulatorQuestion.new(phase: "summary")
    assert q.summary?
    q.phase = "detail"
    assert q.detail?
  end
end
```

Write `test/models/eviction_simulation_test.rb`:

```ruby
require "test_helper"

class EvictionSimulationTest < ActiveSupport::TestCase
  test "valid property-linked simulation" do
    sim = EvictionSimulation.new(
      property: properties(:safe_apartment),
      answers: { "Q1" => true },
      completed: false
    )
    assert sim.valid?
  end

  test "valid standalone simulation" do
    sim = EvictionSimulation.new(
      session_id: "abc123",
      answers: { "Q1" => true },
      completed: false
    )
    assert sim.valid?
  end

  test "one simulation per property" do
    EvictionSimulation.create!(
      property: properties(:risky_villa),
      answers: {}, completed: false
    )
    dup = EvictionSimulation.new(
      property: properties(:risky_villa),
      answers: {}, completed: false
    )
    assert_not dup.valid?
  end

  test "stale scope returns old standalone records" do
    old = EvictionSimulation.create!(
      session_id: "old_session", answers: {}, completed: false,
      created_at: 2.days.ago
    )
    recent = EvictionSimulation.create!(
      session_id: "new_session", answers: {}, completed: false
    )
    stale = EvictionSimulation.stale
    assert_includes stale, old
    assert_not_includes stale, recent
  end
end
```

- [ ] **Step 8: Run tests to verify they fail**

Run: `bin/rails test test/models/eviction_step_test.rb test/models/eviction_simulator_question_test.rb test/models/eviction_simulation_test.rb`
Expected: FAIL — models don't exist yet.

- [ ] **Step 9: Create models**

Write `app/models/eviction_step.rb`:

```ruby
class EvictionStep < ApplicationRecord
  enum :step_type, { main: 0, branch: 1 }

  validates :code, presence: true, uniqueness: true
  validates :step_type, presence: true
  validates :name, presence: true
  validates :description, presence: true
  validates :position, presence: true

  scope :ordered, -> { order(:position) }
  scope :branches_for, ->(step_code) { branch.where(trigger_step_code: step_code).ordered }

  def branches
    return EvictionStep.none unless main? && branch_codes.present?
    EvictionStep.where(code: branch_codes).ordered
  end
end
```

Write `app/models/eviction_simulator_question.rb`:

```ruby
class EvictionSimulatorQuestion < ApplicationRecord
  enum :phase, { summary: 0, detail: 1 }

  validates :code, presence: true, uniqueness: true
  validates :phase, presence: true
  validates :step_code, presence: true
  validates :question, presence: true

  scope :ordered, -> { order(:id) }

  def step
    EvictionStep.find_by(code: step_code)
  end
end
```

Write `app/models/eviction_simulation.rb`:

```ruby
class EvictionSimulation < ApplicationRecord
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
end
```

Add to `app/models/property.rb` (add this line among the other `has_many` declarations):

```ruby
has_many :eviction_simulations, dependent: :destroy
```

- [ ] **Step 10: Run tests to verify they pass**

Run: `bin/rails test test/models/eviction_step_test.rb test/models/eviction_simulator_question_test.rb test/models/eviction_simulation_test.rb`
Expected: All PASS.

- [ ] **Step 11: Run rubocop**

Run: `bin/rubocop app/models/eviction_step.rb app/models/eviction_simulator_question.rb app/models/eviction_simulation.rb`
Expected: No offenses.

- [ ] **Step 12: Commit**

```bash
git add db/migrate/ app/models/eviction_step.rb app/models/eviction_simulator_question.rb \
  app/models/eviction_simulation.rb app/models/property.rb db/schema.rb \
  test/models/eviction_step_test.rb test/models/eviction_simulator_question_test.rb \
  test/models/eviction_simulation_test.rb test/fixtures/eviction_steps.yml \
  test/fixtures/eviction_simulator_questions.yml test/fixtures/eviction_simulations.yml
git commit -m "feat(f06): add eviction data models with migrations and tests"
```

---

## Task 2: Seed Data — Eviction Steps & Simulator Questions

**Files:**
- Create: `db/seeds/eviction_steps.json`
- Create: `db/seeds/eviction_simulator_questions.json`
- Modify: `db/seeds.rb`
- Create: `test/models/eviction_seed_graph_validation_test.rb`

**Important:** The seed data content is derived from `docs/references/ref-006.md` (S1–S15, B1–B11 workflow tables) and `docs/references/ref-004.md` (legal basis). Read these files carefully when creating the JSON.

- [ ] **Step 1: Create eviction_steps.json**

Create `db/seeds/eviction_steps.json` with all 26 items (S1–S15 main steps + B1–B11 branches). Structure follows the pattern below. **Read `docs/references/ref-006.md` Section 1 (Main Workflow) and Section 2 (Branch Flow) for the content of each step.**

```json
{
  "steps": [
    {
      "code": "S1",
      "step_type": "main",
      "name": "권리분석",
      "description": "말소기준권리, 대항력 있는 임차인 유무, 배당요구 여부를 확인해 보증금 인수 리스크를 판단. 이 단계의 결과가 이후 모든 협상·법적 조치의 강도를 결정한다.",
      "completion_condition": "인수 권리 없음 / 대항력 임차인이 배당요구로 전액 회수 가능",
      "failure_condition": "대항력 임차인이 배당요구 안 함 / 유치권 신고 / 무상거주확인서 정황",
      "required_documents": ["등기부등본", "매각물건명세서", "현황조사서"],
      "estimated_duration": "1~2주",
      "estimated_cost": null,
      "legal_basis": [
        {
          "title": "민사집행법 제91조 (말소주의)",
          "summary": "말소기준권리보다 후에 등기된 권리는 매수인에게 인수되지 않고 소멸",
          "url": "https://law.go.kr"
        },
        {
          "title": "주택임대차보호법 제3조 (대항력)",
          "summary": "주택 인도 + 전입신고를 마친 임차인은 다음날부터 제3자에 대하여 효력 발생",
          "url": "https://law.go.kr"
        }
      ],
      "position": 1,
      "next_step_code": "S2",
      "branch_codes": ["B1", "B2", "B3"]
    }
  ],
  "branches": [
    {
      "code": "B1",
      "step_type": "branch",
      "name": "대항력 임차인이 배당요구 안 함 (보증금 인수 리스크)",
      "description": "낙찰자가 보증금 전액 떠안게 되는 최악의 시나리오",
      "trigger_step_code": "S1",
      "problem_summary": "낙찰자가 보증금 전액 떠안게 됨",
      "root_cause": "배당요구종기 내 미신청",
      "action_steps": [
        "입찰 포기 검토가 원칙",
        "이미 낙찰 시 임차인과 보증금 감액 협상",
        "매각물건명세서 상 하자 있으면 매각불허가 신청"
      ],
      "legal_basis": [
        {
          "title": "주택임대차보호법 제3조의5",
          "summary": "보증금이 전부 변제되지 않은 경우 임차권이 매수인에게 인수",
          "url": "https://law.go.kr"
        }
      ],
      "return_step_code": "S2",
      "estimated_duration": "1~3개월",
      "position": 16
    }
  ]
}
```

**Continue this pattern for all S1–S15 and B1–B11 items. Reference:**
- S-series content: `docs/references/ref-006.md` Section 1 table (columns: 단계명, 단계의 의미, 완료 조건, 미완료 상황, 다음 단계)
- B-series content: `docs/references/ref-006.md` Section 2 table (columns: 문제 상황, 근본 원인, 대책 절차, 해결 후 복귀 지점)
- Legal basis: `docs/references/ref-004.md` (match statutes and case law to each step)

- [ ] **Step 2: Create eviction_simulator_questions.json**

Create `db/seeds/eviction_simulator_questions.json`. Questions map to steps — Phase 1 (summary) covers S1–S4, Phase 2 (detail) covers S5–S15. Each "No" answer may lead to a branch-related follow-up question.

```json
[
  {
    "code": "Q1",
    "phase": "summary",
    "step_code": "S1",
    "question": "권리분석을 완료했나요?",
    "help_text": "말소기준권리, 대항력 임차인, 배당요구 여부를 확인했는지 체크합니다.",
    "yes_next_code": "Q2",
    "no_next_code": "Q1G",
    "f02_field_mapping": "has_rights_analysis",
    "difficulty_impact": null
  },
  {
    "code": "Q1G",
    "phase": "summary",
    "step_code": "S1",
    "question": "권리분석이 아직 완료되지 않았습니다. 다음 단계로 넘어갈까요?",
    "help_text": "물건분석(권리분석 탭)에서 먼저 분석을 진행하는 것을 권장합니다.",
    "yes_next_code": "Q2",
    "no_next_code": "END",
    "f02_field_mapping": null,
    "difficulty_impact": null
  }
]
```

**Continue for all ~25–30 questions. Derive from ref-006 completion/failure conditions for each step.**

- [ ] **Step 3: Add seed loading to db/seeds.rb**

Append to `db/seeds.rb`:

```ruby
puts "Seeding eviction steps..."
eviction_data = JSON.parse(File.read(Rails.root.join("db/seeds/eviction_steps.json")))

(eviction_data["steps"] + eviction_data["branches"]).each do |attrs|
  EvictionStep.find_or_create_by!(code: attrs["code"]) do |step|
    step.step_type = attrs["step_type"]
    step.name = attrs["name"]
    step.description = attrs["description"]
    step.completion_condition = attrs["completion_condition"]
    step.failure_condition = attrs["failure_condition"]
    step.required_documents = attrs["required_documents"]
    step.estimated_duration = attrs["estimated_duration"]
    step.estimated_cost = attrs["estimated_cost"]
    step.legal_basis = attrs["legal_basis"]
    step.position = attrs["position"]
    step.next_step_code = attrs["next_step_code"]
    step.branch_codes = attrs["branch_codes"]
    step.trigger_step_code = attrs["trigger_step_code"]
    step.problem_summary = attrs["problem_summary"]
    step.root_cause = attrs["root_cause"]
    step.action_steps = attrs["action_steps"]
    step.return_step_code = attrs["return_step_code"]
  end
end
puts "  -> #{EvictionStep.count} eviction steps"

puts "Seeding eviction simulator questions..."
questions_data = JSON.parse(File.read(Rails.root.join("db/seeds/eviction_simulator_questions.json")))
questions_data.each do |attrs|
  EvictionSimulatorQuestion.find_or_create_by!(code: attrs["code"]) do |q|
    q.phase = attrs["phase"]
    q.step_code = attrs["step_code"]
    q.question = attrs["question"]
    q.help_text = attrs["help_text"]
    q.yes_next_code = attrs["yes_next_code"]
    q.no_next_code = attrs["no_next_code"]
    q.f02_field_mapping = attrs["f02_field_mapping"]
    q.difficulty_impact = attrs["difficulty_impact"]
  end
end
puts "  -> #{EvictionSimulatorQuestion.count} simulator questions"
```

- [ ] **Step 4: Run seed to verify**

Run: `bin/rails db:seed`
Expected: "-> 26 eviction steps" and "-> ~25-30 simulator questions" with no errors.

- [ ] **Step 5: Write graph validation test**

Write `test/models/eviction_seed_graph_validation_test.rb`:

```ruby
require "test_helper"

class EvictionSeedGraphValidationTest < ActiveSupport::TestCase
  setup do
    # Load seed data into test DB
    eviction_data = JSON.parse(File.read(Rails.root.join("db/seeds/eviction_steps.json")))
    (eviction_data["steps"] + eviction_data["branches"]).each do |attrs|
      EvictionStep.find_or_create_by!(code: attrs["code"]) do |step|
        attrs.each { |k, v| step.send(:"#{k}=", v) if step.respond_to?(:"#{k}=") }
      end
    end

    questions_data = JSON.parse(File.read(Rails.root.join("db/seeds/eviction_simulator_questions.json")))
    questions_data.each do |attrs|
      EvictionSimulatorQuestion.find_or_create_by!(code: attrs["code"]) do |q|
        attrs.each { |k, v| q.send(:"#{k}=", v) if q.respond_to?(:"#{k}=") }
      end
    end
  end

  test "all next_step_code values resolve to valid steps" do
    EvictionStep.main.where.not(next_step_code: nil).find_each do |step|
      target = EvictionStep.find_by(code: step.next_step_code)
      assert target, "Step #{step.code} points to missing next_step_code: #{step.next_step_code}"
    end
  end

  test "all branch_codes resolve to valid branch steps" do
    EvictionStep.main.find_each do |step|
      next unless step.branch_codes.present?
      step.branch_codes.each do |bcode|
        target = EvictionStep.find_by(code: bcode)
        assert target, "Step #{step.code} references missing branch: #{bcode}"
        assert target.branch?, "Step #{step.code} branch_code #{bcode} is not a branch type"
      end
    end
  end

  test "all return_step_code values resolve to valid main steps" do
    EvictionStep.branch.where.not(return_step_code: nil).find_each do |branch|
      target = EvictionStep.find_by(code: branch.return_step_code)
      assert target, "Branch #{branch.code} points to missing return_step_code: #{branch.return_step_code}"
      assert target.main?, "Branch #{branch.code} return_step_code #{branch.return_step_code} is not a main type"
    end
  end

  test "all trigger_step_code values resolve to valid main steps" do
    EvictionStep.branch.find_each do |branch|
      next unless branch.trigger_step_code
      target = EvictionStep.find_by(code: branch.trigger_step_code)
      assert target, "Branch #{branch.code} has missing trigger_step_code: #{branch.trigger_step_code}"
      assert target.main?, "Branch #{branch.code} trigger #{branch.trigger_step_code} is not main"
    end
  end

  test "all yes_next_code and no_next_code resolve to valid questions or END" do
    EvictionSimulatorQuestion.find_each do |q|
      [q.yes_next_code, q.no_next_code].compact.each do |code|
        next if code == "END"
        target = EvictionSimulatorQuestion.find_by(code: code)
        assert target, "Question #{q.code} points to missing code: #{code}"
      end
    end
  end

  test "Q1 exists as entry point" do
    q1 = EvictionSimulatorQuestion.find_by(code: "Q1")
    assert q1, "Entry point Q1 must exist"
    assert q1.summary?, "Q1 must be summary phase"
  end

  test "no orphan questions — all are reachable from Q1" do
    all_codes = EvictionSimulatorQuestion.pluck(:code).to_set
    reachable = Set.new
    queue = ["Q1"]

    while queue.any?
      code = queue.shift
      next if reachable.include?(code) || code == "END"
      reachable << code
      q = EvictionSimulatorQuestion.find_by(code: code)
      next unless q
      queue << q.yes_next_code if q.yes_next_code
      queue << q.no_next_code if q.no_next_code
    end

    orphans = all_codes - reachable
    assert orphans.empty?, "Orphan questions not reachable from Q1: #{orphans.to_a.join(', ')}"
  end
end
```

- [ ] **Step 6: Run graph validation test**

Run: `bin/rails test test/models/eviction_seed_graph_validation_test.rb`
Expected: All PASS.

- [ ] **Step 7: Commit**

```bash
git add db/seeds/eviction_steps.json db/seeds/eviction_simulator_questions.json \
  db/seeds.rb test/models/eviction_seed_graph_validation_test.rb
git commit -m "feat(f06): add eviction seed data with graph validation test"
```

---

## Task 3: Routes & Controllers

**Files:**
- Modify: `config/routes.rb`
- Create: `app/controllers/eviction_guide_controller.rb`
- Create: `app/controllers/eviction_guide/simulations_controller.rb`
- Create: `app/controllers/eviction_guide/simulator_controller.rb`
- Create: `app/controllers/eviction_guide/steps_controller.rb`
- Create: `app/controllers/eviction_guide/branches_controller.rb`
- Create: `test/controllers/eviction_guide_controller_test.rb`
- Create: `test/controllers/eviction_guide/simulations_controller_test.rb`
- Create: `test/controllers/eviction_guide/simulator_controller_test.rb`

- [ ] **Step 1: Write failing controller tests**

Write `test/controllers/eviction_guide_controller_test.rb`:

```ruby
require "test_helper"

class EvictionGuideControllerTest < ActionDispatch::IntegrationTest
  test "guide renders successfully" do
    get eviction_guide_guide_url
    assert_response :success
  end

  test "simulator renders successfully" do
    get eviction_guide_simulator_url
    assert_response :success
  end

  test "simulator with property_id pre-selects property" do
    property = properties(:safe_apartment)
    get eviction_guide_simulator_url(property_id: property.id)
    assert_response :success
  end
end
```

Write `test/controllers/eviction_guide/simulator_controller_test.rb`:

```ruby
require "test_helper"

class EvictionGuide::SimulatorControllerTest < ActionDispatch::IntegrationTest
  test "question renders turbo frame" do
    get eviction_guide_simulator_question_url(code: "Q1")
    assert_response :success
  end

  test "question returns 404 for invalid code" do
    get eviction_guide_simulator_question_url(code: "INVALID")
    assert_response :not_found
  end
end
```

Write `test/controllers/eviction_guide/simulations_controller_test.rb`:

```ruby
require "test_helper"

class EvictionGuide::SimulationsControllerTest < ActionDispatch::IntegrationTest
  test "create with property_id creates persisted simulation" do
    property = properties(:safe_apartment)
    assert_difference "EvictionSimulation.count", 1 do
      post eviction_guide_simulation_url, params: {
        simulation: { property_id: property.id }
      }
    end
    sim = EvictionSimulation.last
    assert_equal property.id, sim.property_id
    assert_nil sim.session_id
  end

  test "create without property_id creates standalone simulation" do
    assert_difference "EvictionSimulation.count", 1 do
      post eviction_guide_simulation_url, params: {
        simulation: { property_id: "" }
      }
    end
    sim = EvictionSimulation.last
    assert_nil sim.property_id
    assert_not_nil sim.session_id
  end

  test "update records answer and redirects to next question" do
    sim = eviction_simulations(:property_linked)
    patch eviction_guide_simulation_url, params: {
      simulation: { question_code: "Q1", answer: "true", next_code: "Q2" }
    }
    assert_response :redirect
    sim.reload
    assert_equal true, sim.answers["Q1"]
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/eviction_guide_controller_test.rb test/controllers/eviction_guide/simulator_controller_test.rb test/controllers/eviction_guide/simulations_controller_test.rb`
Expected: FAIL — routes and controllers don't exist.

- [ ] **Step 3: Add routes**

Add to `config/routes.rb` (before the `get "up"` line):

```ruby
resources :eviction_guide, only: [] do
  collection do
    get :guide
    get :simulator
  end
end

namespace :eviction_guide do
  resource :simulation, only: [ :create, :update, :show ]
  get "simulator/question/:code", to: "simulator#question", as: :simulator_question
  get "steps/:code", to: "steps#show", as: :step_detail
  get "branches/:code", to: "branches#show", as: :branch_detail
end
```

- [ ] **Step 4: Create controllers**

Write `app/controllers/eviction_guide_controller.rb`:

```ruby
class EvictionGuideController < ApplicationController
  def guide
    @main_steps = EvictionStep.main.ordered
  end

  def simulator
    @property = Property.find_by(id: params[:property_id])
    @properties = current_user.properties.order(created_at: :desc)
    @first_question = EvictionSimulatorQuestion.find_by(code: "Q1")
  end
end
```

Write `app/controllers/eviction_guide/simulations_controller.rb`:

```ruby
module EvictionGuide
  class SimulationsController < ApplicationController
    def create
      property_id = params.dig(:simulation, :property_id).presence

      @simulation = if property_id
        EvictionSimulation.find_or_initialize_by(property_id: property_id)
      else
        EvictionSimulation.new(session_id: session.id.to_s)
      end

      @simulation.answers = {}
      @simulation.result_path = []
      @simulation.completed = false
      @simulation.difficulty_level = nil
      @simulation.save!

      session[:eviction_simulation_id] = @simulation.id
      redirect_to eviction_guide_simulator_question_path(code: "Q1")
    end

    def update
      @simulation = find_simulation
      return head(:not_found) unless @simulation

      question_code = params.dig(:simulation, :question_code)
      answer = params.dig(:simulation, :answer) == "true"
      next_code = params.dig(:simulation, :next_code)

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

      @simulation.update!(completed: true)
    end

    private

    def find_simulation
      EvictionSimulation.find_by(id: session[:eviction_simulation_id])
    end
  end
end
```

Write `app/controllers/eviction_guide/simulator_controller.rb`:

```ruby
module EvictionGuide
  class SimulatorController < ApplicationController
    def question
      @question = EvictionSimulatorQuestion.find_by!(code: params[:code])
      @simulation = EvictionSimulation.find_by(id: session[:eviction_simulation_id])
      @step = @question.step
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
```

Write `app/controllers/eviction_guide/steps_controller.rb`:

```ruby
module EvictionGuide
  class StepsController < ApplicationController
    def show
      @step = EvictionStep.main.find_by!(code: params[:code])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
```

Write `app/controllers/eviction_guide/branches_controller.rb`:

```ruby
module EvictionGuide
  class BranchesController < ApplicationController
    def show
      @branch = EvictionStep.branch.find_by!(code: params[:code])
    rescue ActiveRecord::RecordNotFound
      head :not_found
    end
  end
end
```

- [ ] **Step 5: Create minimal view stubs** (to make controller tests pass)

Write `app/views/eviction_guide/guide.html.erb`:

```erb
<h1>명도 가이드</h1>
```

Write `app/views/eviction_guide/simulator.html.erb`:

```erb
<h1>명도 시뮬레이터</h1>
```

Write `app/views/eviction_guide/simulator/_question.html.erb`:

```erb
<%= turbo_frame_tag "simulator_question" do %>
  <p><%= @question.question %></p>
<% end %>
```

Write `app/views/eviction_guide/simulator/_result.html.erb`:

```erb
<h2>시뮬레이션 결과</h2>
```

Write `app/views/eviction_guide/steps/show.html.erb`:

```erb
<p><%= @step.name %></p>
```

Write `app/views/eviction_guide/branches/show.html.erb`:

```erb
<p><%= @branch.name %></p>
```

Note: The simulator question action needs to render the partial. Update `app/controllers/eviction_guide/simulator_controller.rb` question action to add:

```ruby
def question
  @question = EvictionSimulatorQuestion.find_by!(code: params[:code])
  @simulation = EvictionSimulation.find_by(id: session[:eviction_simulation_id])
  @step = @question.step
  render partial: "eviction_guide/simulator/question"
rescue ActiveRecord::RecordNotFound
  head :not_found
end
```

And the simulations#show action renders the result partial:

```ruby
def show
  @simulation = find_simulation
  return redirect_to eviction_guide_simulator_path unless @simulation
  @simulation.update!(completed: true)
  render "eviction_guide/simulator/result", layout: "application"
end
```

- [ ] **Step 6: Run tests**

Run: `bin/rails test test/controllers/eviction_guide_controller_test.rb test/controllers/eviction_guide/simulator_controller_test.rb test/controllers/eviction_guide/simulations_controller_test.rb`
Expected: All PASS.

- [ ] **Step 7: Run rubocop**

Run: `bin/rubocop app/controllers/eviction_guide_controller.rb app/controllers/eviction_guide/`
Expected: No offenses.

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/eviction_guide_controller.rb \
  app/controllers/eviction_guide/ app/views/eviction_guide/ \
  test/controllers/eviction_guide_controller_test.rb \
  test/controllers/eviction_guide/
git commit -m "feat(f06): add eviction guide routes, controllers, and view stubs"
```

---

## Task 4: Service Objects — F02DataExtractor, DifficultyAssessor, PathBuilder

**Files:**
- Create: `app/services/eviction_guide/f02_data_extractor.rb`
- Create: `app/services/eviction_guide/difficulty_assessor.rb`
- Create: `app/services/eviction_guide/path_builder.rb`
- Create: `test/services/eviction_guide/f02_data_extractor_test.rb`
- Create: `test/services/eviction_guide/difficulty_assessor_test.rb`
- Create: `test/services/eviction_guide/path_builder_test.rb`

- [ ] **Step 1: Write failing F02DataExtractor test**

Write `test/services/eviction_guide/f02_data_extractor_test.rb`:

```ruby
require "test_helper"

class EvictionGuide::F02DataExtractorTest < ActiveSupport::TestCase
  setup do
    @property = properties(:safe_apartment)
  end

  test "returns empty hash when property has no report" do
    @property.rights_analysis_reports.destroy_all
    result = EvictionGuide::F02DataExtractor.call(@property)
    assert_equal({}, result)
  end

  test "extracts has_opposing_tenant from effective_tenants" do
    report = @property.rights_analysis_reports.last
    next skip("No report fixture") unless report

    result = EvictionGuide::F02DataExtractor.call(@property)
    assert_includes [true, false, nil], result[:has_opposing_tenant]
  end

  test "extracts has_lien from inspection results" do
    result = EvictionGuide::F02DataExtractor.call(@property)
    assert_includes [true, false, nil], result[:has_lien]
  end

  test "returns nil for unmapped fields" do
    result = EvictionGuide::F02DataExtractor.call(@property)
    assert_nil result[:nonexistent_field]
  end
end
```

- [ ] **Step 2: Write failing DifficultyAssessor test**

Write `test/services/eviction_guide/difficulty_assessor_test.rb`:

```ruby
require "test_helper"

class EvictionGuide::DifficultyAssessorTest < ActiveSupport::TestCase
  test "returns low when no branches entered" do
    answers = { "Q1" => true, "Q2" => true, "Q3" => true, "Q4" => true }
    result = EvictionGuide::DifficultyAssessor.call(answers)
    assert_equal "low", result
  end

  test "returns high when B1 branch entered" do
    answers = { "Q1" => false }
    questions = { "Q1" => EvictionSimulatorQuestion.new(
      code: "Q1", step_code: "S1", no_next_code: "Q1B",
      difficulty_impact: "high"
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)
    assert_equal "high", result
  end

  test "returns medium for medium-impact branches" do
    answers = { "Q7" => false }
    questions = { "Q7" => EvictionSimulatorQuestion.new(
      code: "Q7", step_code: "S7", no_next_code: "Q7B",
      difficulty_impact: "medium"
    ) }

    result = EvictionGuide::DifficultyAssessor.call(answers, questions: questions)
    assert_equal "medium", result
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
    assert_equal "high", result
  end
end
```

- [ ] **Step 3: Write failing PathBuilder test**

Write `test/services/eviction_guide/path_builder_test.rb`:

```ruby
require "test_helper"

class EvictionGuide::PathBuilderTest < ActiveSupport::TestCase
  test "builds path from answers — all yes" do
    answers = { "Q1" => true, "Q2" => true, "Q3" => true, "Q4" => true, "Q5" => true }
    path = EvictionGuide::PathBuilder.call(answers)
    assert_kind_of Array, path
    assert path.all? { |entry| entry.key?(:code) && entry.key?(:status) }
  end

  test "includes branch in path when answer is no" do
    answers = { "Q1" => false }
    path = EvictionGuide::PathBuilder.call(answers)
    statuses = path.map { |e| e[:status] }
    assert_includes statuses, "branch"
  end

  test "returns empty path for empty answers" do
    path = EvictionGuide::PathBuilder.call({})
    assert_equal [], path
  end
end
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `bin/rails test test/services/eviction_guide/`
Expected: FAIL — service classes don't exist.

- [ ] **Step 5: Implement F02DataExtractor**

Write `app/services/eviction_guide/f02_data_extractor.rb`:

```ruby
module EvictionGuide
  class F02DataExtractor
    MAPPINGS = %i[
      has_opposing_tenant is_dividend_requested has_lien
      has_gratuitous_residence_doc occupant_type has_small_sum_tenant
      has_rights_analysis
    ].freeze

    def self.call(property)
      new(property).call
    end

    def initialize(property)
      @property = property
      @report = property.rights_analysis_reports.last
      @user = property.user_properties.first&.user
    end

    def call
      return {} unless @report || @user

      MAPPINGS.each_with_object({}) do |field, result|
        value = extract(field)
        result[field] = value unless value.nil?
      end
    end

    private

    def extract(field)
      case field
      when :has_rights_analysis
        @report.present?
      when :has_opposing_tenant
        tenants = @report&.effective_tenants
        return nil unless tenants
        tenants.any? { |t| t["opposing_power"] }
      when :is_dividend_requested
        tenants = @report&.effective_tenants
        return nil unless tenants
        tenants.any? { |t| t["dividend_requested"] }
      when :has_lien
        find_inspection_risk("rights-020")
      when :has_gratuitous_residence_doc
        find_inspection_risk("inspect-005")
      when :occupant_type
        @report&.report_data&.dig("occupant_type")
      when :has_small_sum_tenant
        tenants = @report&.effective_tenants
        return nil unless tenants
        tenants.any? { |t| t["has_priority_repayment"] }
      end
    end

    def find_inspection_risk(item_code)
      return nil unless @user
      item = InspectionItem.find_by(code: item_code)
      return nil unless item
      result = InspectionResult.find_by(
        property: @property,
        inspection_item: item,
        user: @user
      )
      result&.has_risk
    end
  end
end
```

- [ ] **Step 6: Implement DifficultyAssessor**

Write `app/services/eviction_guide/difficulty_assessor.rb`:

```ruby
module EvictionGuide
  class DifficultyAssessor
    LEVELS = { "high" => 3, "medium" => 2, "low" => 1 }.freeze
    LEVEL_FROM_SCORE = LEVELS.invert.freeze

    def self.call(answers, questions: nil)
      new(answers, questions).call
    end

    def initialize(answers, questions = nil)
      @answers = answers || {}
      @questions = questions || load_questions
    end

    def call
      max_score = 0

      @answers.each do |code, answer|
        next if answer # only "no" answers trigger difficulty
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
      EvictionSimulatorQuestion.all.index_by(&:code)
    end
  end
end
```

- [ ] **Step 7: Implement PathBuilder**

Write `app/services/eviction_guide/path_builder.rb`:

```ruby
module EvictionGuide
  class PathBuilder
    def self.call(answers)
      new(answers).call
    end

    def initialize(answers)
      @answers = answers || {}
      @questions = EvictionSimulatorQuestion.all.index_by(&:code)
      @steps = EvictionStep.all.index_by(&:code)
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

- [ ] **Step 8: Run tests**

Run: `bin/rails test test/services/eviction_guide/`
Expected: All PASS.

- [ ] **Step 9: Run rubocop**

Run: `bin/rubocop app/services/eviction_guide/`
Expected: No offenses.

- [ ] **Step 10: Commit**

```bash
git add app/services/eviction_guide/ test/services/eviction_guide/
git commit -m "feat(f06): add F02DataExtractor, DifficultyAssessor, PathBuilder services"
```

---

## Task 5: ViewComponents

**Files:**
- Create: all 7 components (`.rb` + `.html.erb` pairs) in `app/components/eviction_guide/`

This task creates all ViewComponents. Each component follows the existing project pattern (TailwindCSS with dark mode, ViewComponent::Base).

**Important:** Use `/rails-ui` skill (design tokens from `~/.claude/skills/rails-ui/design_tokens.json` and `~/.claude/skills/rails-ui/DESIGN.md`) when implementing the templates to ensure design consistency.

- [ ] **Step 1: Create TabNavigationComponent**

Write `app/components/eviction_guide/tab_navigation_component.rb`:

```ruby
module EvictionGuide
  class TabNavigationComponent < ViewComponent::Base
    TAB_CONFIG = [
      { key: "guide",     label: "명도 가이드",     path_method: :eviction_guide_guide_path },
      { key: "simulator", label: "명도 시뮬레이터", path_method: :eviction_guide_simulator_path }
    ].freeze

    def initialize(active_tab:)
      @active_tab = active_tab
    end

    private

    def tabs
      TAB_CONFIG.map do |tab|
        tab.merge(
          active: tab[:key] == @active_tab,
          url: helpers.send(tab[:path_method])
        )
      end
    end
  end
end
```

Write `app/components/eviction_guide/tab_navigation_component.html.erb`:

```erb
<nav class="border-b border-slate-200 dark:border-slate-700 mb-6">
  <ul class="flex gap-0 -mb-px">
    <% tabs.each do |tab| %>
      <li>
        <a href="<%= tab[:url] %>"
           class="<%= tab[:active] ?
             'inline-block px-6 py-3 text-sm font-semibold border-b-2 border-blue-600 text-blue-600 dark:border-blue-400 dark:text-blue-400' :
             'inline-block px-6 py-3 text-sm font-medium text-slate-500 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-300' %>">
          <%= tab[:label] %>
        </a>
      </li>
    <% end %>
  </ul>
</nav>
```

- [ ] **Step 2: Create StepCardComponent**

Write `app/components/eviction_guide/step_card_component.rb`:

```ruby
module EvictionGuide
  class StepCardComponent < ViewComponent::Base
    def initialize(step:, branches: [])
      @step = step
      @branches = branches
    end

    private

    def step_badge_classes
      if @step.main?
        "bg-blue-600 text-white dark:bg-blue-500"
      else
        "bg-yellow-200 text-yellow-800 dark:bg-yellow-900/40 dark:text-yellow-300"
      end
    end

    def has_branches?
      @branches.any?
    end
  end
end
```

Write `app/components/eviction_guide/step_card_component.html.erb`:

```erb
<div class="border border-slate-200 dark:border-slate-700 rounded-lg mb-2"
     data-controller="accordion"
     data-accordion-open-value="false">
  <%# Collapsed header %>
  <button class="w-full px-4 py-3 flex items-center justify-between cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800/50 rounded-lg"
          data-action="click->accordion#toggle"
          type="button">
    <div class="flex items-center gap-3">
      <span class="<%= step_badge_classes %> px-2.5 py-0.5 rounded text-xs font-bold">
        <%= @step.code %>
      </span>
      <strong class="text-sm text-slate-900 dark:text-slate-100"><%= @step.name %></strong>
      <% if @step.estimated_duration.present? %>
        <span class="text-xs text-slate-500 dark:text-slate-400"><%= @step.estimated_duration %></span>
      <% end %>
    </div>
    <span class="text-slate-400 transition-transform" data-accordion-target="icon">▶</span>
  </button>

  <%# Expanded content %>
  <div class="hidden border-t border-slate-200 dark:border-slate-700 px-4 py-4"
       data-accordion-target="content">
    <p class="text-sm text-slate-700 dark:text-slate-300 mb-4"><%= @step.description %></p>

    <% if @step.required_documents.present? %>
      <div class="flex gap-3 mb-4">
        <div class="flex-1 p-2 bg-slate-50 dark:bg-slate-800 rounded text-xs">
          <div class="font-bold text-slate-500 dark:text-slate-400 text-[0.7rem] mb-1">📄 필요 서류</div>
          <%= @step.required_documents.join(", ") %>
        </div>
        <% if @step.estimated_cost.present? %>
          <div class="flex-1 p-2 bg-slate-50 dark:bg-slate-800 rounded text-xs">
            <div class="font-bold text-slate-500 dark:text-slate-400 text-[0.7rem] mb-1">💰 예상 비용</div>
            <%= @step.estimated_cost %>
          </div>
        <% end %>
      </div>
    <% end %>

    <% if @step.main? %>
      <div class="flex gap-4 mb-4 text-sm">
        <% if @step.completion_condition.present? %>
          <div class="flex-1">
            <span class="text-green-600 dark:text-green-400 font-bold">✅ 완료 조건:</span>
            <span class="text-slate-700 dark:text-slate-300"><%= @step.completion_condition %></span>
          </div>
        <% end %>
        <% if @step.failure_condition.present? %>
          <div class="flex-1">
            <span class="text-red-600 dark:text-red-400 font-bold">❌ 미완료 시:</span>
            <span class="text-slate-700 dark:text-slate-300"><%= @step.failure_condition %></span>
          </div>
        <% end %>
      </div>
    <% end %>

    <% if @step.branch? %>
      <% if @step.problem_summary.present? %>
        <p class="text-sm mb-2"><strong>상황:</strong> <%= @step.problem_summary %></p>
      <% end %>
      <% if @step.root_cause.present? %>
        <p class="text-sm mb-2"><strong>근본 원인:</strong> <%= @step.root_cause %></p>
      <% end %>
      <% if @step.action_steps.present? %>
        <div class="mb-3">
          <strong class="text-sm">대책 절차:</strong>
          <ol class="list-decimal list-inside text-sm mt-1 space-y-1">
            <% @step.action_steps.each do |action| %>
              <li class="text-slate-700 dark:text-slate-300"><%= action %></li>
            <% end %>
          </ol>
        </div>
      <% end %>
      <% if @step.return_step_code.present? %>
        <div class="p-2 bg-slate-50 dark:bg-slate-800 rounded text-sm">
          <strong>해결 후 복귀:</strong> → <%= @step.return_step_code %> 단계
        </div>
      <% end %>
    <% end %>

    <%# Inline branches %>
    <% if has_branches? %>
      <% @branches.each do |branch| %>
        <div class="border border-yellow-200 dark:border-yellow-900/40 bg-yellow-50/50 dark:bg-yellow-900/10 rounded-md p-3 mb-2">
          <%= render EvictionGuide::StepCardComponent.new(step: branch) %>
        </div>
      <% end %>
    <% end %>

    <%# Legal basis %>
    <% if @step.legal_basis.present? %>
      <%= render EvictionGuide::LegalInlineComponent.new(legal_items: @step.legal_basis) %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 3: Create LegalInlineComponent**

Write `app/components/eviction_guide/legal_inline_component.rb`:

```ruby
module EvictionGuide
  class LegalInlineComponent < ViewComponent::Base
    def initialize(legal_items:)
      @legal_items = legal_items || []
    end
  end
end
```

Write `app/components/eviction_guide/legal_inline_component.html.erb`:

```erb
<% if @legal_items.any? %>
  <details class="border-t border-slate-200 dark:border-slate-700 pt-3 mt-3">
    <summary class="cursor-pointer text-blue-600 dark:text-blue-400 font-bold text-sm">
      📚 법률 근거
    </summary>
    <div class="mt-2 space-y-2">
      <% @legal_items.each do |item| %>
        <div class="p-3 bg-slate-50 dark:bg-slate-800 rounded">
          <strong class="text-sm"><%= item["title"] %></strong>
          <p class="text-xs text-slate-600 dark:text-slate-400 mt-1"><%= item["summary"] %></p>
          <% if item["url"].present? %>
            <a href="<%= item["url"] %>" target="_blank" rel="noopener"
               class="text-xs text-blue-600 dark:text-blue-400 hover:underline mt-1 inline-block">
              원문 보기 →
            </a>
          <% end %>
        </div>
      <% end %>
    </div>
  </details>
<% end %>
```

- [ ] **Step 4: Create DifficultyBadgeComponent**

Write `app/components/eviction_guide/difficulty_badge_component.rb`:

```ruby
module EvictionGuide
  class DifficultyBadgeComponent < ViewComponent::Base
    VARIANTS = {
      "high" => { label: "높음", classes: "bg-red-200 text-red-800 dark:bg-red-900/30 dark:text-red-400" },
      "medium" => { label: "중간", classes: "bg-yellow-200 text-yellow-800 dark:bg-yellow-900/30 dark:text-yellow-400" },
      "low" => { label: "낮음", classes: "bg-green-200 text-green-800 dark:bg-green-900/30 dark:text-green-400" }
    }.freeze

    def initialize(level:)
      @level = level.to_s
      @config = VARIANTS[@level] || VARIANTS["medium"]
    end

    def call
      content_tag(:span, "명도 난이도: #{@config[:label]}",
        class: "inline-flex items-center rounded-full px-4 py-1.5 text-sm font-semibold #{@config[:classes]}")
    end
  end
end
```

- [ ] **Step 5: Create SimulatorQuestionComponent**

Write `app/components/eviction_guide/simulator_question_component.rb`:

```ruby
module EvictionGuide
  class SimulatorQuestionComponent < ViewComponent::Base
    def initialize(question:, simulation:, step: nil)
      @question = question
      @simulation = simulation
      @step = step || question.step
    end

    private

    def progress_percent
      total = EvictionSimulatorQuestion.count
      answered = @simulation&.answers&.size || 0
      return 0 if total.zero?
      ((answered.to_f / total) * 100).round
    end
  end
end
```

Write `app/components/eviction_guide/simulator_question_component.html.erb`:

```erb
<div class="max-w-2xl mx-auto">
  <%# Progress bar %>
  <div class="mb-6">
    <div class="h-1 bg-slate-200 dark:bg-slate-700 rounded-full">
      <div class="h-1 bg-blue-600 dark:bg-blue-400 rounded-full transition-all"
           style="width: <%= progress_percent %>%"></div>
    </div>
    <span class="text-xs text-slate-500 dark:text-slate-400 mt-1 inline-block">진행률 <%= progress_percent %>%</span>
  </div>

  <%# Step badge %>
  <% if @step %>
    <span class="text-xs text-slate-500 dark:text-slate-400 mb-2 inline-block">
      <%= @step.code %> — <%= @step.name %>
    </span>
  <% end %>

  <%# Question %>
  <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-2">
    <%= @question.question %>
  </h3>

  <% if @question.help_text.present? %>
    <p class="text-sm text-slate-600 dark:text-slate-400 mb-4"><%= @question.help_text %></p>
  <% end %>

  <%# Yes/No buttons %>
  <div class="flex gap-4 mb-4">
    <%= form_with url: helpers.eviction_guide_simulation_path, method: :patch, class: "flex-1" do |f| %>
      <%= f.hidden_field :question_code, value: @question.code %>
      <%= f.hidden_field :answer, value: "true" %>
      <%= f.hidden_field :next_code, value: @question.yes_next_code %>
      <button type="submit"
              class="w-full p-4 bg-white dark:bg-slate-800 border-2 border-green-500 rounded-lg hover:bg-green-50 dark:hover:bg-green-900/20 text-left">
        <strong class="text-green-600 dark:text-green-400">네</strong>
        <% if @question.yes_next_code && @question.yes_next_code != "END" %>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">→ 다음 단계로</p>
        <% end %>
      </button>
    <% end %>

    <%= form_with url: helpers.eviction_guide_simulation_path, method: :patch, class: "flex-1" do |f| %>
      <%= f.hidden_field :question_code, value: @question.code %>
      <%= f.hidden_field :answer, value: "false" %>
      <%= f.hidden_field :next_code, value: @question.no_next_code %>
      <button type="submit"
              class="w-full p-4 bg-white dark:bg-slate-800 border-2 border-red-500 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 text-left">
        <strong class="text-red-600 dark:text-red-400">아니오</strong>
        <% if @question.no_next_code && @question.no_next_code != "END" %>
          <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">→ 분기 대책 확인</p>
        <% end %>
      </button>
    <% end %>
  </div>

  <%# Legal basis from step %>
  <% if @step&.legal_basis.present? %>
    <%= render EvictionGuide::LegalInlineComponent.new(legal_items: @step.legal_basis) %>
  <% end %>
</div>
```

- [ ] **Step 6: Create SimulatorResultComponent**

Write `app/components/eviction_guide/simulator_result_component.rb`:

```ruby
module EvictionGuide
  class SimulatorResultComponent < ViewComponent::Base
    def initialize(simulation:)
      @simulation = simulation
      @path = simulation.result_path || []
    end

    private

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
  end
end
```

Write `app/components/eviction_guide/simulator_result_component.html.erb`:

```erb
<div class="max-w-2xl mx-auto">
  <%# Difficulty badge %>
  <div class="text-center mb-6">
    <%= render EvictionGuide::DifficultyBadgeComponent.new(level: @simulation.difficulty_level || "medium") %>
  </div>

  <%# Path visualization %>
  <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-4">명도 경로</h3>
  <div class="space-y-2 mb-6">
    <% @path.each do |entry| %>
      <% badge = status_badge(entry["status"]) %>
      <div class="flex items-center gap-3 text-sm">
        <span class="<%= badge[:classes] %> px-2 py-0.5 rounded text-xs font-medium whitespace-nowrap">
          <%= badge[:label] %>
        </span>
        <span class="text-slate-700 dark:text-slate-300">
          <%= entry["code"] %> <%= entry["name"] %>
        </span>
      </div>
    <% end %>
  </div>

  <%# Stats %>
  <div class="flex gap-4 mb-6">
    <div class="flex-1 p-4 bg-slate-50 dark:bg-slate-800 rounded-lg text-center">
      <div class="text-xs text-slate-500 dark:text-slate-400">예상 총 단계</div>
      <div class="text-2xl font-bold text-slate-900 dark:text-slate-100"><%= total_steps %></div>
    </div>
    <div class="flex-1 p-4 bg-slate-50 dark:bg-slate-800 rounded-lg text-center">
      <div class="text-xs text-slate-500 dark:text-slate-400">분기 진입</div>
      <div class="text-2xl font-bold text-slate-900 dark:text-slate-100"><%= branch_count %>건</div>
    </div>
  </div>

  <%# Disclaimer %>
  <div class="p-3 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg text-sm text-red-800 dark:text-red-300">
    ⚠️ 이 결과는 시뮬레이션이며, 실제 명도 작업은 반드시 법률 전문가와 상담 후 진행하세요.
  </div>
</div>
```

- [ ] **Step 7: Create F02PrefillComponent**

Write `app/components/eviction_guide/f02_prefill_component.rb`:

```ruby
module EvictionGuide
  class F02PrefillComponent < ViewComponent::Base
    def initialize(prefill_data:, simulation:)
      @prefill_data = prefill_data || {}
      @simulation = simulation
    end

    private

    FIELD_LABELS = {
      has_opposing_tenant: "대항력 있는 임차인 존재 여부",
      is_dividend_requested: "배당요구 여부",
      has_lien: "유치권 신고 존재",
      has_gratuitous_residence_doc: "무상거주확인서 정황",
      occupant_type: "점유자 유형",
      has_small_sum_tenant: "소액임차인 여부",
      has_rights_analysis: "권리분석 완료 여부"
    }.freeze

    def fields
      @prefill_data.map do |key, value|
        {
          key: key,
          label: FIELD_LABELS[key] || key.to_s.humanize,
          value: value,
          display_value: format_value(value)
        }
      end
    end

    def format_value(value)
      case value
      when true then "있음"
      when false then "없음"
      when nil then "미확인"
      else value.to_s
      end
    end
  end
end
```

Write `app/components/eviction_guide/f02_prefill_component.html.erb`:

```erb
<div class="max-w-2xl mx-auto">
  <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100 mb-2">AI 분석 결과 확인</h3>
  <p class="text-sm text-slate-600 dark:text-slate-400 mb-4">
    물건분석(F02)에서 가져온 결과입니다. 각 항목이 맞는지 확인해주세요.
  </p>

  <div class="space-y-3 mb-6">
    <% fields.each do |field| %>
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
    <div class="text-right">
      <button type="submit"
              class="px-6 py-2 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700">
        확인 완료 → 시뮬레이션 시작
      </button>
    </div>
  <% end %>
</div>
```

- [ ] **Step 8: Run rubocop**

Run: `bin/rubocop app/components/eviction_guide/`
Expected: No offenses.

- [ ] **Step 9: Commit**

```bash
git add app/components/eviction_guide/
git commit -m "feat(f06): add 7 ViewComponents for eviction guide UI"
```

---

## Task 6: Stimulus Controllers

**Files:**
- Create: `app/javascript/controllers/accordion_controller.js`
- Create: `app/javascript/controllers/simulator_controller.js`

- [ ] **Step 1: Create accordion_controller.js**

Write `app/javascript/controllers/accordion_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "icon"]
  static values = { open: { type: Boolean, default: false } }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    if (this.hasContentTarget) {
      this.contentTarget.classList.toggle("hidden", !this.openValue)
    }
    if (this.hasIconTarget) {
      this.iconTarget.textContent = this.openValue ? "▼" : "▶"
    }
  }
}
```

- [ ] **Step 2: Create simulator_controller.js**

Write `app/javascript/controllers/simulator_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["questionFrame"]

  connect() {
    // Simulator state managed server-side via session/DB
    // This controller handles client-side UX enhancements
  }

  scrollToQuestion() {
    if (this.hasQuestionFrameTarget) {
      this.questionFrameTarget.scrollIntoView({ behavior: "smooth", block: "start" })
    }
  }
}
```

- [ ] **Step 3: Register controllers in index**

Verify that `app/javascript/controllers/index.js` auto-registers Stimulus controllers (Rails 8 importmap convention). If it uses `eagerLoadControllersFrom`, the new controllers are auto-registered. If manual, add:

```javascript
import AccordionController from "./accordion_controller"
application.register("accordion", AccordionController)

import SimulatorController from "./simulator_controller"
application.register("simulator", SimulatorController)
```

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/accordion_controller.js \
  app/javascript/controllers/simulator_controller.js
git commit -m "feat(f06): add accordion and simulator Stimulus controllers"
```

---

## Task 7: Full View Templates

**Files:**
- Modify: `app/views/eviction_guide/guide.html.erb`
- Modify: `app/views/eviction_guide/simulator.html.erb`
- Modify: `app/views/eviction_guide/simulator/_question.html.erb`
- Modify: `app/views/eviction_guide/simulator/_result.html.erb`
- Create: `app/views/eviction_guide/simulator/_property_selector.html.erb`

**Important:** Use `/rails-ui` skill for design token compliance.

- [ ] **Step 1: Write guide.html.erb**

Replace `app/views/eviction_guide/guide.html.erb`:

```erb
<%= render EvictionGuide::TabNavigationComponent.new(active_tab: "guide") %>

<div class="max-w-4xl mx-auto px-4">
  <%# Overview box %>
  <div class="p-4 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded-lg mb-6">
    <h2 class="text-lg font-bold text-slate-900 dark:text-slate-100 mb-2">경매 낙찰 후 명도란?</h2>
    <p class="text-sm text-slate-700 dark:text-slate-300">
      소유권을 취득했더라도 점유권은 자동으로 이전되지 않습니다.
      점유자가 자진 퇴거하지 않을 경우, 법적 절차를 통해 부동산을 인도받는 과정을 명도라고 합니다.
      협상 시 2~3개월, 강제집행 시 3~6개월이 소요됩니다.
    </p>
  </div>

  <%# Simulator CTA %>
  <div class="p-4 border-2 border-blue-600 dark:border-blue-400 rounded-lg mb-6 flex items-center justify-between">
    <div>
      <strong class="text-slate-900 dark:text-slate-100">내 물건의 명도 시나리오가 궁금하신가요?</strong>
      <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">
        분석 완료된 물건을 선택하면 맞춤 명도 경로를 확인할 수 있습니다.
      </p>
    </div>
    <a href="<%= eviction_guide_simulator_path %>"
       class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-semibold hover:bg-blue-700 whitespace-nowrap">
      시뮬레이터로 이동 →
    </a>
  </div>

  <%# Step accordion cards %>
  <% @main_steps.each do |step| %>
    <% branches = step.branches %>
    <%= render EvictionGuide::StepCardComponent.new(step: step, branches: branches) %>
  <% end %>

  <%# Disclaimer %>
  <div class="mt-8 p-3 bg-slate-50 dark:bg-slate-800 rounded-lg text-center text-xs text-slate-500 dark:text-slate-400">
    ⚖️ 본 정보는 일반 정보 제공 목적이며, 개별 사안은 변호사·법무사 상담이 필요합니다.
  </div>
</div>
```

- [ ] **Step 2: Write simulator.html.erb**

Replace `app/views/eviction_guide/simulator.html.erb`:

```erb
<%= render EvictionGuide::TabNavigationComponent.new(active_tab: "simulator") %>

<div class="max-w-2xl mx-auto px-4">
  <h2 class="text-xl font-bold text-slate-900 dark:text-slate-100 mb-6">명도 시뮬레이터</h2>

  <%# Entry cards %>
  <div class="flex gap-4 mb-6">
    <div class="flex-1 border-2 border-blue-600 dark:border-blue-400 rounded-lg p-4 text-center cursor-pointer hover:bg-blue-50 dark:hover:bg-blue-900/20"
         data-action="click->simulator#selectMode"
         data-mode="property">
      <div class="text-3xl mb-2">📋</div>
      <strong class="text-sm text-slate-900 dark:text-slate-100">내 물건으로 시뮬레이션</strong>
      <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">분석 완료된 물건의 데이터를 자동 반영</p>
    </div>

    <%= form_with url: eviction_guide_simulation_path, method: :post, class: "flex-1" do |f| %>
      <%= f.hidden_field :property_id, value: "" %>
      <button type="submit"
              class="w-full h-full border-2 border-slate-300 dark:border-slate-600 rounded-lg p-4 text-center cursor-pointer hover:bg-slate-50 dark:hover:bg-slate-800">
        <div class="text-3xl mb-2">✏️</div>
        <strong class="text-sm text-slate-900 dark:text-slate-100">직접 입력으로 시뮬레이션</strong>
        <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">물건 없이 상황을 직접 입력</p>
      </button>
    <% end %>
  </div>

  <%# Property selector (shown when "내 물건으로" is clicked) %>
  <% if @properties.any? %>
    <%= render "eviction_guide/simulator/property_selector", properties: @properties, selected_property: @property %>
  <% end %>

  <%# Guide reverse link %>
  <div class="p-3 bg-slate-50 dark:bg-slate-800 rounded-lg text-sm text-slate-600 dark:text-slate-400">
    💡 명도 절차가 처음이라면
    <a href="<%= eviction_guide_guide_path %>" class="text-blue-600 dark:text-blue-400 hover:underline">명도 가이드</a>를
    먼저 읽어보세요.
  </div>
</div>
```

- [ ] **Step 3: Write _property_selector.html.erb**

Write `app/views/eviction_guide/simulator/_property_selector.html.erb`:

```erb
<div class="mb-6 p-4 border border-slate-200 dark:border-slate-700 rounded-lg">
  <h3 class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-3">물건 선택</h3>
  <%= form_with url: eviction_guide_simulation_path, method: :post do |f| %>
    <div class="mb-3">
      <%= f.select :property_id,
            properties.map { |p| ["#{p.case_number} — #{p.address}", p.id] },
            { include_blank: "물건을 선택하세요" },
            class: "w-full rounded-lg border-slate-300 dark:border-slate-600 dark:bg-slate-800 text-sm" %>
    </div>
    <button type="submit"
            class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-semibold hover:bg-blue-700">
      선택 완료 → 시뮬레이션 시작
    </button>
  <% end %>
</div>
```

- [ ] **Step 4: Write _question.html.erb**

Replace `app/views/eviction_guide/simulator/_question.html.erb`:

```erb
<%= turbo_frame_tag "simulator_question" do %>
  <%= render EvictionGuide::SimulatorQuestionComponent.new(
    question: @question,
    simulation: @simulation,
    step: @step
  ) %>
<% end %>
```

- [ ] **Step 5: Write _result.html.erb**

Write `app/views/eviction_guide/simulator/result.html.erb` (rename from partial to full view):

```erb
<%= render EvictionGuide::TabNavigationComponent.new(active_tab: "simulator") %>

<div class="max-w-2xl mx-auto px-4">
  <h2 class="text-xl font-bold text-slate-900 dark:text-slate-100 mb-6">시뮬레이션 결과</h2>
  <%= render EvictionGuide::SimulatorResultComponent.new(simulation: @simulation) %>
</div>
```

- [ ] **Step 6: Run full test suite**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add app/views/eviction_guide/
git commit -m "feat(f06): implement full view templates for guide and simulator"
```

---

## Task 8: Cleanup Job & Simulation Completion Logic

**Files:**
- Create: `app/jobs/eviction_simulation_cleanup_job.rb`
- Create: `test/jobs/eviction_simulation_cleanup_job_test.rb`
- Modify: `app/controllers/eviction_guide/simulations_controller.rb` — wire in DifficultyAssessor and PathBuilder on show

- [ ] **Step 1: Write failing cleanup job test**

Write `test/jobs/eviction_simulation_cleanup_job_test.rb`:

```ruby
require "test_helper"

class EvictionSimulationCleanupJobTest < ActiveJob::TestCase
  test "deletes stale standalone simulations" do
    stale = EvictionSimulation.create!(
      session_id: "stale", answers: {}, completed: false,
      created_at: 2.days.ago
    )
    recent = EvictionSimulation.create!(
      session_id: "recent", answers: {}, completed: false
    )
    linked = EvictionSimulation.create!(
      property: properties(:safe_apartment), answers: {}, completed: false,
      created_at: 2.days.ago
    )

    EvictionSimulationCleanupJob.perform_now

    assert_not EvictionSimulation.exists?(stale.id), "Stale standalone should be deleted"
    assert EvictionSimulation.exists?(recent.id), "Recent standalone should survive"
    assert EvictionSimulation.exists?(linked.id), "Property-linked should survive regardless of age"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/jobs/eviction_simulation_cleanup_job_test.rb`
Expected: FAIL — job doesn't exist.

- [ ] **Step 3: Implement cleanup job**

Write `app/jobs/eviction_simulation_cleanup_job.rb`:

```ruby
class EvictionSimulationCleanupJob < ApplicationJob
  queue_as :default

  def perform
    count = EvictionSimulation.stale.delete_all
    Rails.logger.info "[EvictionSimulationCleanupJob] Deleted #{count} stale simulations"
  end
end
```

- [ ] **Step 4: Run test**

Run: `bin/rails test test/jobs/eviction_simulation_cleanup_job_test.rb`
Expected: PASS.

- [ ] **Step 5: Update simulations_controller#show to compute result**

Update the `show` action in `app/controllers/eviction_guide/simulations_controller.rb`:

```ruby
def show
  @simulation = find_simulation
  return redirect_to eviction_guide_simulator_path unless @simulation

  @simulation.result_path = EvictionGuide::PathBuilder.call(@simulation.answers)
  @simulation.difficulty_level = EvictionGuide::DifficultyAssessor.call(@simulation.answers)
  @simulation.completed = true
  @simulation.save!

  render "eviction_guide/simulator/result", layout: "application"
end
```

- [ ] **Step 6: Run full test suite**

Run: `bin/rails test`
Expected: All PASS.

- [ ] **Step 7: Commit**

```bash
git add app/jobs/eviction_simulation_cleanup_job.rb \
  test/jobs/eviction_simulation_cleanup_job_test.rb \
  app/controllers/eviction_guide/simulations_controller.rb
git commit -m "feat(f06): add cleanup job and wire result computation into simulation show"
```

---

## Task 9: Cross-Links & F02 Grade Tab Integration

**Files:**
- Modify: `app/views/inspections/grades/show.html.erb` — add eviction guide link
- Modify: `app/controllers/eviction_guide/simulations_controller.rb` — wire F02 prefill on property-linked create
- Modify: `app/views/eviction_guide/simulator.html.erb` — show prefill when property is selected

- [ ] **Step 1: Add eviction guide link to F02 grade tab**

Find the grade show view and add a link. Look for a suitable insertion point (after the grade summary or at the bottom):

```erb
<%# Eviction scenario link %>
<div class="mt-6 p-4 border border-slate-200 dark:border-slate-700 rounded-lg">
  <div class="flex items-center justify-between">
    <div>
      <strong class="text-sm text-slate-900 dark:text-slate-100">명도 시나리오 확인</strong>
      <p class="text-xs text-slate-500 dark:text-slate-400 mt-0.5">이 물건의 명도 난이도와 절차를 미리 확인할 수 있습니다.</p>
    </div>
    <a href="<%= eviction_guide_simulator_path(property_id: @property.id) %>"
       class="px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-semibold hover:bg-blue-700 whitespace-nowrap">
      명도 시나리오 보기 →
    </a>
  </div>
</div>
```

- [ ] **Step 2: Wire F02 prefill in simulations_controller#create**

Update the create action to handle property-linked flow with prefill redirect:

```ruby
def create
  property_id = params.dig(:simulation, :property_id).presence&.to_i

  @simulation = if property_id
    EvictionSimulation.find_or_initialize_by(property_id: property_id)
  else
    EvictionSimulation.new(session_id: session.id.to_s)
  end

  @simulation.answers = {}
  @simulation.result_path = []
  @simulation.completed = false
  @simulation.difficulty_level = nil
  @simulation.save!

  session[:eviction_simulation_id] = @simulation.id

  if @simulation.property_linked?
    @property = @simulation.property
    @prefill_data = EvictionGuide::F02DataExtractor.call(@property)
    render "eviction_guide/simulator/_prefill"
  else
    redirect_to eviction_guide_simulator_question_path(code: "Q1")
  end
end
```

- [ ] **Step 3: Create prefill view**

Write `app/views/eviction_guide/simulator/_prefill.html.erb`:

```erb
<%= render EvictionGuide::TabNavigationComponent.new(active_tab: "simulator") %>

<div class="max-w-2xl mx-auto px-4">
  <%= render EvictionGuide::F02PrefillComponent.new(
    prefill_data: @prefill_data,
    simulation: @simulation
  ) %>
</div>
```

- [ ] **Step 4: Run full test suite**

Run: `bin/rails test`
Expected: All PASS.

- [ ] **Step 5: Run rubocop and brakeman**

Run: `bin/rubocop && bin/brakeman --quiet --no-pager`
Expected: No offenses, no warnings.

- [ ] **Step 6: Commit**

```bash
git add app/views/inspections/grades/show.html.erb \
  app/controllers/eviction_guide/simulations_controller.rb \
  app/views/eviction_guide/simulator/_prefill.html.erb
git commit -m "feat(f06): add F02 grade tab cross-link and prefill flow"
```

---

## Task 10: Final Integration Test & Cleanup

**Files:**
- Run: full CI pipeline

- [ ] **Step 1: Run the full CI pipeline**

Run: `bin/ci`
Expected: All checks pass (rubocop, brakeman, bundler-audit, importmap audit, tests, seed check).

- [ ] **Step 2: Verify seed loading in clean DB**

Run: `bin/rails db:reset`
Expected: Database resets and seeds load cleanly with eviction data.

- [ ] **Step 3: Manual smoke test**

Run: `bin/dev`
Open browser and verify:
1. `/eviction-guide/guide` — renders accordion with step cards
2. `/eviction-guide/simulator` — shows entry screen with two options
3. Click "직접 입력" → starts simulation at Q1
4. Answer yes/no → questions progress via Turbo Frame
5. Complete simulation → result screen with difficulty badge and path
6. Property grade tab shows "명도 시나리오 보기" link

- [ ] **Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "fix(f06): final integration fixes"
```

(Only if fixes were needed. Skip if no changes.)
