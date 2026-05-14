# PDF-Based Analysis Redesign

**Date**: 2026-04-11
**Status**: Approved
**Supersedes**: 2026-04-10-ai-inspection-runner-design.md (partial), 2026-04-09-court-auction-pipeline-completion-design.md (partial)

## Problem

The current analysis pipeline feeds structured API data (raw_data from courtauction.go.kr) to the LLM for property inspection. However:

1. **API data is insufficient** — Government API fields are cryptic codes (`csNo`, `aeeEvlAmt`, `bidDvsCd`) with no semantic context, and even when mapped, they lack the depth needed for rights analysis.
2. **Critical documents are missing** — The majority of high-priority inspection items (매각물건명세서, 현황조사서, 감정평가서, 등기부등본) require full legal documents that the API does not provide.
3. **Automated document scraping is impractical** — Court auction documents use POST-based navigation, special viewers, and session-dependent access. Maintenance cost far exceeds benefit.

## Decision

Replace the structured-data-to-LLM pipeline with a **PDF-upload-based analysis** approach:
- Users upload PDF documents (printed from court auction site or other sources)
- LLM analyzes PDF content directly (multimodal)
- LLM extracts metadata + answers inspection items in a single call
- List search (criteria search) is retained for property discovery only

## Design

### 1. Removal Scope

#### Tables to Drop
| Table | Reason |
|---|---|
| `property_sale_details` | Populated only by case detail search (removed) |
| `land_details` | Populated only by case detail search (removed) |
| `appraisal_points` | Populated only by case detail search (removed) |

#### Columns to Remove
| Table | Column | Reason |
|---|---|---|
| `properties` | `raw_data` | No longer storing raw API responses |

#### Code to Remove
| File/Module | Reason |
|---|---|
| `BrowserClient#fetch_with_detail` | Case detail search removed |
| `ResponseParser#parse_case_search`, `#parse_with_detail`, `#merge_detail` | Case detail parsing removed |
| `PropertyDataSyncService` | Detail search → DB sync removed |
| `PropertyDataAssembler` | Structured-data-to-text assembly removed |
| `InspectionPromptBuilder` | Replaced by PdfPromptBuilder |
| `AiInspectionRunner` | Replaced by PdfAnalysisService |
| `InspectionRunner` | Rule-based fallback removed (depended on raw_data/sale_detail) |
| `PropertyInspectionService` | Orchestrator replaced by PdfAnalysisService |
| `RightsAnalysisService` + 5 sub-services | Raw-data-based rights analysis removed |
| `CaseSearchClient` | Case number search removed |
| `CaseSearchService` | Case number search removed |
| `CaseNumberParser` | Case number validation removed |

#### Code to Retain
| File/Module | Reason |
|---|---|
| `CriteriaSearchClient` | Criteria-based list search |
| `ResponseParser#parse` | List search result parsing |
| `CourtAuctionSearchService` | Criteria search orchestration |
| `InspectionResultMapper` | LLM response → InspectionResult mapping |
| `InspectionRatingService` | Safety rating calculation |
| `BudgetCalculationService`, `BudgetSnapshotService` | Budget features |
| All LLM adapters (`Llm::Base`, `Anthropic`, `Gemini`, etc.) | LLM communication |

### 2. PDF Upload & Storage

**Active Storage** is adopted for document management.

```ruby
# Property model
class Property < ApplicationRecord
  has_many_attached :documents
end
```

- Storage: Local disk (existing `config/storage.yml` disk configuration)
- Accepted format: PDF only (mime type validation)
- No file count or size limit enforced at application level

#### Two Entry Paths

**Path 1 — From property card:**
1. User searches by criteria → selects property → property card displayed
2. User uploads PDFs via document upload area on property card
3. User clicks "분석 시작" → `PdfAnalysisService.call(property:, user:)`

**Path 2 — Direct analysis (no prior search):**
1. User navigates to "새 분석" menu
2. User uploads PDFs
3. User clicks "분석 시작" → `PdfAnalysisService.call(documents:, user:)`
4. LLM extracts metadata → Property matched by `case_number` (if exists, documents are attached to it and analysis results are updated) or created as new record
5. Redirects to property show page with results

### 3. LLM Analysis Pipeline

#### Service Structure

```
app/services/
├── pdf_analysis_service.rb              # Orchestrator (replaces PropertyInspectionService)
├── inspection/
│   ├── pdf_prompt_builder.rb            # PDF prompt assembly (replaces InspectionPromptBuilder)
│   └── inspection_result_mapper.rb      # Retained — LLM response → InspectionResult
```

#### PdfAnalysisService Flow

```ruby
PdfAnalysisService.call(property:, user:)    # Path 1
PdfAnalysisService.call(documents:, user:)   # Path 2
```

1. Collect PDF files from `property.documents` or `documents` parameter
2. Build prompt via `PdfPromptBuilder.call(documents:, items:)`
3. Call `Llm::Base.for(user).analyze(system:, prompt:, documents:)`
4. Parse response JSON:
   - `metadata` → find/create Property (Path 2), or validate (Path 1)
   - `results` → map to InspectionResult records via `InspectionResultMapper`
5. Log to `LlmAnalysisLog`
6. Calculate safety rating via `InspectionRatingService`

#### Prompt Structure

**System prompt:**
```
당신은 대한민국 부동산 경매 권리분석 전문가입니다.
첨부된 PDF 문서들을 분석하여 아래 작업을 수행하세요.

[작업 1: 메타데이터 추출]
문서에서 다음 정보를 추출하세요:
- court_name: 관할 법원명
- case_number: 사건번호 (예: 2024타경964)
- address: 소재지
- property_type: 물건종류
- appraisal_price: 감정가
- min_bid_price: 최저입찰가

[작업 2: 점검항목 판정]
각 항목에 대해 has_risk, confidence, reasoning을 반환하세요.

[판정 규칙]
- 데이터가 부족하여 판단할 수 없는 항목은 has_risk: null, confidence: "none"
- yes_means_safe=false인 항목은 "예"가 위험을 의미
- reasoning은 반드시 문서에서 확인한 구체적 근거를 인용

[응답 형식]
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
  }
}
```

**User prompt:**
```
[첨부 문서]
(PDF files attached via LLM API document/file parameters)

[점검 항목]
rights-002: 매각물건명세서 '소멸되지 아니하는 것'... (yes_means_safe=true, priority=상)
rights-011: 매각물건명세서 비고란에 유치권... (yes_means_safe=false, priority=상)
...
```

#### LLM Adapter Interface Change

```ruby
# Before
Llm::Base#analyze(system:, prompt:)

# After
Llm::Base#analyze(system:, prompt:, documents: [])
```

#### PDF Support by Provider

PDF analysis requires native multimodal document support. Not all LLM providers support this equally.

| Provider | PDF Support | Structured Output | MVP Status |
|---|---|---|---|
| **Anthropic Claude** | Native (`document` content block, base64) | Tool Use with JSON schema | **Supported** |
| **Gemini** | Native (`inlineData` with PDF mime type) | `response_mime_type: "application/json"` + `response_schema` | **Supported** |
| **OpenAI** | Limited (may require PDF-to-image conversion) | JSON Mode / Structured Outputs | **Not supported in MVP** — returns clear error |
| **OpenRouter** | Depends on underlying model | Varies | **Not supported in MVP** — returns clear error |
| **Ollama** | Not supported | Varies | **Not supported in MVP** — returns clear error |
| **Mock** | Returns predefined response | N/A | **Supported** (for testing) |

Unsupported providers raise a descriptive error: "이 모델은 PDF 분석을 지원하지 않습니다. Anthropic Claude 또는 Gemini를 사용해주세요."

PDF-to-text fallback for unsupported providers is deferred to post-MVP.

#### Structured Output Enforcement

LLM responses must be valid JSON. Each adapter enforces this at API parameter level:
- **Anthropic**: Use Tool Use to define response JSON schema, forcing structured output
- **Gemini**: Set `response_mime_type: "application/json"` and provide `response_schema`
- **Defensive parsing**: All adapters strip markdown code fences (```json ... ```) and extract JSON via regex before parsing, as a safety net

### 4. Controller & Route Changes

#### New Controllers

```ruby
# PDF document management on existing property
Properties::DocumentsController
  create   # Upload PDFs (Turbo Frame response)
  destroy  # Remove individual PDF

# Standalone analysis (Path 2)
AnalysesController
  new      # Upload form
  create   # Upload + trigger analysis → redirect to property show
```

#### Modified Controllers

```ruby
# Trigger changed from structured-data analysis to PDF analysis
Inspections::StartController#create
  # Before: PropertyInspectionService.call
  # After:  PdfAnalysisService.call(property:, user:)
  # Error if no documents attached
```

#### Routes

```ruby
resources :properties do
  resources :documents, only: [:create, :destroy],
            controller: "properties/documents"
  # Existing inspection routes retained
end

resources :analyses, only: [:new, :create]
```

#### Routes/Features Removed
- `properties#create` case-number-based addition logic
- Case search related routes

#### Routes/Features Retained
- `SearchResultsController` (criteria search + import)
- `Inspections::TabsController`, `GradesController` (result viewing)
- `PropertiesController#index`, `#show`
- All settings controllers

### 5. Data Model Summary

#### Properties Table (After)

```ruby
# Retained columns (populated by list search)
:case_number, :case_type, :address, :sido, :sigungu, :dong,
:property_type, :appraisal_price, :min_bid_price,
:building_name, :building_detail, :building_structure,
:exclusive_area, :land_category, :status, :remarks,
:special_conditions_code, :claim_amount, :failed_bid_count,
:view_count, :interest_count, :latitude, :longitude, :property_count

# Removed
:raw_data

# Added
has_many_attached :documents  # Active Storage
```

#### Tables Dropped
- `property_sale_details`
- `land_details`
- `appraisal_points`

#### Tables Retained (No Changes)
- `auction_schedules`
- `search_results`
- `inspection_items`
- `inspection_results`
- `rights_analysis_reports`
- `llm_analysis_logs`
- `user_properties`
- All settings/reference tables

### 6. Upload UI

- Drag-and-drop or file picker on property card / standalone analysis page
- PDF-only validation (client + server)
- Uploaded file list displayed with delete option
- "분석 시작" button activates after at least one PDF uploaded
- Analysis runs as background job with step-by-step progress feedback (see section 7)

### 7. Analysis Progress Feedback

PDF analysis can take significant time (tens of seconds to minutes) depending on document size and count. Users must see real-time progress.

**Implementation:** Turbo Stream broadcasts via Solid Cable (Action Cable already configured).

**Progress steps displayed to user:**
1. "문서 업로드 완료" — PDFs received
2. "AI 분석 중..." — LLM API call in progress
3. "결과 저장 중..." — Parsing response and saving InspectionResults
4. "분석 완료" — Redirect to results page

**Technical flow:**
- `PdfAnalysisJob` (background job) broadcasts status updates to a user-specific Turbo Stream channel
- UI shows a progress indicator with current step
- On completion, Turbo Stream replaces the progress area with a link to results (or auto-redirects)
- On failure, error message is displayed inline

No estimated time is shown (too variable). Step-based progress is sufficient.

### 8. Privacy & Data Retention

Uploaded PDFs may contain personal information (owner names, partial resident registration numbers, addresses from 등기부등본).

**MVP policy:**
- **Storage**: PDFs stored on local disk via Active Storage. Retained for re-analysis.
- **User control**: Users can delete individual documents at any time via `DocumentsController#destroy`
- **Upload notice**: Upload UI displays a notice: "업로드된 문서는 AI 분석을 위해 외부 API(선택한 LLM 제공자)로 전송됩니다."
- **No automatic purge** in MVP — manual deletion only

**Post-MVP considerations:**
- Automatic purge policy (e.g., delete PDFs N days after analysis)
- Server-side encryption at rest
- Audit log for document access
