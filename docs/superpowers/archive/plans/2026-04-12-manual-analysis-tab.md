# Manual Analysis Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "수동분석" tab to the analysis page so users can download AI prompts as markdown and upload JSON results for processing through the existing analysis pipeline.

**Architecture:** Extend `PdfAnalysisService` with a `response_json:` parameter to skip the LLM call when user-supplied JSON is provided. Add two new controller actions (`prompt`, `manual`) to `AnalysesController`. Add a Stimulus controller for tab switching and JSON file state management. Processing is synchronous (no background job).

**Tech Stack:** Rails 8.1, Stimulus (pure JS), TailwindCSS, ViewComponent, Minitest

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Modify | `config/routes.rb` | Add `prompt` and `manual` collection routes |
| Modify | `app/controllers/analyses_controller.rb` | Add `#prompt` and `#manual` actions |
| Modify | `app/services/pdf_analysis_service.rb` | Accept `response_json:` param, skip LLM when present |
| Modify | `app/views/analyses/new.html.erb` | Tabbed layout wrapping auto + manual panels |
| Create | `app/views/analyses/_manual_form.html.erb` | Manual analysis form (prompt download + JSON upload) |
| Create | `app/javascript/controllers/analysis_tabs_controller.js` | Tab switching + JSON file state + submit enable/disable |
| Modify | `test/services/pdf_analysis_service_test.rb` | Tests for `response_json:` path |
| Modify | `test/controllers/analyses_controller_test.rb` | Tests for `#prompt` and `#manual` actions |

---

### Task 1: Extend PdfAnalysisService with `response_json:` parameter

**Files:**
- Test: `test/services/pdf_analysis_service_test.rb`
- Modify: `app/services/pdf_analysis_service.rb`

- [ ] **Step 1: Write failing test — manual JSON path creates inspection results**

Add this test to `test/services/pdf_analysis_service_test.rb`:

```ruby
test "Path 3: processes user-provided JSON without LLM call" do
  response_json = JSON.parse(File.read(Rails.root.join("test/fixtures/files/ai_inspection_response.json")))

  result = PdfAnalysisService.call(response_json: response_json, user: @user)

  assert result.success?
  assert result.property.persisted?
  assert_equal "2024타경12345", result.property.case_number
  assert result.property.inspection_results.where(user: @user).any?
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb -n "test_Path_3:_processes_user-provided_JSON_without_LLM_call" -v`

Expected: FAIL — `PdfAnalysisService.call` does not accept `response_json:` keyword

- [ ] **Step 3: Implement `response_json:` parameter in PdfAnalysisService**

In `app/services/pdf_analysis_service.rb`, update the class:

```ruby
class PdfAnalysisService
  Result = Struct.new(:success?, :property, :error, keyword_init: true)

  def self.call(property: nil, documents: nil, user:, response_json: nil)
    new(property:, documents:, user:, response_json:).call
  end

  def initialize(property:, documents:, user:, response_json:)
    @property = property
    @documents = documents
    @user = user
    @response_json = response_json
  end

  def call
    response = if @response_json
      @response_json
    else
      pdf_blobs = collect_documents
      return Result.new(success?: false, error: "문서를 먼저 업로드해주세요.") if pdf_blobs.empty?

      items = InspectionItem.ordered
      prompts = Inspection::PdfPromptBuilder.call(items: items)

      llm = Llm::Base.for
      llm.analyze(
        system: prompts[:system],
        prompt: prompts[:user],
        documents: pdf_blobs
      )
    end

    items = InspectionItem.ordered unless items
    property = resolve_property(response["metadata"])
    attach_documents_to_property(property, collect_documents) if @property.nil? && !@response_json

    Inspection::InspectionResultMapper.call(
      response: response, property: property, user: @user, items: items
    )

    log_analysis(property, response)
    create_or_update_report(property, response)

    UserProperty.find_or_create_by!(user: @user, property: property)
    InspectionRatingService.call(property: property, user: @user)

    Result.new(success?: true, property: property)
  rescue => e
    log_failure(e)
    raise
  end

  private

  def collect_documents
    if @property
      @property.documents.map(&:blob)
    elsif @documents
      @documents
    else
      []
    end
  end

  def resolve_property(metadata)
    return @property if @property

    case_number = metadata&.dig("case_number")
    property = Property.find_by(case_number: case_number) if case_number.present?

    property || Property.create!(
      case_number: case_number || "PDF-#{SecureRandom.hex(4)}",
      address: metadata&.dig("address"),
      property_type: metadata&.dig("property_type"),
      appraisal_price: metadata&.dig("appraisal_price"),
      min_bid_price: metadata&.dig("min_bid_price")
    )
  end

  def attach_documents_to_property(property, blobs)
    blobs.each do |blob|
      property.documents.attach(blob) unless property.documents.blobs.include?(blob)
    end
  end

  def log_analysis(property, response)
    if @response_json
      LlmAnalysisLog.create!(
        property: property,
        user: @user,
        provider: "manual",
        model: "user_input",
        system_prompt: "manual_upload",
        user_prompt: "manual_upload",
        response_json: response,
        status: :completed,
        executed_at: Time.current
      )
    else
      llm = Llm::Base.for
      prompts = Inspection::PdfPromptBuilder.call(items: InspectionItem.ordered)
      LlmAnalysisLog.create!(
        property: property,
        user: @user,
        provider: llm.provider_name,
        model: llm.model_id,
        system_prompt: prompts[:system],
        user_prompt: prompts[:user],
        response_json: response,
        status: :completed,
        executed_at: Time.current
      )
    end
  end

  def create_or_update_report(property, response)
    report = RightsAnalysisReport.find_or_initialize_by(user: @user, property: property)
    rights_data = response["rights_analysis"]

    if rights_data.blank?
      report.update!(
        analyzed_at: Time.current,
        verdict_summary: nil,
        report_data: { "analysis_status" => "extraction_failed", "failed_at" => Time.current.iso8601 }
      )
      return
    end

    rights_timeline = rights_data["rights_timeline"] || []
    tenants = rights_data["tenants"] || []

    validation = Inspection::RightsValidator.call(
      base_right_date: rights_data["base_right_date"],
      tenants: tenants,
      rights_timeline: rights_timeline
    )

    report.update!(
      analyzed_at: Time.current,
      verdict: rights_data["verdict"],
      verdict_summary: rights_data["verdict_summary"],
      base_right_type: rights_data["base_right_type"],
      base_right_holder: rights_data["base_right_holder"],
      base_right_date: rights_data["base_right_date"],
      assumed_amount: validation.validated_amounts["assumed_amount"],
      total_risk_amount: validation.validated_amounts["total_risk_amount"],
      opportunity_type: rights_data["opportunity_type"],
      opportunity_reason: rights_data["opportunity_reason"],
      report_data: {
        "llm_raw" => {
          "tenants" => tenants,
          "rights_timeline" => rights_timeline,
          "reasoning" => rights_data["reasoning"],
          "checklist_references" => rights_data["checklist_references"]
        },
        "calculated" => {
          "tenants" => validation.validated_tenants,
          "assumed_amount" => validation.validated_amounts["assumed_amount"],
          "opposing_deposits" => validation.validated_amounts["opposing_deposits"],
          "total_risk_amount" => validation.validated_amounts["total_risk_amount"]
        },
        "discrepancies" => validation.discrepancies
      }
    )
  end

  def log_failure(error)
    return unless @property

    LlmAnalysisLog.create!(
      property: @property,
      user: @user,
      provider: Llm::Base.for.provider_name,
      model: Llm::Base.for.model_id,
      system_prompt: "error",
      user_prompt: "error",
      status: :failed,
      error_message: error.message,
      executed_at: Time.current
    )
  rescue => log_error
    Rails.logger.error "[PdfAnalysisService] Failed to log error: #{log_error.message}"
  end
end
```

Note: The key change is in `#call` — when `@response_json` is present, it's used directly as `response`, skipping document collection and LLM invocation. The `log_analysis` method branches to log `provider: "manual"` for manual uploads.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb -n "test_Path_3:_processes_user-provided_JSON_without_LLM_call" -v`

Expected: PASS

- [ ] **Step 5: Write failing test — manual path logs with provider "manual"**

Add this test to `test/services/pdf_analysis_service_test.rb`:

```ruby
test "Path 3: logs analysis with provider manual and model user_input" do
  response_json = JSON.parse(File.read(Rails.root.join("test/fixtures/files/ai_inspection_response.json")))

  assert_difference "LlmAnalysisLog.count", 1 do
    PdfAnalysisService.call(response_json: response_json, user: @user)
  end

  log = LlmAnalysisLog.last
  assert_equal "manual", log.provider
  assert_equal "user_input", log.model
  assert_equal "manual_upload", log.system_prompt
  assert_equal "completed", log.status
end
```

- [ ] **Step 6: Run test to verify it passes** (should already pass from step 3 implementation)

Run: `bin/rails test test/services/pdf_analysis_service_test.rb -n "test_Path_3:_logs_analysis_with_provider_manual_and_model_user_input" -v`

Expected: PASS

- [ ] **Step 7: Run all existing service tests to verify no regressions**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb -v`

Expected: All tests PASS

- [ ] **Step 8: Commit**

```bash
git add test/services/pdf_analysis_service_test.rb app/services/pdf_analysis_service.rb
git commit -m "feat: extend PdfAnalysisService with response_json parameter for manual analysis"
```

---

### Task 2: Add routes for prompt download and manual upload

**Files:**
- Modify: `config/routes.rb`

- [ ] **Step 1: Add collection routes**

In `config/routes.rb`, change:

```ruby
resources :analyses, only: [ :new, :create ]
```

to:

```ruby
resources :analyses, only: [ :new, :create ] do
  collection do
    get :prompt
    post :manual
  end
end
```

- [ ] **Step 2: Verify routes exist**

Run: `bin/rails routes | grep analyses`

Expected output includes:
```
prompt_analyses GET    /analyses/prompt(.:format)  analyses#prompt
manual_analyses POST   /analyses/manual(.:format)  analyses#manual
```

- [ ] **Step 3: Commit**

```bash
git add config/routes.rb
git commit -m "feat: add prompt and manual routes to analyses resource"
```

---

### Task 3: Implement `AnalysesController#prompt` action

**Files:**
- Test: `test/controllers/analyses_controller_test.rb`
- Modify: `app/controllers/analyses_controller.rb`

- [ ] **Step 1: Write failing test — prompt downloads markdown file**

Add to `test/controllers/analyses_controller_test.rb`:

```ruby
test "GET prompt downloads markdown file" do
  get prompt_analyses_path

  assert_response :success
  assert_equal "text/markdown", response.content_type
  assert_match /attachment/, response.headers["Content-Disposition"]
  assert_match /auction-analysis-prompt\.md/, response.headers["Content-Disposition"]
  assert_includes response.body, "부동산 경매 AI 분석 프롬��트"
  assert_includes response.body, "시스템 프롬프트"
  assert_includes response.body, "사용자 프롬프트"
  assert_includes response.body, "기대 응답 형식"
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/analyses_controller_test.rb -n "test_GET_prompt_downloads_markdown_file" -v`

Expected: FAIL — action not found

- [ ] **Step 3: Implement `#prompt` action**

Add to `app/controllers/analyses_controller.rb`:

```ruby
def prompt
  items = InspectionItem.ordered
  prompts = Inspection::PdfPromptBuilder.call(items: items)

  markdown = <<~MD
    # 부동산 경매 AI 분석 프롬프트

    아래 내용을 AI에게 전달하고, 법원경매 PDF 문서(매각물건명세서, 현황조사서, 감정평가서, 등기부등본)와 ��께 분석을 요청하세요.

    **중요:** 결과는 반드시 마지막 섹션의 JSON 형식으로 받아주세요.

    ---

    ## 시스템 프롬프트

    #{prompts[:system]}

    ---

    ## 사용자 프롬프트

    #{prompts[:user]}

    ---

    ## 기대 응답 형식 (JSON)

    AI의 응답이 아래 구조를 따르는지 확인하세요:

    ```json
    {
      "metadata": {
        "court_name": "관할 법원명",
        "case_number": "사건번호",
        "address": "소재지",
        "property_type": "물건종류",
        "appraisal_price": 0,
        "min_bid_price": 0
      },
      "results": {
        "<item_code>": {
          "has_risk": true,
          "confidence": "high",
          "reasoning": "판정 근거"
        }
      },
      "rights_analysis": {
        "verdict": "safe",
        "verdict_summary": "한줄 요약",
        "base_right_type": "근저당권",
        "base_right_holder": "권리자명",
        "base_right_date": "YYYY-MM-DD",
        "opportunity_type": null,
        "opportunity_reason": null,
        "tenants": [],
        "rights_timeline": [],
        "reasoning": "분석 근거",
        "checklist_references": []
      }
    }
    ```
  MD

  send_data markdown,
    filename: "auction-analysis-prompt.md",
    type: "text/markdown",
    disposition: "attachment"
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/controllers/analyses_controller_test.rb -n "test_GET_prompt_downloads_markdown_file" -v`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add app/controllers/analyses_controller.rb test/controllers/analyses_controller_test.rb
git commit -m "feat: add prompt download action to AnalysesController"
```

---

### Task 4: Implement `AnalysesController#manual` action

**Files:**
- Test: `test/controllers/analyses_controller_test.rb`
- Modify: `app/controllers/analyses_controller.rb`

- [ ] **Step 1: Write failing test — manual with valid JSON redirects to inspection tab**

Add to `test/controllers/analyses_controller_test.rb`:

```ruby
test "POST manual with valid JSON processes and redirects to inspection tab" do
  json_file = fixture_file_upload("test/fixtures/files/ai_inspection_response.json", "application/json")

  post manual_analyses_path, params: { json_file: json_file }

  property = Property.find_by(case_number: "2024타경12345")
  assert_not_nil property
  assert_redirected_to edit_property_inspections_tab_path(property, tab_key: "rights_analysis")
  assert_equal "분석 결과가 저장되었습니다.", flash[:notice]
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/analyses_controller_test.rb -n "test_POST_manual_with_valid_JSON_processes_and_redirects_to_inspection_tab" -v`

Expected: FAIL — action not found

- [ ] **Step 3: Write failing test — manual without file shows alert**

```ruby
test "POST manual without JSON file shows alert" do
  post manual_analyses_path, params: {}

  assert_redirected_to new_analysis_path
  assert_equal "JSON 파일을 업로드해주세요.", flash[:alert]
end
```

- [ ] **Step 4: Write failing test — manual with invalid JSON shows alert**

```ruby
test "POST manual with invalid JSON shows alert" do
  invalid_file = Rack::Test::UploadedFile.new(
    StringIO.new("this is not json"),
    "application/json",
    original_filename: "bad.json"
  )

  post manual_analyses_path, params: { json_file: invalid_file }

  assert_redirected_to new_analysis_path
  assert_equal "유효한 JSON 파일이 아닙니다.", flash[:alert]
end
```

- [ ] **Step 5: Write failing test — manual with JSON missing metadata shows alert**

```ruby
test "POST manual with JSON missing metadata key shows alert" do
  json_content = { "results" => {} }.to_json
  file = Rack::Test::UploadedFile.new(
    StringIO.new(json_content),
    "application/json",
    original_filename: "missing_metadata.json"
  )

  post manual_analyses_path, params: { json_file: file }

  assert_redirected_to new_analysis_path
  assert_equal "JSON에 metadata 키가 필요합니다.", flash[:alert]
end
```

- [ ] **Step 6: Write failing test — manual with JSON missing case_number shows alert**

```ruby
test "POST manual with JSON missing case_number shows alert" do
  json_content = { "metadata" => { "address" => "test" }, "results" => {} }.to_json
  file = Rack::Test::UploadedFile.new(
    StringIO.new(json_content),
    "application/json",
    original_filename: "no_case.json"
  )

  post manual_analyses_path, params: { json_file: file }

  assert_redirected_to new_analysis_path
  assert_equal "metadata.case_number가 필요합니다.", flash[:alert]
end
```

- [ ] **Step 7: Implement `#manual` action**

Add to `app/controllers/analyses_controller.rb`:

```ruby
def manual
  unless params[:json_file].present?
    redirect_to new_analysis_path, alert: "JSON 파일을 업로드해주세요."
    return
  end

  json_string = params[:json_file].read
  parsed = begin
    JSON.parse(json_string)
  rescue JSON::ParserError
    redirect_to new_analysis_path, alert: "유효한 JSON 파일이 아닙니다."
    return
  end

  unless parsed.key?("metadata")
    redirect_to new_analysis_path, alert: "JSON에 metadata 키가 필요합니다."
    return
  end

  unless parsed.key?("results")
    redirect_to new_analysis_path, alert: "JSON에 results 키가 필요합니다."
    return
  end

  unless parsed.dig("metadata", "case_number").present?
    redirect_to new_analysis_path, alert: "metadata.case_number가 필요합니다."
    return
  end

  result = PdfAnalysisService.call(response_json: parsed, user: current_user)

  if result.success?
    redirect_to edit_property_inspections_tab_path(result.property, tab_key: "rights_analysis"),
      notice: "분석 결과가 저장되었습니다."
  else
    redirect_to new_analysis_path, alert: "분석 결과 저장 중 오류가 발생했습니다: #{result.error}"
  end
rescue => e
  redirect_to new_analysis_path, alert: "분석 결과 저장 중 오류가 발생했습니다: #{e.message}"
end
```

- [ ] **Step 8: Run all manual-related tests**

Run: `bin/rails test test/controllers/analyses_controller_test.rb -v`

Expected: All tests PASS

- [ ] **Step 9: Commit**

```bash
git add app/controllers/analyses_controller.rb test/controllers/analyses_controller_test.rb
git commit -m "feat: add manual JSON upload action to AnalysesController"
```

---

### Task 5: Create Stimulus `analysis_tabs_controller.js`

**Files:**
- Create: `app/javascript/controllers/analysis_tabs_controller.js`

- [ ] **Step 1: Create the Stimulus controller**

Create `app/javascript/controllers/analysis_tabs_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["autoTab", "manualTab", "autoPanel", "manualPanel", "jsonInput", "submitButton", "fileName"]

  connect() {
    this.showAuto()
  }

  showAuto() {
    this.autoPanelTarget.classList.remove("hidden")
    this.manualPanelTarget.classList.add("hidden")
    this.autoTabTarget.classList.add("border-blue-500", "text-blue-600", "dark:text-blue-400")
    this.autoTabTarget.classList.remove("border-transparent", "text-slate-500")
    this.manualTabTarget.classList.remove("border-blue-500", "text-blue-600", "dark:text-blue-400")
    this.manualTabTarget.classList.add("border-transparent", "text-slate-500")
  }

  showManual() {
    this.manualPanelTarget.classList.remove("hidden")
    this.autoPanelTarget.classList.add("hidden")
    this.manualTabTarget.classList.add("border-blue-500", "text-blue-600", "dark:text-blue-400")
    this.manualTabTarget.classList.remove("border-transparent", "text-slate-500")
    this.autoTabTarget.classList.remove("border-blue-500", "text-blue-600", "dark:text-blue-400")
    this.autoTabTarget.classList.add("border-transparent", "text-slate-500")
  }

  selectJson() {
    const file = this.jsonInputTarget.files[0]
    if (file) {
      this.fileNameTarget.textContent = `${file.name} (${this.formatSize(file.size)})`
      this.fileNameTarget.classList.remove("hidden")
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    } else {
      this.fileNameTarget.classList.add("hidden")
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
  }

  submitManual() {
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    this.submitButtonTarget.value = "저장 중..."
  }

  formatSize(bytes) {
    if (bytes < 1024) return `${bytes}B`
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(0)}KB`
    return `${(bytes / 1048576).toFixed(1)}MB`
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add app/javascript/controllers/analysis_tabs_controller.js
git commit -m "feat: add analysis_tabs Stimulus controller for tab switching and JSON upload state"
```

---

### Task 6: Update `analyses/new.html.erb` with tabbed layout

**Files:**
- Modify: `app/views/analyses/new.html.erb`

- [ ] **Step 1: Replace `analyses/new.html.erb` with tabbed layout**

Replace the entire content of `app/views/analyses/new.html.erb` with:

```erb
<div class="max-w-lg mx-auto space-y-4" data-controller="analysis-tabs">
  <h1 class="text-lg font-semibold text-slate-900 dark:text-slate-100">새 분석</h1>

  <div class="border-b border-slate-200 dark:border-slate-700">
    <nav class="-mb-px flex gap-x-4" aria-label="Tabs">
      <button type="button"
        data-analysis-tabs-target="autoTab"
        data-action="click->analysis-tabs#showAuto"
        class="whitespace-nowrap border-b-2 py-3 px-1 text-sm font-medium border-blue-500 text-blue-600 dark:text-blue-400">
        AI 자동분석
      </button>
      <button type="button"
        data-analysis-tabs-target="manualTab"
        data-action="click->analysis-tabs#showManual"
        class="whitespace-nowrap border-b-2 py-3 px-1 text-sm font-medium border-transparent text-slate-500 hover:border-slate-300 hover:text-slate-700 dark:text-slate-400 dark:hover:text-slate-300">
        수동분석
      </button>
    </nav>
  </div>

  <div data-analysis-tabs-target="autoPanel">
    <%= render CardComponent.new(title: "PDF 문서 업로드") do %>
      <div class="space-y-3">
        <p class="text-sm text-slate-600 dark:text-slate-400">
          법원경매 사이트에서 확보한 문서(매각물건명세서, 현황조사서, 감정평가서, 등기부등본 등)를 PDF로 업로드해주세요.
        </p>
        <div class="text-xs text-amber-600 dark:text-amber-400">
          업로드된 문서는 AI 분석을 위해 외부 API(선택한 LLM 제공자)로 전송됩니다.
        </div>

        <%= render "analyses/form" %>
      </div>
    <% end %>
  </div>

  <div data-analysis-tabs-target="manualPanel" class="hidden">
    <%= render "analyses/manual_form" %>
  </div>
</div>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/analyses/new.html.erb
git commit -m "feat: add tabbed layout to analyses/new with auto and manual panels"
```

---

### Task 7: Create `analyses/_manual_form.html.erb` partial

**Files:**
- Create: `app/views/analyses/_manual_form.html.erb`

- [ ] **Step 1: Create the manual form partial**

Create `app/views/analyses/_manual_form.html.erb`:

```erb
<div class="space-y-4">
  <%= render CardComponent.new(title: "프롬프트 다운로드") do %>
    <div class="space-y-3">
      <p class="text-sm text-slate-600 dark:text-slate-400">
        아래 버튼을 눌러 AI 분석용 프롬프트를 다운로드하세요.
        다운로드한 파일의 내용을 AI(ChatGPT, Claude, Gemini 등)에 전달하고,
        법원경매 PDF 문서와 함께 분석을 요청하세요.
      </p>
      <%= link_to prompt_analyses_path, class: "inline-flex items-center gap-1.5 rounded-md bg-slate-100 px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-200 dark:bg-slate-700 dark:text-slate-300 dark:hover:bg-slate-600" do %>
        <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
        </svg>
        프롬프트 다운로드 (.md)
      <% end %>
    </div>
  <% end %>

  <%= render CardComponent.new(title: "분석 결과 업로드") do %>
    <div class="space-y-3">
      <p class="text-sm text-slate-600 dark:text-slate-400">
        AI로부터 받은 JSON 결과 파일을 업로드하세요.
      </p>

      <%= form_with url: manual_analyses_path, method: :post, class: "space-y-3", data: { action: "submit->analysis-tabs#submitManual" } do |f| %>
        <div>
          <%= f.file_field :json_file, accept: ".json,application/json",
              data: { analysis_tabs_target: "jsonInput", action: "change->analysis-tabs#selectJson" },
              class: "block w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 dark:file:bg-blue-900 dark:file:text-blue-300 dark:text-slate-400" %>
        </div>
        <div data-analysis-tabs-target="fileName"
             class="hidden text-sm text-slate-600 dark:text-slate-400 bg-slate-50 dark:bg-slate-800 rounded-md p-3 border border-slate-200 dark:border-slate-700">
        </div>
        <%= f.submit "분석 결과 저장",
            data: { analysis_tabs_target: "submitButton" },
            disabled: true,
            class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed" %>
      <% end %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/analyses/_manual_form.html.erb
git commit -m "feat: add manual analysis form partial with prompt download and JSON upload"
```

---

### Task 8: Integration verification — run full test suite

**Files:** None (verification only)

- [ ] **Step 1: Run all analyses controller tests**

Run: `bin/rails test test/controllers/analyses_controller_test.rb -v`

Expected: All tests PASS (including new prompt and manual tests)

- [ ] **Step 2: Run all PdfAnalysisService tests**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb -v`

Expected: All tests PASS (including new Path 3 tests)

- [ ] **Step 3: Run full test suite**

Run: `bin/rails test -v`

Expected: All tests PASS, no regressions

- [ ] **Step 4: Run linter**

Run: `bin/rubocop`

Expected: No new offenses. If any, fix them.

- [ ] **Step 5: Run security check**

Run: `bin/brakeman --quiet --no-pager`

Expected: No new warnings

- [ ] **Step 6: Commit any lint/security fixes if needed**

```bash
git add -A
git commit -m "fix: address rubocop/brakeman findings from manual analysis feature"
```

---

### Task 9: Manual browser verification

**Files:** None (verification only)

- [ ] **Step 1: Start dev server**

Run: `bin/dev`

- [ ] **Step 2: Navigate to `/analyses/new`**

Verify:
- Two tabs visible: "AI 자동분석" (active by default) and "수동분석"
- Auto tab shows existing PDF upload form
- Clicking "수동분석" switches to manual panel

- [ ] **Step 3: Test prompt download**

Click "프롬프트 다운로드 (.md)" button.

Verify:
- Browser downloads `auction-analysis-prompt.md`
- File contains system prompt, user prompt with inspection items, and JSON format example

- [ ] **Step 4: Test JSON upload flow**

Upload the test fixture `test/fixtures/files/ai_inspection_response.json` via the manual form.

Verify:
- File name and size displayed after selection
- "분석 결과 저장" button becomes enabled
- On submit, redirects to the inspection tab with results populated
- Flash notice: "분석 결과가 저장되었습니다."

- [ ] **Step 5: Test error cases**

- Submit without file → alert message
- Upload a non-JSON file → alert message
- Upload JSON missing `metadata` → alert message

- [ ] **Step 6: Test tab switching with dark mode**

Toggle dark mode and verify tab styling works correctly in both themes.
