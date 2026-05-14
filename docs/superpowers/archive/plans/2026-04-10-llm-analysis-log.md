# LLM Analysis Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the AiInspectionRunner pipeline to persist LLM prompts and responses in a new `llm_analysis_logs` table for audit/debugging and re-execution.

**Architecture:** Add a `LlmAnalysisLog` model that records every LLM call (prompts, response, provider/model, status). The existing `AiInspectionRunner` is modified to create a log before calling the LLM and update it after. LLM adapters expose `provider_name` and `model_id` metadata. A new `AiInspectionJob` enables automatic execution via Solid Queue.

**Tech Stack:** Rails 8.1, SQLite, Minitest, Solid Queue

**Spec:** `docs/superpowers/specs/2026-04-10-llm-analysis-log-design.md`

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `db/migrate/XXXXXX_create_llm_analysis_logs.rb` | Create | Migration for llm_analysis_logs table |
| `app/models/llm_analysis_log.rb` | Create | Model with enum, validations, scopes |
| `test/models/llm_analysis_log_test.rb` | Create | Model unit tests |
| `test/fixtures/llm_analysis_logs.yml` | Create | Test fixtures |
| `app/models/property.rb` | Modify | Add `has_many :llm_analysis_logs` |
| `app/models/user.rb` | Modify | Add `has_many :llm_analysis_logs` |
| `app/adapters/llm/base.rb` | Modify | Add `provider_name` and `model_id` methods |
| `app/adapters/llm/anthropic.rb` | Modify | Implement `provider_name` / `model_id` |
| `app/adapters/llm/mock.rb` | Modify | Implement `provider_name` / `model_id` |
| `app/adapters/llm/open_ai.rb` | Modify | Implement `provider_name` / `model_id` |
| `app/adapters/llm/gemini.rb` | Modify | Implement `provider_name` / `model_id` |
| `app/adapters/llm/ollama.rb` | Modify | Implement `provider_name` / `model_id` |
| `app/adapters/llm/open_router.rb` | Modify | Implement `provider_name` / `model_id` |
| `test/adapters/llm/base_test.rb` | Modify | Test provider_name / model_id |
| `app/services/inspection/property_data_assembler.rb` | Modify | Add raw_data section |
| `test/services/inspection/property_data_assembler_test.rb` | Modify | Test raw_data inclusion |
| `app/services/ai_inspection_runner.rb` | Modify | Create/update LlmAnalysisLog |
| `test/services/ai_inspection_runner_test.rb` | Modify | Test log creation/update |
| `app/jobs/ai_inspection_job.rb` | Create | Solid Queue job |
| `test/jobs/ai_inspection_job_test.rb` | Create | Job test |
| `app/services/property_data_sync_service.rb` | Modify | Enqueue AiInspectionJob |

---

## Task 1: Migration and Model

**Files:**
- Create: `db/migrate/XXXXXX_create_llm_analysis_logs.rb`
- Create: `app/models/llm_analysis_log.rb`
- Create: `test/models/llm_analysis_log_test.rb`
- Create: `test/fixtures/llm_analysis_logs.yml`
- Modify: `app/models/property.rb`
- Modify: `app/models/user.rb`

- [ ] **Step 1: Generate migration**

Run:
```bash
bin/rails generate model LlmAnalysisLog \
  property:references \
  user:references \
  system_prompt:text \
  user_prompt:text \
  response_json:json \
  provider:string \
  model:string \
  status:integer \
  error_message:text \
  executed_at:datetime
```

- [ ] **Step 2: Edit migration to make user_id nullable and add indexes**

Open the generated migration file and update it:

```ruby
class CreateLlmAnalysisLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :llm_analysis_logs do |t|
      t.references :property, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.text :system_prompt, null: false
      t.text :user_prompt, null: false
      t.json :response_json
      t.string :provider
      t.string :model
      t.integer :status, default: 0, null: false
      t.text :error_message
      t.datetime :executed_at

      t.timestamps
    end

    add_index :llm_analysis_logs, :status
    add_index :llm_analysis_logs, [:property_id, :status]
  end
end
```

- [ ] **Step 3: Run migration**

Run: `bin/rails db:migrate`
Expected: Migration runs successfully, schema.rb updated.

- [ ] **Step 4: Write failing model test**

Replace generated `test/models/llm_analysis_log_test.rb`:

```ruby
require "test_helper"

class LlmAnalysisLogTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    @user = users(:guest)
  end

  test "valid with required attributes" do
    log = LlmAnalysisLog.new(
      property: @property,
      system_prompt: "You are an expert.",
      user_prompt: "Analyze this property."
    )
    assert log.valid?
  end

  test "valid without user (system-triggered)" do
    log = LlmAnalysisLog.new(
      property: @property,
      user: nil,
      system_prompt: "You are an expert.",
      user_prompt: "Analyze this property."
    )
    assert log.valid?
  end

  test "invalid without property" do
    log = LlmAnalysisLog.new(
      system_prompt: "You are an expert.",
      user_prompt: "Analyze this property."
    )
    assert_not log.valid?
    assert_includes log.errors[:property], "must exist"
  end

  test "invalid without system_prompt" do
    log = LlmAnalysisLog.new(
      property: @property,
      system_prompt: nil,
      user_prompt: "Analyze this property."
    )
    assert_not log.valid?
    assert_includes log.errors[:system_prompt], "can't be blank"
  end

  test "invalid without user_prompt" do
    log = LlmAnalysisLog.new(
      property: @property,
      system_prompt: "You are an expert.",
      user_prompt: nil
    )
    assert_not log.valid?
    assert_includes log.errors[:user_prompt], "can't be blank"
  end

  test "status enum values" do
    log = LlmAnalysisLog.new(
      property: @property,
      system_prompt: "test",
      user_prompt: "test"
    )

    log.status = :pending
    assert log.pending?

    log.status = :completed
    assert log.completed?

    log.status = :failed
    assert log.failed?
  end

  test "default status is pending" do
    log = LlmAnalysisLog.new(
      property: @property,
      system_prompt: "test",
      user_prompt: "test"
    )
    assert log.pending?
  end

  test "latest_for scope returns most recent completed log" do
    older = LlmAnalysisLog.create!(
      property: @property, system_prompt: "s", user_prompt: "u",
      status: :completed, executed_at: 2.hours.ago
    )
    newer = LlmAnalysisLog.create!(
      property: @property, system_prompt: "s", user_prompt: "u",
      status: :completed, executed_at: 1.hour.ago
    )
    failed = LlmAnalysisLog.create!(
      property: @property, system_prompt: "s", user_prompt: "u",
      status: :failed
    )

    result = LlmAnalysisLog.latest_for(@property)
    assert_equal newer, result
  end
end
```

- [ ] **Step 5: Run test to verify it fails**

Run: `bin/rails test test/models/llm_analysis_log_test.rb`
Expected: FAIL — model has no validations, enum, or scopes yet.

- [ ] **Step 6: Implement model**

Replace generated `app/models/llm_analysis_log.rb`:

```ruby
class LlmAnalysisLog < ApplicationRecord
  belongs_to :property
  belongs_to :user, optional: true

  enum :status, { pending: 0, completed: 1, failed: 2 }

  validates :system_prompt, presence: true
  validates :user_prompt, presence: true

  scope :latest_for, ->(property) {
    where(property: property, status: :completed)
      .order(executed_at: :desc)
      .first
  }
end
```

- [ ] **Step 7: Create fixture**

Replace `test/fixtures/llm_analysis_logs.yml`:

```yaml
# empty — tests create records directly
```

- [ ] **Step 8: Add associations to Property and User**

In `app/models/property.rb`, add:
```ruby
has_many :llm_analysis_logs, dependent: :destroy
```

In `app/models/user.rb`, add:
```ruby
has_many :llm_analysis_logs, dependent: :nullify
```

- [ ] **Step 9: Run tests to verify they pass**

Run: `bin/rails test test/models/llm_analysis_log_test.rb`
Expected: All 8 tests PASS.

- [ ] **Step 10: Commit**

```bash
git add db/migrate/ db/schema.rb app/models/llm_analysis_log.rb app/models/property.rb app/models/user.rb test/models/llm_analysis_log_test.rb test/fixtures/llm_analysis_logs.yml
git commit -m "feat: add LlmAnalysisLog model with migration, validations, and scopes"
```

---

## Task 2: LLM Adapter Metadata

**Files:**
- Modify: `app/adapters/llm/base.rb`
- Modify: `app/adapters/llm/anthropic.rb`
- Modify: `app/adapters/llm/mock.rb`
- Modify: `app/adapters/llm/open_ai.rb` (if exists)
- Modify: `app/adapters/llm/gemini.rb` (if exists)
- Modify: `app/adapters/llm/ollama.rb` (if exists)
- Modify: `app/adapters/llm/open_router.rb` (if exists)

- [ ] **Step 1: Write failing test**

Create or update `test/adapters/llm/base_test.rb`:

```ruby
require "test_helper"

class Llm::BaseTest < ActiveSupport::TestCase
  test "Mock adapter returns provider_name and model_id" do
    adapter = Llm::Mock.new
    assert_equal "mock", adapter.provider_name
    assert_equal "mock", adapter.model_id
  end

  test "Anthropic adapter returns provider_name and model_id" do
    adapter = Llm::Anthropic.new
    assert_equal "anthropic", adapter.provider_name
    assert_includes adapter.model_id, "claude"
  end

  test "Base.for returns adapter with metadata methods" do
    ENV["USE_MOCK"] = "true"
    adapter = Llm::Base.for
    assert_respond_to adapter, :provider_name
    assert_respond_to adapter, :model_id
  ensure
    ENV.delete("USE_MOCK")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/adapters/llm/base_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'provider_name'`

- [ ] **Step 3: Add abstract methods to Base**

In `app/adapters/llm/base.rb`, add after the `analyze` method:

```ruby
def provider_name
  raise NotImplementedError, "#{self.class}#provider_name must be implemented"
end

def model_id
  raise NotImplementedError, "#{self.class}#model_id must be implemented"
end
```

- [ ] **Step 4: Implement in Mock adapter**

In `app/adapters/llm/mock.rb`, add:

```ruby
def provider_name
  "mock"
end

def model_id
  "mock"
end
```

- [ ] **Step 5: Implement in Anthropic adapter**

In `app/adapters/llm/anthropic.rb`, add:

```ruby
def provider_name
  "anthropic"
end

def model_id
  model_name(DEFAULT_MODEL)
end
```

- [ ] **Step 6: Implement in all other adapters**

For each adapter (OpenAi, Gemini, Ollama, OpenRouter), add `provider_name` and `model_id` methods following the same pattern. Each returns its provider string and uses `model_name(DEFAULT_MODEL)`. Check each file for its `DEFAULT_MODEL` constant.

- [ ] **Step 7: Run tests to verify they pass**

Run: `bin/rails test test/adapters/llm/base_test.rb`
Expected: All 3 tests PASS.

- [ ] **Step 8: Commit**

```bash
git add app/adapters/llm/ test/adapters/llm/
git commit -m "feat: add provider_name and model_id to LLM adapters"
```

---

## Task 3: PropertyDataAssembler — Add raw_data Section

**Files:**
- Modify: `app/services/inspection/property_data_assembler.rb`
- Modify: `test/services/inspection/property_data_assembler_test.rb`

- [ ] **Step 1: Write failing test**

Add to `test/services/inspection/property_data_assembler_test.rb`:

```ruby
test "includes raw_data section when raw_data is present" do
  @property.update!(raw_data: { "registry_transcript" => "등기부등본 내용", "sale_memo" => "비고" })

  text = Inspection::PropertyDataAssembler.call(@property)

  assert_includes text, "[원시 데이터 (raw_data)]"
  assert_includes text, "registry_transcript"
  assert_includes text, "등기부등본 내용"
end

test "shows no raw_data message when raw_data is nil" do
  @property.update!(raw_data: nil)

  text = Inspection::PropertyDataAssembler.call(@property)

  assert_includes text, "[원시 데이터 (raw_data)]"
  assert_includes text, "(정보 없음)"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/inspection/property_data_assembler_test.rb -n "/raw_data/"`
Expected: FAIL — no raw_data section in output.

- [ ] **Step 3: Add raw_data_section to PropertyDataAssembler**

In `app/services/inspection/property_data_assembler.rb`, add `raw_data_section` to the `call` method's sections array and implement the method:

In the `call` method, change:
```ruby
sections = [
  basic_info_section,
  sale_detail_section,
  appraisal_section,
  land_section,
  auction_section
]
```
to:
```ruby
sections = [
  basic_info_section,
  sale_detail_section,
  appraisal_section,
  land_section,
  auction_section,
  raw_data_section
]
```

Add private method:
```ruby
def raw_data_section
  data = @property.raw_data
  return "[원시 데이터 (raw_data)]\n(정보 없음)" if data.blank?

  "[원시 데이터 (raw_data)]\n#{JSON.pretty_generate(data)}"
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/inspection/property_data_assembler_test.rb`
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/services/inspection/property_data_assembler.rb test/services/inspection/property_data_assembler_test.rb
git commit -m "feat: include raw_data in PropertyDataAssembler output"
```

---

## Task 4: AiInspectionRunner — Log Creation and Updates

**Files:**
- Modify: `app/services/ai_inspection_runner.rb`
- Modify: `test/services/ai_inspection_runner_test.rb`

- [ ] **Step 1: Write failing tests**

Add to `test/services/ai_inspection_runner_test.rb`:

```ruby
test "creates LlmAnalysisLog with pending status before LLM call" do
  @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

  AiInspectionRunner.call(property: @property, user: @user)

  log = @property.llm_analysis_logs.last
  assert_not_nil log
  assert log.completed?
  assert_not_nil log.system_prompt
  assert_not_nil log.user_prompt
  assert_equal "mock", log.provider
  assert_equal "mock", log.model
end

test "stores response_json on successful LLM call" do
  @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

  AiInspectionRunner.call(property: @property, user: @user)

  log = @property.llm_analysis_logs.last
  assert log.completed?
  assert_not_nil log.response_json
  assert log.response_json.key?("results")
  assert_not_nil log.executed_at
end

test "stores user_id when user is provided" do
  @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

  AiInspectionRunner.call(property: @property, user: @user)

  log = @property.llm_analysis_logs.last
  assert_equal @user, log.user
end

test "allows nil user for system-triggered runs" do
  @property.inspection_results.where(user: nil).destroy_all

  AiInspectionRunner.call(property: @property, user: nil)

  log = @property.llm_analysis_logs.last
  assert_nil log.user
  assert log.completed?
end

test "marks log as failed when LLM raises error" do
  adapter = Minitest::Mock.new
  adapter.expect(:provider_name, "mock")
  adapter.expect(:model_id, "mock")
  adapter.expect(:analyze, nil) { raise "LLM API error (500): Internal server error" }

  Llm::Base.stub(:for, adapter) do
    assert_raises(RuntimeError) do
      AiInspectionRunner.call(property: @property, user: @user)
    end
  end

  log = @property.llm_analysis_logs.last
  assert log.failed?
  assert_includes log.error_message, "LLM API error"
  assert_nil log.response_json
end

test "creates new log each run (history preserved)" do
  @property.inspection_results.where(user: @user).where.not(source_type: :manual).destroy_all

  AiInspectionRunner.call(property: @property, user: @user)
  first_count = @property.llm_analysis_logs.count

  AiInspectionRunner.call(property: @property, user: @user)
  assert_equal first_count + 1, @property.llm_analysis_logs.count
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/ai_inspection_runner_test.rb`
Expected: FAIL — `NoMethodError: undefined method 'llm_analysis_logs'` or similar.

- [ ] **Step 3: Implement AiInspectionRunner with logging**

Replace `app/services/ai_inspection_runner.rb`:

```ruby
class AiInspectionRunner
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def initialize(property:, user:)
    @property = property
    @user = user
  end

  def call
    text = Inspection::PropertyDataAssembler.call(@property)
    items = InspectionItem.ordered
    prompt = Inspection::InspectionPromptBuilder.call(property_text: text, items: items)
    adapter = Llm::Base.for

    log = create_log(prompt, adapter)

    begin
      response = adapter.analyze(system: prompt[:system], prompt: prompt[:user])
      complete_log(log, response)
      Inspection::InspectionResultMapper.call(
        response: response, property: @property, user: @user, items: items
      )
    rescue => e
      fail_log(log, e)
      raise
    end
  end

  private

  def create_log(prompt, adapter)
    LlmAnalysisLog.create!(
      property: @property,
      user: @user,
      system_prompt: prompt[:system],
      user_prompt: prompt[:user],
      provider: adapter.provider_name,
      model: adapter.model_id,
      status: :pending
    )
  end

  def complete_log(log, response)
    log.update!(
      status: :completed,
      response_json: response,
      executed_at: Time.current
    )
  end

  def fail_log(log, error)
    log.update!(
      status: :failed,
      error_message: error.message,
      executed_at: Time.current
    )
  end
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/ai_inspection_runner_test.rb`
Expected: All tests PASS (both existing and new).

- [ ] **Step 5: Run full test suite to check for regressions**

Run: `bin/rails test`
Expected: No regressions.

- [ ] **Step 6: Commit**

```bash
git add app/services/ai_inspection_runner.rb test/services/ai_inspection_runner_test.rb
git commit -m "feat: persist LLM prompts and responses in LlmAnalysisLog"
```

---

## Task 5: AiInspectionJob (Solid Queue)

**Files:**
- Create: `app/jobs/ai_inspection_job.rb`
- Create: `test/jobs/ai_inspection_job_test.rb`
- Modify: `app/services/property_data_sync_service.rb`

- [ ] **Step 1: Write failing job test**

Create `test/jobs/ai_inspection_job_test.rb`:

```ruby
require "test_helper"

class AiInspectionJobTest < ActiveSupport::TestCase
  setup do
    @property = properties(:risky_villa)
    ENV["USE_MOCK"] = "true"
  end

  teardown do
    ENV.delete("USE_MOCK")
  end

  test "calls AiInspectionRunner with property and no user" do
    @property.inspection_results.where(user: nil).destroy_all

    AiInspectionJob.perform_now(@property)

    log = @property.llm_analysis_logs.last
    assert_not_nil log
    assert log.completed?
    assert_nil log.user
  end

  test "does not raise when AiInspectionRunner fails" do
    adapter = Minitest::Mock.new
    adapter.expect(:provider_name, "mock")
    adapter.expect(:model_id, "mock")
    adapter.expect(:analyze, nil) { raise "LLM API error" }

    Llm::Base.stub(:for, adapter) do
      assert_nothing_raised do
        AiInspectionJob.perform_now(@property)
      end
    end

    log = @property.llm_analysis_logs.last
    assert log.failed?
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/jobs/ai_inspection_job_test.rb`
Expected: FAIL — `NameError: uninitialized constant AiInspectionJob`

- [ ] **Step 3: Implement the job**

Create `app/jobs/ai_inspection_job.rb`:

```ruby
class AiInspectionJob < ApplicationJob
  queue_as :default

  def perform(property)
    AiInspectionRunner.call(property: property, user: nil)
  rescue => e
    Rails.logger.error "[AiInspectionJob] Failed for property #{property.case_number}: #{e.message}"
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/jobs/ai_inspection_job_test.rb`
Expected: All 2 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add app/jobs/ai_inspection_job.rb test/jobs/ai_inspection_job_test.rb
git commit -m "feat: add AiInspectionJob for automatic LLM analysis"
```

- [ ] **Step 6: Write failing test for PropertyDataSyncService enqueue**

Add to `test/services/property_data_sync_service_test.rb` (create if needed):

```ruby
require "test_helper"

class PropertyDataSyncServiceTest < ActiveSupport::TestCase
  test "enqueues AiInspectionJob after successful sync" do
    # Use a mock adapter that returns valid court data
    mock_data = {
      property_type: "아파트", address: "서울 강남", status: "진행중",
      appraisal_price: 100_000_000, min_bid_price: 70_000_000,
      failed_bid_count: 0, view_count: 0, interest_count: 0
    }

    mock_adapter = Minitest::Mock.new
    mock_adapter.expect(:fetch_data_with_detail, mock_data, case_number: "2026타경99999")

    GovernmentCourtAuctionAdapter.stub(:new, mock_adapter) do
      assert_enqueued_with(job: AiInspectionJob) do
        PropertyDataSyncService.call(case_number: "2026타경99999")
      end
    end
  end
end
```

- [ ] **Step 7: Run test to verify it fails**

Run: `bin/rails test test/services/property_data_sync_service_test.rb -n "/enqueues/"`
Expected: FAIL — no job enqueued.

- [ ] **Step 8: Add enqueue to PropertyDataSyncService**

In `app/services/property_data_sync_service.rb`, in the `persist_property` method, add at the end before `property`:

```ruby
AiInspectionJob.perform_later(property)

property
```

Replace the last line of `persist_property` so it reads:

```ruby
    sync_appraisal_points(property, court_data[:appraisal_points])

    AiInspectionJob.perform_later(property)

    property
  end
```

- [ ] **Step 9: Run test to verify it passes**

Run: `bin/rails test test/services/property_data_sync_service_test.rb`
Expected: PASS.

- [ ] **Step 10: Run full test suite**

Run: `bin/rails test`
Expected: No regressions.

- [ ] **Step 11: Commit**

```bash
git add app/services/property_data_sync_service.rb test/services/property_data_sync_service_test.rb
git commit -m "feat: enqueue AiInspectionJob after property data sync"
```

---

## Task 6: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests PASS.

- [ ] **Step 2: Run rubocop**

Run: `bin/rubocop`
Expected: No new offenses.

- [ ] **Step 3: Run brakeman**

Run: `bin/brakeman --quiet --no-pager`
Expected: No new warnings.

- [ ] **Step 4: Verify migration is clean**

Run: `bin/rails db:migrate:status`
Expected: All migrations are `up`.
