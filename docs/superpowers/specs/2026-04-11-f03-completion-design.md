# F03 Rights Analysis Completion — Design Spec

**Date:** 2026-04-11
**Status:** Draft
**Scope:** Close all 6 gaps in the F03 PDF analysis pipeline

---

## Context

The PDF analysis pipeline (upload → LLM → inspection results) is functional. However, the rights analysis report display layer is disconnected — `RightsAnalysisReport` is never created, several components are stubs, and there are reliability issues with the job error handling and UX flow.

## Gap Summary

| # | Gap | Severity | Fix Approach |
|---|-----|----------|-------------|
| 1 | RightsAnalysisReport never created | Critical | Extract report data from LLM response in PdfAnalysisService |
| 2 | SourceDocViewerComponent is a dead stub | Major | Rewrite to display LLM-extracted data from report_data |
| 3 | Dividend simulation does nothing | Major | Implement basic priority-ordered distribution calculation |
| 4 | Job failure silently succeeds | Medium | Re-raise after broadcast so Solid Queue retries |
| 5 | Standalone analysis (Path B) UX | Medium | Stay on page with Turbo instead of redirecting |
| 6 | Dev mode broadcast unreachable | Low | Document workaround, no code change needed |

---

## Design

### Gap 1: Create RightsAnalysisReport from LLM Response

**Approach:** Extend the LLM prompt to also request rights analysis summary data, then create a `RightsAnalysisReport` record in `PdfAnalysisService` after inspection results are mapped.

**Prompt extension (PdfPromptBuilder):**
Add a third task to the system prompt requesting:
```json
"rights_analysis": {
  "verdict": "safe" | "caution" | "danger",
  "verdict_summary": "한줄 요약",
  "base_right_type": "근저당권" | "전세권" | ...,
  "base_right_holder": "○○은행",
  "base_right_date": "2024-01-15",
  "opportunity_type": null | "gap_investment" | "occupancy",
  "opportunity_reason": null | "...",
  "tenants": [
    { "name": "...", "deposit": 50000000, "move_in_date": "2024-03-01", "opposing_power": true, "priority_rank": 2 }
  ],
  "rights_timeline": [
    { "date": "2024-01-15", "type": "근저당권", "holder": "○○은행", "amount": 200000000, "extinguished_on_sale": true }
  ],
  "reasoning": "말소기준권리는 2024-01-15 근저당권이며, 이보다 후순위인 ... 따라서 인수되는 금액은 없다.",
  "checklist_references": ["rights-003", ...]
}
```

**LLM은 팩트 추출 + 추론 근거만 담당, 금액 계산은 Ruby에서 수행:**

LLM은 복잡한 배당 순위나 권리 소멸 여부에 대한 수학적 계산이 부정확할 수 있다(hallucination 리스크). 따라서:
- LLM이 반환하는 것: 권리 내역(`rights_timeline`), 임차인 정보(`tenants`), 판단 근거(`reasoning`), 정성적 판단(`verdict`)
- LLM이 반환하지 **않는** 것: `assumed_amount`, `total_risk_amount` — 이 금액들은 아래 Ruby 로직에서 산출
- `reasoning` 필드로 Chain of Thought를 강제하여, LLM의 판단 근거를 감사 추적(audit trail)에 활용

**Ruby 레벨 금액 계산 (PdfAnalysisService 내):**
```ruby
# LLM이 추출한 팩트 데이터 기반으로 계산
assumed_amount = rights_timeline
  .select { |r| !r["extinguished_on_sale"] }
  .sum { |r| r["amount"].to_i }

total_risk_amount = assumed_amount + tenants
  .select { |t| t["opposing_power"] }
  .sum { |t| t["deposit"].to_i }
```

**Service change (PdfAnalysisService#call):**
After `InspectionResultMapper.call`, add:
```ruby
create_or_update_report(property, response)
```

The new method:
- Reads `response["rights_analysis"]`
- LLM 반환값에서 팩트 데이터 추출: `tenants`, `rights_timeline`, `reasoning`
- Ruby에서 `assumed_amount`, `total_risk_amount` 계산
- Maps to `RightsAnalysisReport` fields: `verdict`, `verdict_summary`, `base_right_type/holder/date`, `assumed_amount`(계산값), `total_risk_amount`(계산값), `opportunity_type/reason`
- Stores `tenants`, `rights_timeline`, `reasoning`, `checklist_references` in `report_data` JSON
- Uses `find_or_initialize_by(user: @user, property: property)` + `update!` for idempotency

**Fallback:** If LLM doesn't return `rights_analysis` key (e.g., mock adapter), create a report record with `analysis_status: "extraction_failed"` rather than skipping creation entirely. This ensures the rights analysis tab always renders — the UI shows an explicit error state ("분석 데이터를 구조화하는 데 실패했습니다. 원본 문서를 참고하세요.") instead of breaking or being empty.

```ruby
# Fallback: report 레코드는 반드시 생성
if rights_data.blank?
  report.update!(
    verdict: nil,
    report_data: { "analysis_status" => "extraction_failed",
                   "failed_at" => Time.current.iso8601 }
  )
  return
end
```

### Gap 2: SourceDocViewerComponent Rewrite

**Approach:** Instead of referencing deleted models, read from `RightsAnalysisReport#report_data` which now contains LLM-extracted document summaries.

**Changes:**
- `SourceDocViewerComponent#initialize` accepts `report:` instead of just `property:`
- Template reads from `@report.report_data`:
  - 매각물건명세서 panel: shows `base_right_type`, `base_right_holder`, `base_right_date`, `verdict_summary`, `property.remarks`
  - 등기부등본 panel: shows rights count, tenant count from `report_data["tenants"]` and `report_data["rights_timeline"]`
- If `@report` is nil, shows "분석을 먼저 실행해주세요" message

**Impact:** Update `RightsReportSectionComponent` template to pass `report:` to `SourceDocViewerComponent`.

### Gap 3: Dividend Simulation

**Approach:** Implement a basic distribution calculation in `DividendsController#update`.

**Logic:**
1. User inputs `expected_bid` (예상 낙찰가)
2. Read `tenants` from `report_data` (pre-populated by LLM)
3. Calculate execution costs (약 1.5% of bid)
4. Priority-ordered distribution: 집행비용 → 선순위 담보 → 대항력 있는 임차인 → 낙찰자
5. Compute `bidder_burden` = sum of amounts that survive (not extinguished by sale)
6. Store results in **별도 네임스페이스** `report_data["user_simulation"]`에 격리 저장

**시뮬레이션 데이터 격리:**
`report_data` 최상위에 시뮬레이션 결과를 혼합하지 않는다. LLM이 추출한 원본 데이터(불변)와 사용자가 반복 변경하는 시뮬레이션 결과(휘발성)를 명확히 분리:
```json
{
  "tenants": [...],           // LLM 원본 — 불변
  "rights_timeline": [...],   // LLM 원본 — 불변
  "reasoning": "...",         // LLM 원본 — 불변
  "user_simulation": {        // 사용자 입력 기반 — 휘발성
    "expected_bid": 150000000,
    "execution_cost": 2250000,
    "distribution": [...],
    "bidder_burden": 0,
    "simulated_at": "2026-04-11T10:30:00Z"
  }
}
```
이 구조를 통해 시뮬레이션 초기화(`report_data.delete("user_simulation")`)나 디버깅이 용이해진다.

**Note:** This is a simplified simulation. Full accuracy requires actual registry data. The LLM-extracted tenant/rights data provides a reasonable approximation with a disclaimer.

### Gap 4: Job Failure Re-raise

**Approach:** After broadcasting the failure message, re-raise the exception so Solid Queue marks the job as failed and can retry.

**Change in PdfAnalysisJob:**
```ruby
rescue => e
  Rails.logger.error "[PdfAnalysisJob] Failed: #{e.message}"
  log_failure_outside_transaction(e)  # 트랜잭션 밖에서 에러 로그 기록
  broadcast_progress("failed", "분석 중 오류가 발생했습니다: #{e.message}")
  raise  # Let Solid Queue handle retry
end
```

**트랜잭션 롤백 주의:**
Job 내부의 메인 로직이 `ActiveRecord::Base.transaction`으로 감싸져 있을 경우, 예외 발생 시 트랜잭션이 롤백되면서 에러 로그(DB 기록)도 함께 소실될 수 있다. 반드시 다음을 준수:
- `PdfAnalysisService#log_failure`는 트랜잭션 **밖에서** 실행 (별도 DB 커넥션 또는 `after_rollback` 콜백 활용)
- 브로드캐스트도 트랜잭션 밖에서 수행 (롤백되어도 사용자에게 실패 알림은 전달되어야 함)

```ruby
# PdfAnalysisJob — 트랜잭션 안전한 에러 처리 패턴
def perform(property_id, user_id)
  ActiveRecord::Base.transaction do
    # 메인 분석 로직
  end
rescue => e
  # 이 시점에서는 트랜잭션이 이미 롤백되었으므로
  # 에러 로그와 브로드캐스트는 안전하게 실행됨
  PdfAnalysisService.log_failure(property_id, e)
  broadcast_progress("failed", "분석 중 오류가 발생했습니다: #{e.message}")
  raise
end
```

**Also fix PdfAnalysisService#log_failure:**
- Replace hardcoded `"error"` strings with actual prompt content when available
- Handle nil `@property` case by creating a minimal log

### Gap 5: Standalone Analysis (Path B) UX

**Approach:** Instead of redirecting to `properties_path`, use Turbo Stream response to stay on the page and show progress.

**Changes:**
- `AnalysesController#create` responds with `turbo_stream` format
- Renders a Turbo Stream that replaces the form with the progress indicator
- The existing `turbo_stream_from` subscription on `analyses/new.html.erb` will receive updates
- On completion, the progress partial shows a link to the newly created property

### Gap 6: Dev Mode Broadcast

**No code change.** Document in CLAUDE.md or README that in development, Turbo broadcasts from background jobs require `config.solid_queue.connects_to` to use the same process, or switching cable adapter to `solid_cable` in development.yml.

---

## Files to Modify

| File | Change |
|------|--------|
| `app/services/inspection/pdf_prompt_builder.rb` | Add rights_analysis to system prompt |
| `app/services/pdf_analysis_service.rb` | Add `create_or_update_report` method |
| `app/jobs/pdf_analysis_job.rb` | Re-raise after broadcast, fix log_failure |
| `app/components/source_doc_viewer_component.rb` | Accept report, read from report_data |
| `app/components/source_doc_viewer_component.html.erb` | Rewrite panels to use report_data |
| `app/components/rights_report_section_component.html.erb` | Pass report to SourceDocViewer |
| `app/controllers/inspections/dividends_controller.rb` | Implement distribution calculation |
| `app/controllers/analyses_controller.rb` | Turbo Stream response instead of redirect |
| `app/views/analyses/new.html.erb` | Add turbo_frame for form replacement |

## Files to Create

| File | Purpose |
|------|---------|
| `test/services/pdf_analysis_service_test.rb` | Test report creation |
| `test/jobs/pdf_analysis_job_test.rb` | Test re-raise behavior |

## Out of Scope

- Full registry parsing (OCR/structured extraction) — LLM approximation is sufficient for MVP
- Real-time notification for Path B completion (push notification)
- Dividend simulation with actual court-provided priority tables
