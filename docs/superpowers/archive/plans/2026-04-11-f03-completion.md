# F03 Rights Analysis Completion — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Close all 6 gaps in the F03 PDF analysis pipeline — create RightsAnalysisReport from LLM response, rewrite SourceDocViewerComponent, implement dividend simulation, fix job error handling, and improve standalone analysis UX.

**Architecture:** Extend the existing PdfAnalysisService → LLM → InspectionResultMapper pipeline to also produce a RightsAnalysisReport. LLM extracts facts (rights timeline, tenants, reasoning); Ruby code computes financial amounts. Simulation results are stored in an isolated `user_simulation` namespace within `report_data` to separate volatile user input from immutable LLM output.

**Tech Stack:** Rails 8.1, Minitest, ViewComponent, Turbo Streams, Stimulus, Solid Queue, SQLite

---

## File Map

### Files to Modify

| File | Responsibility |
|------|---------------|
| `app/services/inspection/pdf_prompt_builder.rb` | Add rights_analysis task to system prompt |
| `app/services/pdf_analysis_service.rb` | Add `create_or_update_report` + Ruby amount calculation |
| `app/jobs/pdf_analysis_job.rb` | Re-raise after broadcast, transaction-safe error handling |
| `app/components/source_doc_viewer_component.rb` | Accept `report:` param, read from report_data |
| `app/components/source_doc_viewer_component.html.erb` | Rewrite panels for report_data |
| `app/components/rights_report_section_component.html.erb` | Pass `report:` to SourceDocViewer, handle nil report |
| `app/components/dividend_simulator_component.rb` | Read from `user_simulation` namespace |
| `app/components/dividend_simulator_component.html.erb` | No change needed (reads via component methods) |
| `app/controllers/inspections/dividends_controller.rb` | Implement distribution calculation, isolated storage |
| `app/controllers/analyses_controller.rb` | Turbo Stream response instead of redirect |
| `app/views/analyses/new.html.erb` | Wrap form in turbo_frame |
| `test/fixtures/files/ai_inspection_response.json` | Add rights_analysis fixture data |
| `test/services/pdf_analysis_service_test.rb` | Add report creation tests |
| `test/jobs/pdf_analysis_job_test.rb` | Add re-raise behavior tests |

### Files to Create

| File | Responsibility |
|------|---------------|
| `test/controllers/inspections/dividends_controller_test.rb` | Dividend simulation tests |
| `test/controllers/analyses_controller_test.rb` | Turbo Stream response tests |

---

## Task 1: Update Mock Fixture with Rights Analysis Data

**Files:**
- Modify: `test/fixtures/files/ai_inspection_response.json`

This is a prerequisite — every subsequent test relies on the mock adapter returning `rights_analysis` data.

- [ ] **Step 1: Add rights_analysis to fixture**

Replace the contents of `test/fixtures/files/ai_inspection_response.json` — keep existing `metadata` and `results`, add `rights_analysis`:

```json
{
  "metadata": {
    "court_name": "수원지방법원",
    "case_number": "2024타경12345",
    "address": "경기도 수원시 팔달구 인계동 123-4",
    "property_type": "아파트",
    "appraisal_price": 350000000,
    "min_bid_price": 280000000
  },
  "results": {
    "rights-002": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "매각물건명세서에 '을구 1번 주택임차권등기 — 배당에서 전액 변제받지 않으면 매수인이 인수'로 기재되어 있어 인수할 권리가 존재합니다."
    },
    "rights-001": {
      "has_risk": false,
      "confidence": "medium",
      "reasoning": "매각물건명세서에 가처분 관련 기재가 없으며, 임의경매 사건으로 소유권 분쟁 가능성이 낮습니다."
    },
    "rights-005": {
      "has_risk": false,
      "confidence": "medium",
      "reasoning": "무허가, 미등기 등의 기재가 없어 정상 건물로 추정됩니다."
    },
    "rights-007": {
      "has_risk": false,
      "confidence": "medium",
      "reasoning": "매각물건명세서에 예고등기 관련 기재가 없습니다."
    },
    "rights-008": {
      "has_risk": false,
      "confidence": "medium",
      "reasoning": "매각물건명세서에 선순위 세금 압류 관련 기재가 없습니다."
    },
    "rights-011": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "비고란에 '유치권 신고 있음'으로 기재되어 있습니다."
    },
    "rights-019": {
      "has_risk": false,
      "confidence": "high",
      "reasoning": "토지구분이 '전유'이므로 토지와 건물이 일체로 매각됩니다."
    },
    "rights-020": {
      "has_risk": true,
      "confidence": "high",
      "reasoning": "비고란에 '유치권 신고 있음'으로 기재되어 있습니다."
    },
    "rights-021": {
      "has_risk": false,
      "confidence": "high",
      "reasoning": "전세사기 특별법 또는 우선매수권 관련 기재가 없습니다."
    },
    "manual-001": {
      "has_risk": false,
      "confidence": "high",
      "reasoning": "경기도 수원시 빌라 3층 물건으로 분묘기지권 성립 가능성이 없습니다."
    }
  },
  "rights_analysis": {
    "verdict": "caution",
    "verdict_summary": "선순위 근저당 2억원이 말소기준권리이며, 대항력 있는 임차인 1명(보증금 5천만원)이 존재합니다.",
    "base_right_type": "근저당권",
    "base_right_holder": "○○은행",
    "base_right_date": "2024-01-15",
    "opportunity_type": null,
    "opportunity_reason": null,
    "tenants": [
      {
        "name": "김○○",
        "deposit": 50000000,
        "move_in_date": "2023-06-01",
        "opposing_power": true,
        "priority_rank": 1
      },
      {
        "name": "박○○",
        "deposit": 30000000,
        "move_in_date": "2024-05-01",
        "opposing_power": false,
        "priority_rank": 3
      }
    ],
    "rights_timeline": [
      {
        "date": "2024-01-15",
        "type": "근저당권",
        "holder": "○○은행",
        "amount": 200000000,
        "extinguished_on_sale": true
      },
      {
        "date": "2024-03-20",
        "type": "전세권",
        "holder": "김○○",
        "amount": 50000000,
        "extinguished_on_sale": true
      },
      {
        "date": "2024-08-10",
        "type": "가압류",
        "holder": "이○○",
        "amount": 10000000,
        "extinguished_on_sale": true
      }
    ],
    "reasoning": "말소기준권리는 2024-01-15 설정된 ○○은행 근저당권(채권최고액 2억원)입니다. 이보다 선순위인 임차인 김○○(전입 2023-06-01, 보증금 5천만원)은 대항력이 있어 낙찰자가 인수해야 합니다. 후순위 전세권과 가압류는 매각으로 소멸합니다.",
    "checklist_references": ["rights-002"]
  }
}
```

- [ ] **Step 2: Verify existing tests still pass**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb test/jobs/pdf_analysis_job_test.rb`
Expected: All existing tests PASS (fixture is backward-compatible — new key is simply ignored by current code)

- [ ] **Step 3: Commit**

```bash
git add test/fixtures/files/ai_inspection_response.json
git commit -m "test: add rights_analysis data to mock LLM fixture"
```

---

## Task 2: Extend PdfPromptBuilder with Rights Analysis Task

**Files:**
- Modify: `app/services/inspection/pdf_prompt_builder.rb`

- [ ] **Step 1: Add Task 3 to SYSTEM_PROMPT**

In `app/services/inspection/pdf_prompt_builder.rb`, replace the `SYSTEM_PROMPT` constant. Keep Tasks 1 and 2 exactly as they are, then add Task 3 and update the JSON response format:

```ruby
SYSTEM_PROMPT = <<~PROMPT
  당신은 대한민국 부동산 경매 권리분석 전문가입니다.
  첨부된 PDF 문서들을 분석하여 아래 작업을 수행하세요.

  [작업 1: 메타데이터 추출]
  문서에서 다음 정보를 추출하세요:
  - court_name: 관할 법원명
  - case_number: 사건번호 (예: 2024타경964)
  - address: 소재지
  - property_type: 물건종류
  - appraisal_price: 감정가 (숫자)
  - min_bid_price: 최저입찰가 (숫자)

  [작업 2: 점검항목 판정]
  각 항목에 대해 has_risk, confidence, reasoning을 반환하세요.

  [판정 규칙]
  - 데이터가 부족하여 판단할 수 없는 항목은 has_risk: null, confidence: "none"으로 반환하세요.
  - yes_means_safe=false인 항목은 "예"가 위험을 의미합니다. has_risk는 항상 "이 항목이 위험한가?"를 기준으로 판정하세요.
  - reasoning은 반드시 문서에서 확인한 구체적 근거를 인용하세요.

  [작업 3: 권리분석]
  등기부등본과 매각물건명세서를 종합하여 권리분석 데이터를 추출하세요.
  금액은 반드시 원(₩) 단위 숫자로 반환하세요.

  - verdict: "safe" | "caution" | "danger" — 낙찰자 입장의 종합 위험도
  - verdict_summary: 한줄 요약 (한국어)
  - base_right_type: 말소기준권리 유형 ("근저당권", "전세권", "가압류", "담보가등기" 등)
  - base_right_holder: 말소기준권리 권리자명
  - base_right_date: 말소기준권리 설정일 (YYYY-MM-DD)
  - opportunity_type: null | "gap_investment" | "occupancy"
  - opportunity_reason: 기회 요인 설명 (없으면 null)
  - tenants: 임차인 배열. 각 항목은 { name, deposit(원), move_in_date(YYYY-MM-DD), opposing_power(boolean), priority_rank(정수) }
  - rights_timeline: 권리 설정 내역 배열. 각 항목은 { date(YYYY-MM-DD), type, holder, amount(원), extinguished_on_sale(boolean) }
  - reasoning: 분석 과정과 판단 근거를 단계적으로 서술하세요 (Chain of Thought). 어떤 권리가 말소되고 어떤 권리가 인수되는지 명시적으로 설명하세요.
  - checklist_references: 관련된 점검항목 코드 배열 (예: ["rights-002"])

  [응답 형식]
  반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트를 포함하지 마세요.
  {
    "metadata": {
      "court_name": "...",
      "case_number": "...",
      "address": "...",
      "property_type": "...",
      "appraisal_price": ...,
      "min_bid_price": ...
    },
    "results": {
      "<item_code>": {
        "has_risk": true | false | null,
        "confidence": "high" | "medium" | "none",
        "reasoning": "판정 근거 (한국어, 문서 인용 포함)"
      }
    },
    "rights_analysis": {
      "verdict": "safe" | "caution" | "danger",
      "verdict_summary": "...",
      "base_right_type": "...",
      "base_right_holder": "...",
      "base_right_date": "YYYY-MM-DD",
      "opportunity_type": null | "gap_investment" | "occupancy",
      "opportunity_reason": null | "...",
      "tenants": [{ "name": "...", "deposit": 0, "move_in_date": "YYYY-MM-DD", "opposing_power": true, "priority_rank": 1 }],
      "rights_timeline": [{ "date": "YYYY-MM-DD", "type": "...", "holder": "...", "amount": 0, "extinguished_on_sale": true }],
      "reasoning": "...",
      "checklist_references": ["..."]
    }
  }
PROMPT
```

- [ ] **Step 2: Verify existing tests still pass**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb`
Expected: All PASS (prompt change doesn't affect mock adapter behavior)

- [ ] **Step 3: Commit**

```bash
git add app/services/inspection/pdf_prompt_builder.rb
git commit -m "feat: add rights_analysis task to PDF prompt builder"
```

---

## Task 3: Add Report Creation to PdfAnalysisService

**Files:**
- Modify: `app/services/pdf_analysis_service.rb`
- Modify: `test/services/pdf_analysis_service_test.rb`

- [ ] **Step 1: Write failing test for report creation**

Add to `test/services/pdf_analysis_service_test.rb`:

```ruby
test "creates RightsAnalysisReport from LLM rights_analysis response" do
  result = PdfAnalysisService.call(property: @property, user: @user)

  assert result.success?

  report = RightsAnalysisReport.find_by(property: result.property, user: @user)
  assert_not_nil report
  assert_equal "caution", report.verdict
  assert_equal "근저당권", report.base_right_type
  assert_equal "○○은행", report.base_right_holder
  assert_equal Date.parse("2024-01-15"), report.base_right_date
end

test "calculates assumed_amount from rights_timeline in Ruby" do
  result = PdfAnalysisService.call(property: @property, user: @user)
  report = RightsAnalysisReport.find_by(property: result.property, user: @user)

  # Only rights with extinguished_on_sale: false are assumed
  # Fixture: all 3 rights have extinguished_on_sale: true → assumed_amount = 0
  assert_equal 0, report.assumed_amount
end

test "calculates total_risk_amount from assumed_amount plus opposing tenants" do
  result = PdfAnalysisService.call(property: @property, user: @user)
  report = RightsAnalysisReport.find_by(property: result.property, user: @user)

  # assumed_amount(0) + opposing tenant 김○○ deposit(50_000_000) = 50_000_000
  assert_equal 50_000_000, report.total_risk_amount
end

test "stores tenants and rights_timeline in report_data" do
  result = PdfAnalysisService.call(property: @property, user: @user)
  report = RightsAnalysisReport.find_by(property: result.property, user: @user)

  assert_equal 2, report.report_data["tenants"].size
  assert_equal 3, report.report_data["rights_timeline"].size
  assert report.report_data["reasoning"].present?
end

test "creates extraction_failed report when rights_analysis key is missing" do
  # Temporarily use a fixture without rights_analysis
  fixture_path = Rails.root.join("test/fixtures/files/ai_inspection_response.json")
  original = File.read(fixture_path)
  no_rights = JSON.parse(original).except("rights_analysis")
  File.write(fixture_path, JSON.generate(no_rights))

  result = PdfAnalysisService.call(property: @property, user: @user)
  report = RightsAnalysisReport.find_by(property: result.property, user: @user)

  assert_not_nil report
  assert_nil report.verdict
  assert_equal "extraction_failed", report.report_data["analysis_status"]
ensure
  File.write(fixture_path, original)
end

test "report creation is idempotent on re-analysis" do
  PdfAnalysisService.call(property: @property, user: @user)
  PdfAnalysisService.call(property: @property, user: @user)

  assert_equal 1, RightsAnalysisReport.where(property: @property, user: @user).count
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb`
Expected: 6 new tests FAIL (no `create_or_update_report` method yet)

- [ ] **Step 3: Implement create_or_update_report in PdfAnalysisService**

In `app/services/pdf_analysis_service.rb`, add the call after `log_analysis` and before `UserProperty.find_or_create_by!`:

```ruby
def call
  pdf_blobs = collect_documents
  return Result.new(success?: false, error: "문서를 먼저 업로드해주세요.") if pdf_blobs.empty?

  items = InspectionItem.ordered
  prompts = Inspection::PdfPromptBuilder.call(items: items)

  llm = Llm::Base.for
  response = llm.analyze(
    system: prompts[:system],
    prompt: prompts[:user],
    documents: pdf_blobs
  )

  property = resolve_property(response["metadata"])
  attach_documents_to_property(property, pdf_blobs) if @property.nil?

  Inspection::InspectionResultMapper.call(
    response: response, property: property, user: @user, items: items
  )

  log_analysis(property, llm, prompts, response)
  create_or_update_report(property, response)

  UserProperty.find_or_create_by!(user: @user, property: property)
  InspectionRatingService.call(property: property, user: @user)

  Result.new(success?: true, property: property)
rescue => e
  log_failure(e)
  raise
end
```

Add the private method:

```ruby
def create_or_update_report(property, response)
  report = RightsAnalysisReport.find_or_initialize_by(user: @user, property: property)
  rights_data = response["rights_analysis"]

  if rights_data.blank?
    report.update!(
      analyzed_at: Time.current,
      verdict: nil,
      verdict_summary: nil,
      report_data: { "analysis_status" => "extraction_failed", "failed_at" => Time.current.iso8601 }
    )
    return
  end

  rights_timeline = rights_data["rights_timeline"] || []
  tenants = rights_data["tenants"] || []

  assumed_amount = rights_timeline
    .reject { |r| r["extinguished_on_sale"] }
    .sum { |r| r["amount"].to_i }

  opposing_tenant_deposits = tenants
    .select { |t| t["opposing_power"] }
    .sum { |t| t["deposit"].to_i }

  total_risk_amount = assumed_amount + opposing_tenant_deposits

  report.update!(
    analyzed_at: Time.current,
    verdict: rights_data["verdict"],
    verdict_summary: rights_data["verdict_summary"],
    base_right_type: rights_data["base_right_type"],
    base_right_holder: rights_data["base_right_holder"],
    base_right_date: rights_data["base_right_date"],
    assumed_amount: assumed_amount,
    total_risk_amount: total_risk_amount,
    opportunity_type: rights_data["opportunity_type"],
    opportunity_reason: rights_data["opportunity_reason"],
    report_data: {
      "tenants" => tenants,
      "rights_timeline" => rights_timeline,
      "reasoning" => rights_data["reasoning"],
      "checklist_references" => rights_data["checklist_references"]
    }
  )
end
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/services/pdf_analysis_service_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/services/pdf_analysis_service.rb test/services/pdf_analysis_service_test.rb
git commit -m "feat: create RightsAnalysisReport from LLM response with Ruby amount calculation"
```

---

## Task 4: Fix Job Failure Handling (Re-raise + Transaction Safety)

**Files:**
- Modify: `app/jobs/pdf_analysis_job.rb`
- Modify: `test/jobs/pdf_analysis_job_test.rb`

- [ ] **Step 1: Write failing test for re-raise**

Add to `test/jobs/pdf_analysis_job_test.rb`:

```ruby
test "re-raises exception after broadcasting failure" do
  # Force an error by using a non-existent property ID
  assert_raises(ActiveRecord::RecordNotFound) do
    PdfAnalysisJob.perform_now(property_id: -1, user_id: @user.id)
  end
end

test "logs failure to LlmAnalysisLog when service raises" do
  ENV["USE_MOCK"] = nil
  ENV["LLM_PROVIDER"] = "ollama"

  assert_raises(RuntimeError) do
    PdfAnalysisJob.perform_now(property_id: @property.id, user_id: @user.id)
  end

  log = LlmAnalysisLog.last
  assert_equal "failed", log.status
ensure
  ENV["LLM_PROVIDER"] = nil
  ENV["USE_MOCK"] = "true"
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/jobs/pdf_analysis_job_test.rb`
Expected: First test FAILS (current code rescues without re-raising)

- [ ] **Step 3: Fix PdfAnalysisJob to re-raise**

Replace `app/jobs/pdf_analysis_job.rb`:

```ruby
class PdfAnalysisJob < ApplicationJob
  queue_as :default

  def perform(property_id: nil, user_id:, document_blob_ids: nil)
    @user = User.find(user_id)
    @property = Property.find(property_id) if property_id

    broadcast_progress("analyzing", "AI 분석 중...")

    result = if document_blob_ids
      documents = ActiveStorage::Blob.where(id: document_blob_ids).to_a
      PdfAnalysisService.call(documents: documents, user: @user)
    else
      PdfAnalysisService.call(property: @property, user: @user)
    end

    if result.success?
      @property = result.property
      broadcast_progress("saving", "결과 저장 중...")
      broadcast_progress("completed", "분석 완료", property_id: result.property.id)
    else
      broadcast_progress("failed", result.error)
    end
  rescue => e
    Rails.logger.error "[PdfAnalysisJob] Failed: #{e.message}"
    broadcast_progress("failed", "분석 중 오류가 발생했습니다: #{e.message}")
    raise
  end

  private

  def broadcast_progress(status, message, **extra)
    Turbo::StreamsChannel.broadcast_replace_to(
      "analysis_progress_#{@user.id}",
      target: "analysis_progress",
      partial: "analyses/progress",
      locals: { status: status, message: message, **extra }
    )
  rescue ActionView::MissingTemplate => e
    Rails.logger.debug "[PdfAnalysisJob] Broadcast skipped (template missing): #{e.message}"
  rescue => e
    Rails.logger.error "[PdfAnalysisJob] Broadcast failed: #{e.message}"
  end
end
```

Key changes:
- Added `raise` at end of rescue block so Solid Queue can retry
- Added broader rescue in `broadcast_progress` to prevent broadcast errors from masking the original exception
- `PdfAnalysisService#log_failure` is already called inside the service's own rescue, which runs before the job's rescue — so error logging happens before re-raise

- [ ] **Step 4: Run tests to verify they pass**

Run: `bin/rails test test/jobs/pdf_analysis_job_test.rb`
Expected: All PASS

- [ ] **Step 5: Commit**

```bash
git add app/jobs/pdf_analysis_job.rb test/jobs/pdf_analysis_job_test.rb
git commit -m "fix: re-raise exceptions in PdfAnalysisJob for Solid Queue retry"
```

---

## Task 5: Rewrite SourceDocViewerComponent

**Files:**
- Modify: `app/components/source_doc_viewer_component.rb`
- Modify: `app/components/source_doc_viewer_component.html.erb`
- Modify: `app/components/rights_report_section_component.html.erb`

- [ ] **Step 1: Rewrite SourceDocViewerComponent Ruby class**

Replace `app/components/source_doc_viewer_component.rb`:

```ruby
class SourceDocViewerComponent < ViewComponent::Base
  def initialize(report:)
    @report = report
    @report_data = report&.report_data || {}
  end

  private

  def tenants
    @report_data["tenants"] || []
  end

  def rights_timeline
    @report_data["rights_timeline"] || []
  end

  def extraction_failed?
    @report_data["analysis_status"] == "extraction_failed"
  end

  def has_data?
    @report.present? && !extraction_failed?
  end
end
```

- [ ] **Step 2: Rewrite SourceDocViewerComponent template**

Replace `app/components/source_doc_viewer_component.html.erb`:

```erb
<div class="space-y-4" data-controller="source-doc-tracker">
  <h3 class="text-base font-semibold text-slate-900 dark:text-slate-100">원문 뷰어</h3>

  <% if extraction_failed? %>
    <div class="rounded-lg bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-700 p-4 text-sm text-amber-800 dark:text-amber-200">
      분석 데이터를 구조화하는 데 실패했습니다. 원본 문서를 참고하세요.
    </div>
  <% elsif !has_data? %>
    <div class="rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 text-sm text-slate-500 dark:text-slate-400">
      분석을 먼저 실행해주세요.
    </div>
  <% else %>
    <div class="flex border-b border-slate-200 dark:border-slate-700">
      <button class="px-4 py-2 text-sm font-medium border-b-2 border-blue-600 text-blue-600 dark:border-blue-400 dark:text-blue-400"
              data-source-doc-tracker-target="tab" data-action="click->source-doc-tracker#switchTab"
              data-doc-type="court_auction">매각물건명세서</button>
      <button class="px-4 py-2 text-sm font-medium border-b-2 border-transparent text-slate-500 dark:text-slate-400"
              data-source-doc-tracker-target="tab" data-action="click->source-doc-tracker#switchTab"
              data-doc-type="registry">등기부등본</button>
    </div>

    <div data-source-doc-tracker-target="panel" data-doc-type="court_auction"
         class="rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 text-sm font-mono leading-relaxed text-slate-700 dark:text-slate-300">
      <div class="font-semibold text-slate-900 dark:text-slate-100 mb-2">매각물건명세서 주요 내용</div>
      <p>• 말소기준권리: <%= @report.base_right_type.presence || "미확인" %> (<%= @report.base_right_holder.presence || "미확인" %>, <%= @report.base_right_date&.strftime("%Y.%m.%d") || "미확인" %>)</p>
      <p>• 종합 판단: <%= @report.verdict_summary.presence || "—" %></p>
      <p>• 인수 금액: <%= number_to_currency(@report.assumed_amount, unit: "₩", precision: 0) %></p>
      <p>• 위험 금액: <%= number_to_currency(@report.total_risk_amount, unit: "₩", precision: 0) %></p>
    </div>

    <div data-source-doc-tracker-target="panel" data-doc-type="registry" class="hidden rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-200 dark:border-slate-700 p-4 text-sm font-mono leading-relaxed text-slate-700 dark:text-slate-300">
      <div class="font-semibold text-slate-900 dark:text-slate-100 mb-2">등기부등본 주요 내용</div>
      <p>• 권리 설정: <%= rights_timeline.size %>건</p>
      <p>• 임차인: <%= tenants.size %>명 (대항력 있음: <%= tenants.count { |t| t["opposing_power"] } %>명)</p>
      <% if rights_timeline.any? %>
        <div class="mt-2 space-y-1">
          <% rights_timeline.each do |right| %>
            <p class="<%= right["extinguished_on_sale"] ? "text-slate-500 dark:text-slate-400" : "text-red-600 dark:text-red-400 font-semibold" %>">
              • <%= right["date"] %> <%= right["type"] %> — <%= right["holder"] %> (<%= number_to_currency(right["amount"], unit: "₩", precision: 0) %>)
              <%= right["extinguished_on_sale"] ? "[소멸]" : "[인수]" %>
            </p>
          <% end %>
        </div>
      <% end %>
    </div>
  <% end %>

  <div class="rounded-lg bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-700 px-3 py-2 text-sm text-red-800 dark:text-red-200">
    반드시 매각물건명세서 비고란을 직접 확인하세요. 본 서비스는 분석 결과의 정확성을 보증하지 않습니다.
  </div>
</div>
```

- [ ] **Step 3: Update RightsReportSectionComponent template**

Replace `app/components/rights_report_section_component.html.erb`:

```erb
<% if @report %>
  <div class="space-y-4">
    <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100">권리 분석 리포트</h3>
    <%= render ReportSummaryComponent.new(report: @report, property: @property) %>
    <%= render RegistryTimelineComponent.new(report: @report) %>
    <%= render DividendSimulatorComponent.new(report: @report, property: @property) %>
    <%= render SourceDocViewerComponent.new(report: @report) %>
    <%= render LegalDisclaimerComponent.new %>
  </div>
<% end %>
```

The only change: `SourceDocViewerComponent.new(property: @property)` → `SourceDocViewerComponent.new(report: @report)`

- [ ] **Step 4: Run all tests**

Run: `bin/rails test`
Expected: All PASS. Check for any component preview/test that referenced the old `property:` param.

- [ ] **Step 5: Commit**

```bash
git add app/components/source_doc_viewer_component.rb app/components/source_doc_viewer_component.html.erb app/components/rights_report_section_component.html.erb
git commit -m "feat: rewrite SourceDocViewerComponent to read from report_data"
```

---

## Task 6: Implement Dividend Simulation with Isolated Storage

**Files:**
- Modify: `app/controllers/inspections/dividends_controller.rb`
- Modify: `app/components/dividend_simulator_component.rb`
- Create: `test/controllers/inspections/dividends_controller_test.rb`

- [ ] **Step 1: Write failing test for dividend calculation**

Create `test/controllers/inspections/dividends_controller_test.rb`:

```ruby
require "test_helper"

module Inspections
  class DividendsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:guest)
      @property = properties(:safe_apartment)
      sign_in_as @user

      @report = RightsAnalysisReport.create!(
        user: @user,
        property: @property,
        analyzed_at: Time.current,
        verdict: :caution,
        verdict_summary: "테스트",
        assumed_amount: 0,
        total_risk_amount: 50_000_000,
        report_data: {
          "tenants" => [
            { "name" => "김○○", "deposit" => 50_000_000, "opposing_power" => true, "priority_rank" => 1 }
          ],
          "rights_timeline" => [
            { "date" => "2024-01-15", "type" => "근저당권", "holder" => "○○은행", "amount" => 200_000_000, "extinguished_on_sale" => true }
          ]
        }
      )
    end

    test "calculates distribution and stores in user_simulation namespace" do
      patch property_inspections_dividend_path(@property), params: { expected_bid: 300_000_000 }

      @report.reload
      simulation = @report.report_data["user_simulation"]

      assert_not_nil simulation
      assert_equal 300_000_000, simulation["expected_bid"]
      assert simulation["distribution"].is_a?(Array)
      assert simulation["distribution"].size > 0
      assert simulation["simulated_at"].present?
    end

    test "does not overwrite LLM original data" do
      patch property_inspections_dividend_path(@property), params: { expected_bid: 300_000_000 }

      @report.reload
      assert_equal 1, @report.report_data["tenants"].size
      assert_equal 1, @report.report_data["rights_timeline"].size
    end

    test "calculates execution cost as 1.5% of bid" do
      patch property_inspections_dividend_path(@property), params: { expected_bid: 200_000_000 }

      @report.reload
      simulation = @report.report_data["user_simulation"]
      assert_equal 3_000_000, simulation["execution_cost"]
    end
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/inspections/dividends_controller_test.rb`
Expected: FAIL (current implementation doesn't use `user_simulation` namespace or calculate distribution)

- [ ] **Step 3: Implement dividend calculation in controller**

Replace `app/controllers/inspections/dividends_controller.rb`:

```ruby
module Inspections
  class DividendsController < ApplicationController
    def update
      @property = Property.find(params[:property_id])
      @report = RightsAnalysisReport.find_by!(property: @property, user: current_user)

      expected_bid = params[:expected_bid].to_i
      return redirect_to property_inspections_grade_url(@property) if expected_bid <= 0

      simulation = calculate_distribution(expected_bid)

      report_data = @report.report_data.dup
      report_data["user_simulation"] = simulation
      @report.update!(report_data: report_data)

      redirect_to property_inspections_grade_url(@property)
    end

    private

    def calculate_distribution(expected_bid)
      execution_cost = (expected_bid * 0.015).to_i
      remaining = expected_bid - execution_cost

      distribution = []
      distribution << build_row(1, "집행비용", "집행비용", execution_cost, execution_cost)

      rights = @report.report_data["rights_timeline"] || []
      tenants = @report.report_data["tenants"] || []

      claimants = build_claimants(rights, tenants)
      claimants.sort_by! { |c| c[:priority_rank] }

      bidder_burden = 0

      claimants.each.with_index(2) do |claimant, rank|
        if claimant[:extinguished_on_sale]
          dividend = [ claimant[:amount], remaining ].min
          remaining -= dividend
          shortfall = claimant[:amount] - dividend
          distribution << build_row(rank, claimant[:holder], claimant[:type], claimant[:amount], dividend, shortfall)
        else
          bidder_burden += claimant[:amount]
          distribution << build_row(rank, claimant[:holder], claimant[:type], claimant[:amount], 0, 0, assumed: true)
        end
      end

      {
        "expected_bid" => expected_bid,
        "execution_cost" => execution_cost,
        "distribution" => distribution,
        "bidder_burden" => bidder_burden,
        "remaining" => remaining,
        "simulated_at" => Time.current.iso8601
      }
    end

    def build_claimants(rights, tenants)
      claimants = rights.map.with_index(1) do |right, idx|
        {
          holder: right["holder"],
          type: right["type"],
          amount: right["amount"].to_i,
          priority_rank: idx,
          extinguished_on_sale: right["extinguished_on_sale"]
        }
      end

      tenants.select { |t| t["opposing_power"] }.each do |tenant|
        claimants << {
          holder: tenant["name"],
          type: "임차보증금",
          amount: tenant["deposit"].to_i,
          priority_rank: tenant["priority_rank"] || 999,
          extinguished_on_sale: false
        }
      end

      claimants
    end

    def build_row(priority, holder, type, claim, dividend, shortfall = 0, assumed: false)
      {
        "priority" => priority,
        "holder" => holder,
        "type" => type,
        "claim" => claim,
        "dividend" => dividend,
        "shortfall" => shortfall,
        "assumed" => assumed
      }
    end
  end
end
```

- [ ] **Step 4: Update DividendSimulatorComponent to read from user_simulation**

In `app/components/dividend_simulator_component.rb`, update the initializer and methods:

```ruby
class DividendSimulatorComponent < ViewComponent::Base
  BURDEN_CONFIG = {
    "safe" => { color: "text-green-700 dark:text-green-400", bg: "bg-green-50 dark:bg-green-900/20", message: "추가 인수 부담이 없는 구조입니다" },
    "caution" => { color: "text-yellow-700 dark:text-yellow-400", bg: "bg-yellow-50 dark:bg-yellow-900/20", message: "미확인 위험 금액이 존재합니다. 확인이 필요합니다" },
    "danger" => { color: "text-red-700 dark:text-red-400", bg: "bg-red-50 dark:bg-red-900/20", message: "인수 금액이 추가 발생하는 구조입니다" }
  }.freeze

  def initialize(report:, property:)
    @report = report
    @property = property
    @simulation = report.report_data&.dig("user_simulation") || {}
  end

  private

  def expected_bid
    @simulation["expected_bid"]
  end

  def distribution
    @simulation["distribution"] || []
  end

  def bidder_burden
    @simulation["bidder_burden"] || 0
  end

  def burden_verdict
    if bidder_burden > 0
      "danger"
    elsif @report.total_risk_amount > 0
      "caution"
    else
      "safe"
    end
  end

  def burden_config
    BURDEN_CONFIG[burden_verdict]
  end

  def format_manwon(amount)
    return "—" if amount.nil?
    manwon = amount.to_i

    if manwon >= 10000
      eok = manwon / 10000
      remainder = manwon % 10000
      remainder > 0 ? "#{eok}억 #{remainder.to_fs(:delimited)}만원" : "#{eok}억원"
    elsif manwon > 0
      "#{manwon.to_fs(:delimited)}만원"
    else
      "0만원"
    end
  end
end
```

- [ ] **Step 5: Update DividendSimulatorComponent template for new data shape**

Replace the burden analysis section in `app/components/dividend_simulator_component.html.erb`. The distribution table stays the same. Update the burden section (lines 49-69) to use the new methods:

```erb
  <div class="rounded-lg border p-4 <%= burden_config[:bg] %>">
    <div class="text-sm font-semibold text-slate-900 dark:text-slate-100 mb-2">낙찰자 부담 분석</div>
    <div class="grid grid-cols-2 gap-4 text-sm mb-3">
      <div>
        <span class="text-slate-500 dark:text-slate-400">인수 금액 (대항력 임차인)</span>
        <p class="font-semibold text-slate-900 dark:text-slate-100"><%= format_manwon(bidder_burden) %></p>
      </div>
      <div>
        <span class="text-slate-500 dark:text-slate-400">총 위험 금액</span>
        <p class="font-bold text-slate-900 dark:text-slate-100"><%= format_manwon(@report.total_risk_amount) %></p>
      </div>
    </div>
    <div class="text-sm font-medium <%= burden_config[:color] %>">
      <% if burden_verdict == "safe" %>✅<% elsif burden_verdict == "caution" %>⚠️<% else %>🔴<% end %>
      <%= burden_config[:message] %>
    </div>
  </div>
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bin/rails test test/controllers/inspections/dividends_controller_test.rb`
Expected: All PASS

Run: `bin/rails test`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add app/controllers/inspections/dividends_controller.rb app/components/dividend_simulator_component.rb app/components/dividend_simulator_component.html.erb test/controllers/inspections/dividends_controller_test.rb
git commit -m "feat: implement dividend simulation with isolated user_simulation namespace"
```

---

## Task 7: Standalone Analysis (Path B) Turbo UX

**Files:**
- Modify: `app/controllers/analyses_controller.rb`
- Modify: `app/views/analyses/new.html.erb`
- Create: `test/controllers/analyses_controller_test.rb`

- [ ] **Step 1: Write failing test for Turbo Stream response**

Create `test/controllers/analyses_controller_test.rb`:

```ruby
require "test_helper"

class AnalysesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:guest)
    sign_in_as @user
  end

  test "GET new renders upload form" do
    get new_analysis_path
    assert_response :success
    assert_select "input[type=file]"
  end

  test "POST create with Turbo replaces form with progress indicator" do
    pdf = fixture_file_upload("test/fixtures/files/test.pdf", "application/pdf")

    post analyses_path, params: { documents: [ pdf ] },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
  end

  test "POST create without Turbo redirects with notice" do
    pdf = fixture_file_upload("test/fixtures/files/test.pdf", "application/pdf")

    post analyses_path, params: { documents: [ pdf ] }

    assert_redirected_to new_analysis_path
    assert_equal "분석이 시작되었습니다.", flash[:notice]
  end

  test "POST create without documents shows alert" do
    post analyses_path, params: {}

    assert_redirected_to new_analysis_path
    assert flash[:alert].present?
  end
end
```

- [ ] **Step 2: Create test PDF fixture if needed**

Run: `ls test/fixtures/files/test.pdf 2>/dev/null || echo "MISSING"`

If missing, create a minimal PDF:
```bash
echo "%PDF-1.4 test" > test/fixtures/files/test.pdf
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/controllers/analyses_controller_test.rb`
Expected: Turbo Stream tests FAIL (current controller always redirects)

- [ ] **Step 4: Update AnalysesController for Turbo Stream**

Replace `app/controllers/analyses_controller.rb`:

```ruby
class AnalysesController < ApplicationController
  def new
  end

  def create
    if params[:documents].blank?
      redirect_to new_analysis_path, alert: "PDF 파일을 업로드해주세요."
      return
    end

    blob_ids = params[:documents].map do |file|
      unless file.content_type == "application/pdf"
        redirect_to new_analysis_path, alert: "PDF 파일만 업로드할 수 있습니다."
        return
      end
      ActiveStorage::Blob.create_and_upload!(
        io: file,
        filename: file.original_filename,
        content_type: file.content_type
      ).id
    end

    PdfAnalysisJob.perform_later(
      property_id: nil,
      user_id: current_user.id,
      document_blob_ids: blob_ids
    )

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "analysis_form",
          partial: "analyses/progress",
          locals: { status: "analyzing", message: "AI 분석 중..." }
        )
      end
      format.html do
        redirect_to new_analysis_path, notice: "분석이 시작되었습니다."
      end
    end
  end
end
```

- [ ] **Step 5: Wrap form in turbo_frame in view**

Replace `app/views/analyses/new.html.erb`:

```erb
<div class="max-w-lg mx-auto space-y-4">
  <h1 class="text-lg font-semibold text-slate-900 dark:text-slate-100">새 분석</h1>

  <%= render CardComponent.new(title: "PDF 문서 업로드") do %>
    <div class="space-y-3">
      <p class="text-sm text-slate-600 dark:text-slate-400">
        법원경매 사이트에서 확보한 문서(매각물건명세서, 현황조사서, 감정평가서, 등기부등본 등)를 PDF로 업로드해주세요.
      </p>
      <div class="text-xs text-amber-600 dark:text-amber-400">
        업로드된 문서는 AI 분석을 위해 외부 API(선택한 LLM 제공자)로 전송됩니다.
      </div>

      <div id="analysis_form">
        <%= form_with url: analyses_path, method: :post, class: "space-y-3" do |f| %>
          <div>
            <%= f.file_field :documents, multiple: true, accept: "application/pdf",
                class: "block w-full text-sm text-slate-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-blue-50 file:text-blue-700 hover:file:bg-blue-100 dark:file:bg-blue-900 dark:file:text-blue-300" %>
          </div>
          <%= f.submit "분석 시작", class: "inline-flex items-center rounded-md bg-blue-600 px-4 py-2 text-sm font-medium text-white hover:bg-blue-700" %>
        <% end %>
      </div>
    </div>
  <% end %>

  <div id="analysis_progress">
    <%= turbo_stream_from "analysis_progress_#{current_user.id}" %>
  </div>
</div>
```

Key change: Wrapped the form in `<div id="analysis_form">` so Turbo Stream can target it for replacement.

- [ ] **Step 6: Run tests to verify they pass**

Run: `bin/rails test test/controllers/analyses_controller_test.rb`
Expected: All PASS

- [ ] **Step 7: Commit**

```bash
git add app/controllers/analyses_controller.rb app/views/analyses/new.html.erb test/controllers/analyses_controller_test.rb
git commit -m "feat: replace redirect with Turbo Stream for standalone analysis UX"
```

---

## Task 8: Final Verification

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All PASS

- [ ] **Step 2: Run linting**

Run: `bin/rubocop`
Expected: No new offenses

- [ ] **Step 3: Run security audit**

Run: `bin/brakeman --quiet --no-pager`
Expected: No new warnings

- [ ] **Step 4: Verify seed data still works**

Run: `bin/rails db:reset && bin/rails db:seed`
Expected: No errors

- [ ] **Step 5: Commit any lint fixes**

If rubocop found issues, fix and commit:
```bash
bin/rubocop -a
git add -A
git commit -m "style: fix rubocop offenses"
```
