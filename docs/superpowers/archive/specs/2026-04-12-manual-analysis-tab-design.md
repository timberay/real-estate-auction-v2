# Manual Analysis Tab Design

## Overview

Add a "수동분석" (Manual Analysis) tab alongside the existing "AI자동분석" (Auto Analysis) tab on the `analyses/new` page. This allows users who cannot use the AI API directly to:

1. Download a prompt as a `.md` file to use with their own AI
2. Upload the resulting JSON file
3. Process it into the DB using the same pipeline as auto-analysis

## Motivation

Some users may not have access to (or budget for) AI API keys. They can still perform analysis by copying the prompt into any AI chat interface (ChatGPT, Claude, Gemini, etc.), attaching their PDF documents, and receiving a JSON response to upload back.

## Approach

**Extend `PdfAnalysisService`** with a `response_json:` parameter. When provided, skip the LLM call and process the user-supplied JSON through the existing pipeline (InspectionResultMapper, RightsValidator, RightsAnalysisReport, InspectionRatingService). This is synchronous (no background job needed).

## UI Structure

```
┌──────────────────────────────────────────┐
│  새 분석                                   │
│  ┌───────────────┬───────────────┐       │
│  │ AI 자동분석    │  수동분석      │       │
│  └───────────────┴───────────────┘       │
│                                           │
│  [AI 자동분석 탭] (existing, unchanged)    │
│  PDF upload form → background job → toast │
│                                           │
│  [수동분석 탭]                             │
│  ① "프롬프트 다운로드" button              │
│     → GET /analyses/prompt → .md file     │
│  ② JSON file upload input                 │
│  ③ "분석 결과 저장" button                 │
│     (disabled until JSON file selected)   │
│     → POST /analyses/manual               │
│     → synchronous processing              │
│     → redirect to inspection tab          │
└──────────────────────────────────────────┘
```

Tab switching uses a Stimulus controller (no Turbo Frame needed — both forms are lightweight and rendered together, toggled via CSS visibility).

## Routes

```ruby
resources :analyses, only: [:new, :create] do
  collection do
    get :prompt    # Download prompt as .md
    post :manual   # Upload JSON and process
  end
end
```

## Components

### 1. Prompt Download (`GET /analyses/prompt`)

**Controller action:** `AnalysesController#prompt`

Generates a markdown file from `Inspection::PdfPromptBuilder`:

```markdown
# 부동산 경매 AI 분석 프롬프트

아래 내용을 AI에게 전달하고, 법원경매 PDF 문서(매각물건명세서, 현황조사서, 감정평가서, 등기부등본)와 함께 분석을 요청하세요.

**중요:** 결과는 반드시 마지막 섹션의 JSON 형식으로 받아주세요.

---

## 시스템 프롬프트

(PdfPromptBuilder::SYSTEM_PROMPT content)

## 사용자 프롬프트

(PdfPromptBuilder user prompt with inspection items)

---

## 기대 응답 형식 (JSON)

AI의 응답이 아래 구조를 따르는지 확인하세요:

{
  "metadata": { "court_name": "...", "case_number": "...", ... },
  "results": { "<item_code>": { "has_risk": true|false|null, "confidence": "high"|"medium"|"none", "reasoning": "..." } },
  "rights_analysis": { "verdict": "safe"|"caution"|"danger", ... }
}
```

Response: `send_data` with `filename: "auction-analysis-prompt.md"`, `type: "text/markdown"`.

### 2. JSON Upload & Processing (`POST /analyses/manual`)

**Controller action:** `AnalysesController#manual`

**Flow:**
1. Accept single `.json` file upload
2. Parse JSON, validate structure
3. Call `PdfAnalysisService.call(response_json: parsed_json, user: current_user)`
4. On success: redirect to `edit_property_inspections_tab_path(property, tab_key: "rights_analysis")`
5. On failure: re-render form with flash error

**JSON validation (server-side):**
- Valid JSON parse
- Top-level keys: `metadata`, `results` (required); `rights_analysis` (optional)
- `metadata.case_number` must be present (non-blank)
- Validation errors return user-friendly Korean messages

### 3. PdfAnalysisService Extension

Add `response_json:` keyword parameter (default: `nil`):

```ruby
def self.call(property: nil, documents: nil, user:, response_json: nil)
  new(property:, documents:, user:, response_json:).call
end
```

In `#call`, when `response_json` is present:
- Skip `collect_documents`, `PdfPromptBuilder`, and `Llm::Base.for.analyze` calls
- Use `response_json` directly as the response
- Continue with existing: `resolve_property`, `InspectionResultMapper`, `RightsValidator`, `RightsAnalysisReport`, `LlmAnalysisLog` (with `provider: "manual"`, `model: "user_input"`), `InspectionRatingService`

### 4. Stimulus Controller: `manual-analysis`

Responsibilities:
- Toggle tab visibility (auto vs manual panels)
- Track JSON file selection state
- Enable/disable submit button based on file presence
- Show selected filename

Targets: `autoTab`, `manualTab`, `autoPanel`, `manualPanel`, `jsonInput`, `submitButton`, `fileName`

### 5. LlmAnalysisLog for Manual Analysis

Manual analysis is logged with:
- `provider: "manual"`
- `model: "user_input"`
- `system_prompt` / `user_prompt`: stored as "manual_upload" (no actual prompt was sent)
- `response_json`: the user-uploaded JSON (for audit trail)
- `status: :completed`

## Error Handling

| Error | Message |
|-------|---------|
| No file uploaded | "JSON 파일을 업로드해주세요." |
| Invalid JSON | "유효한 JSON 파일이 아닙니다." |
| Missing `metadata` key | "JSON에 metadata 키가 필요합니다." |
| Missing `results` key | "JSON에 results 키가 필요합니다." |
| Missing `case_number` | "metadata.case_number가 필요합니다." |
| DB save failure | Transaction rollback + "분석 결과 저장 중 오류가 발생했습니다: (detail)" |

## Testing Strategy

- **Service test**: `PdfAnalysisService` with `response_json:` parameter — verifies LLM is not called, results are mapped correctly
- **Controller tests**: `#prompt` returns markdown file; `#manual` with valid/invalid JSON
- **Stimulus**: Tab switching, button enable/disable on file selection
- **Integration**: Full flow from JSON upload to inspection tab redirect

## Out of Scope

- JSON schema deep validation (e.g., checking every result item code matches InspectionItem codes) — the existing mapper handles unknown codes gracefully
- Drag-and-drop file upload — standard file input is sufficient for MVP
- Editing JSON in-browser before submission
