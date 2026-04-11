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
  "assumed_amount": 0,
  "total_risk_amount": 0,
  "opportunity_type": null | "gap_investment" | "occupancy",
  "opportunity_reason": null | "...",
  "tenants": [...],
  "rights_timeline": [...],
  "checklist_references": ["rights-003", ...]
}
```

**Service change (PdfAnalysisService#call):**
After `InspectionResultMapper.call`, add:
```ruby
create_or_update_report(property, response)
```

The new method:
- Reads `response["rights_analysis"]`
- Maps to `RightsAnalysisReport` fields: `verdict`, `verdict_summary`, `base_right_type/holder/date`, `assumed_amount`, `total_risk_amount`, `opportunity_type/reason`
- Stores `tenants`, `rights_timeline`, `checklist_references` in `report_data` JSON
- Uses `find_or_initialize_by(user: @user, property: property)` + `update!` for idempotency

**Fallback:** If LLM doesn't return `rights_analysis` key (e.g., mock adapter), skip report creation gracefully.

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
6. Store results back in `report_data["dividend_simulation"]` and `report_data["bidder_burden"]`

**Note:** This is a simplified simulation. Full accuracy requires actual registry data. The LLM-extracted tenant/rights data provides a reasonable approximation with a disclaimer.

### Gap 4: Job Failure Re-raise

**Approach:** After broadcasting the failure message, re-raise the exception so Solid Queue marks the job as failed and can retry.

**Change in PdfAnalysisJob:**
```ruby
rescue => e
  Rails.logger.error "[PdfAnalysisJob] Failed: #{e.message}"
  broadcast_progress("failed", "분석 중 오류가 발생했습니다: #{e.message}")
  raise  # Let Solid Queue handle retry
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
