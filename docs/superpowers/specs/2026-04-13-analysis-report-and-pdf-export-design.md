# Analysis Report Screen & PDF Export — Design Spec

## 1. Overview

Transform the existing 최종등급 (Final Grade) tab into a comprehensive analysis report screen. The report consolidates all collected inspection data, provides a rule-based bid opinion with supporting figures, and can be exported as PDF for offline professional consultation.

This design merges SRS v2.2 features:
- **F02 acceptance criteria:** 최종등급 safety grade aggregation UI (incomplete)
- **F05:** Analysis Report PDF Export (not started)

### Scope

- Enhance `GradesController#show` with additional data and new components
- Add 4 new ViewComponents to the report layout
- Implement Playwright-based HTML → PDF export
- Add PDF download button on report page (sidebar "리포트 내보내기" stays disabled — global nav can't reference per-property URLs)

### Out of Scope

- F03 Net Profit Calculator (separate feature, P1)
- F06 Eviction Scenario Guide (separate feature, P2)
- HUG opportunity auto-detection (separate task)

---

## 2. Report Screen Structure

### Layout

The report is rendered at the existing URL `/properties/:id/inspections/grade` using the existing `inspections/layout` with `active_tab: "grade"`. For PDF export, a dedicated `report_pdf` layout is used (no sidebar, header, or Stimulus controllers).

### Section Order

| # | Component | Status | Description |
|---|-----------|--------|-------------|
| 1 | PropertyInfoComponent | **New** | Property basic info card |
| 2 | BudgetSummaryComponent | **New** | Budget settings summary card |
| 3 | GradeSummaryComponent | Existing | Safety grade badge (safe/caution/danger/incomplete) |
| 4 | BidOpinionComponent | **New** | Bid recommendation with supporting figures |
| 5 | TabSummaryTableComponent | Existing | Per-tab safe/risk/unanswered counts |
| 6 | RiskItemsListComponent | Existing | Risk items grouped by resolvability |
| 7 | ReportSummaryComponent | Existing | Base right, assumed amount, opportunity |
| 8 | RegistryTimelineComponent | Existing | Rights and tenant timeline |
| 9 | DividendSimulatorComponent | Existing | Distribution simulation |
| 10 | ConsultationGuideComponent | **New** | Dynamic expert consultation guide |
| 11 | LegalDisclaimerComponent | Existing | Legal disclaimer footer |

### Removed from Report

- `SourceDocViewerComponent` — Descoped in SRS v2.2. Users have local PDF copies.

---

## 3. New Components

### 3.1 PropertyInfoComponent

Displays property basic information in a card layout.

**Inputs:** `property` (Property model)

**Fields displayed:**
- 사건번호 (`case_number`)
- 소재지 (`address`)
- 물건유형 (`property_type`)
- 감정가 (`appraisal_price`, formatted in 억/만원)
- 최저매각가격 (`min_bid_price`, formatted)
- 전용면적 (`exclusive_area`, ㎡)
- 유찰횟수 (`failed_bid_count`)
- 청구금액 (`claim_amount`, formatted)

**Layout:** 2-column grid card with label-value pairs.

### 3.2 BudgetSummaryComponent

Displays the user's budget settings relevant to this analysis.

**Inputs:** `budget_setting` (BudgetSetting model)

**Fields displayed:**
- 가용 자금 (`available_cash`, 만원)
- 대출 비율 (`loan_ratio`, %)
- 최대 입찰가 (`max_bid_amount`, 만원 → formatted)
- 예비비 합계 (`total_reserves`, 만원)
- 선택 지역 (`region`)

**Layout:** Compact card with key figures. If no budget setting exists, show a prompt to complete onboarding.

### 3.3 BidOpinionComponent

Rule-based bid recommendation with supporting figures.

**Inputs:** `rating` (symbol), `report` (RightsAnalysisReport), `risk_results` (array), `budget_setting` (BudgetSetting), `property` (Property)

**Verdict rules:**

| Rating | Verdict | Description |
|--------|---------|-------------|
| `:danger` | "입찰을 권하지 않습니다" | Lists unresolvable risk items by name |
| `:caution` | "입찰 검토 가능하나 확인 필요" | Lists resolvable risk items + assumed amount |
| `:safe` | "입찰 검토 가능합니다" | No risk items, basic summary |
| `:incomplete` | "분석이 완료되지 않았습니다" | Shows unanswered item count, completion prompt |

**Key figures table (always shown):**

| Label | Source |
|-------|--------|
| 감정가 | `property.appraisal_price` |
| 최저매각가격 | `property.min_bid_price` |
| 인수금액 | `report.assumed_amount` |
| 총 위험금액 | `report.total_risk_amount` |
| 대항력 있는 임차인 수 | `report.effective_tenants.count { opposing_power }` |
| 최대 입찰가 (예산 기준) | `budget_setting.max_bid_amount` |
| 낙찰자 부담액 | `report.report_data["user_simulation"]["bidder_burden"]` (if present) |

**Layout:** Colored verdict banner (matching GradeSummaryComponent colors) + reasoning text + 2-column figures table.

### 3.4 ConsultationGuideComponent

Dynamically matches risk items to relevant professional consultants.

**Inputs:** `risk_results` (array of InspectionResult with has_risk: true)

**Matching rules:**

| Tab | Professional | Scope |
|-----|-------------|-------|
| rights_analysis | 법무사/변호사 | 등기 권리관계 확인 및 인수 여부 판단 |
| property_analysis | 법무사 + 건축사 | 건축물 하자, 위반건축물 확인 |
| profit_analysis | 세무사 + 은행/대출 컨설턴트 | 취득세, 양도세 계산 및 대출 가능 여부 확인 |
| field_check | 공인중개사 | 현장 상태 확인 및 시세 검증 |
| bidding | 법무사 | 입찰 절차 및 보증금 관련 확인 |

**Output:** For each matched professional type, show:
- Professional type and scope
- List of specific risk items (code + question) that triggered the recommendation

**Visibility:** Component is not rendered if there are no risk items.

---

## 4. Controller Changes

### GradesController#show

Add to existing data loading:

```ruby
def show
  # Existing
  @property = ...
  @rating = InspectionRatingService.call(...)
  @report = ...
  @results_by_tab = ...
  @risk_results = ...

  # New
  @budget_setting = current_user.budget_setting

  respond_to do |format|
    format.html
    format.pdf { send_pdf }
  end
end
```

### Sidebar

Keep "리포트 내보내기" as `enabled: false` in the global sidebar. The sidebar is rendered without property context, so it cannot link to a per-property PDF. Instead, a "PDF 다운로드" button is placed directly on the report page header.

---

## 5. PDF Export

### Architecture

```
GET /properties/:id/inspections/grade.pdf
  → GradesController#show (format.pdf)
  → render report HTML with layout: "report_pdf"
  → PdfExportService.call(html:)
  → Playwright renders HTML → page.pdf()
  → send_data PDF binary
```

### PdfExportService

**Location:** `app/services/pdf_export_service.rb`

**Interface:** `PdfExportService.call(html:, filename:) → PDF binary string`

**Implementation:**
1. Launch Playwright browser (headless Chromium)
2. `page.set_content(html)` — load rendered HTML with inline CSS (see Asset Handling below)
3. `page.pdf(format: "A4", margin: { top: "20mm", bottom: "20mm", left: "15mm", right: "15mm" }, print_background: true)`
4. Return PDF binary
5. Close browser

**Synchronous execution (MVP):** PDF generation runs synchronously in the request cycle (~2-5s). Acceptable for MVP with low traffic. Future optimization: move to ActiveJob + ActionCable push notification (same pattern as PdfAnalysisJob).

### Asset Handling (CSS Inlining)

**Problem:** `page.set_content(html)` runs in an empty browser context (`about:blank`). Relative asset paths (`/assets/tailwind-xxx.css`) cannot be resolved, resulting in unstyled PDF output. Using absolute URLs risks Puma deadlock when a single-threaded worker serves both the user request and the Playwright CSS request simultaneously.

**Solution:** Inline all CSS directly into the PDF layout HTML.

The `report_pdf` layout uses `<style>` tags with CSS content read from the compiled asset files at render time:

```erb
<style><%= Rails.application.assets.load_path.find("tailwind.css")&.content&.html_safe %></style>
```

This ensures:
- No external HTTP requests from Playwright
- No Puma deadlock risk
- CSS is self-contained in the HTML string

### PDF Layout (`report_pdf`)

Dedicated layout (`app/views/layouts/report_pdf.html.erb`) for PDF rendering:
- No sidebar, header, navigation, Stimulus controllers
- Tailwind CSS inlined via `<style>` tag (see Asset Handling above)
- Light theme only (no dark mode classes)
- Print-optimized typography
- Korean font: system `fonts-noto-cjk` package (see Docker Requirements below)

### Docker Requirements

The production Dockerfile (`ruby:3.4.8-slim` based) must include Chromium and Korean fonts for PDF generation.

**Additions to final stage (`FROM base`):**

```dockerfile
# Install Chromium and Korean fonts for PDF export
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      chromium \
      fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives
```

**Why:**
- `chromium` — Playwright's headless browser for HTML → PDF conversion
- `fonts-noto-cjk` — Korean/CJK font package. Without this, all Korean text renders as tofu (ㅁㅁㅁ) in the PDF.

**Playwright configuration:** Set `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium` environment variable so Playwright uses the system Chromium instead of downloading its own.

### Print CSS

Applied to the PDF layout:
- `DividendSimulatorComponent`: hide input form, show results only
- Page breaks: `break-before: page` on major sections (5, 7, 9) with `page-break-before: always` as fallback for older renderers
- Hide interactive elements (buttons, forms, links styled as buttons)
- Force light background colors

### Filename

`경매분석리포트_{case_number}_{YYYY-MM-DD}.pdf`

Example: `경매분석리포트_2024타경12345_2026-04-13.pdf`

---

## 6. Data Flow

```
User opens /properties/:id/inspections/grade
  │
  ├── GradesController loads:
  │     @property (Property)
  │     @budget_setting (BudgetSetting)
  │     @rating (InspectionRatingService)
  │     @report (RightsAnalysisReport)
  │     @results_by_tab (InspectionResults grouped)
  │     @risk_results (has_risk: true results)
  │
  ├── HTML response renders 11 components in order
  │
  └── User clicks "PDF 다운로드"
        │
        ├── GET /properties/:id/inspections/grade.pdf
        ├── Same controller, format.pdf branch
        ├── Renders HTML with report_pdf layout
        ├── PdfExportService converts to PDF
        └── Browser downloads file
```

---

## 7. Route Changes

```ruby
# No new routes needed — .pdf format handled by existing resource route
# Existing: GET /properties/:id/inspections/grade → inspections/grades#show
# New format: respond_to { |f| f.html; f.pdf }
```

---

## 8. Testing Strategy

### Unit Tests (Minitest)

- **BidOpinionComponent:** Test all 4 verdict states with expected text output
- **ConsultationGuideComponent:** Test each tab-to-professional mapping; test empty state (no risk items → not rendered)
- **PropertyInfoComponent:** Test rendering with complete and partial property data
- **BudgetSummaryComponent:** Test rendering with budget; test nil budget fallback
- **PdfExportService:** Test that valid HTML produces non-empty PDF binary (integration test with Playwright)

### Controller Tests

- `GradesController#show` HTML format: verify all instance variables are set
- `GradesController#show` PDF format: verify response content type is `application/pdf`

### Existing Tests

- Verify existing component tests still pass (no regressions from layout changes)

---

## 9. SRS Impact

This implementation completes:
- **F02 acceptance criteria:** "최종등급 correctly aggregates all 89 items into safety grade" → BidOpinionComponent + existing GradeSummaryComponent
- **F05 acceptance criteria:** All 4 items (PDF export with inspection results, consultation guide, downloadable, Korean text)

After this work:
- F02 remaining: HUG opportunity auto-detection only
- F05: Complete
- Sidebar "리포트 내보내기" remains disabled (PDF download button on report page instead)
