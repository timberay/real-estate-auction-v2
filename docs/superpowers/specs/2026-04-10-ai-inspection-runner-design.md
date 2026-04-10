# AI Inspection Runner Design

## Overview

Replace keyword-based inspection rules with LLM-powered analysis for the 29 rights analysis checklist items. The current `InspectionRunner` uses pattern matching on limited fields and only auto-detects 3/29 items. An `AiInspectionRunner` using LLM contextual analysis can determine 22/29 items from the same data.

## Motivation

Simulation results on case `2025타경102360` (apartment with 임차권등기 risk):

| Method | Items Determined | Coverage |
|--------|-----------------|----------|
| Current InspectionRunner (keyword rules) | 3/29 | 10% |
| LLM analysis (same data) | 22/29 | 76% |
| LLM + additional scraping (future) | 27-28/29 | 93-97% |

The gap exists because keyword matching cannot interpret contextual meaning (e.g., "매수인에게 대항할 수 있는 을구 5번 임차권등기" implies risk for rights-002, rights-013, rights-015, rights-023 simultaneously), while LLM can.

## Scope

**In scope (Phase 1):**
- LLM-based inspection using currently collected data (Property + SaleDetail + AppraisalPoints)
- Mock adapter for development/testing, real adapter structure for future API connection
- Fallback to existing InspectionRunner on failure
- `source_type: "ai"` enum addition

**Out of scope:**
- Additional web scraping (tenant lists, field inspection reports)
- External registry API integration (Tilko, IROS)
- UI changes beyond existing AI badge display

## Architecture

```
PropertyInspectionService.call(property:, user:)
  ├── [primary] AiInspectionRunner.call(property:, user:)
  │       ├── PropertyDataAssembler.call(property)  → structured text
  │       ├── InspectionPromptBuilder.call(text, items)  → system + user prompt
  │       ├── LlmAdapter.for(:anthropic).analyze(prompt)  → JSON response
  │       └── InspectionResultMapper.call(response, property, user)  → DB records
  │
  ├── [fallback] InspectionRunner.call(property:, user:)
  │       (only runs if AiInspectionRunner raises an error)
  │
  └── RightsAnalysisService.call(property:, user:)  (unchanged)
```

## Component Design

### 1. AiInspectionRunner (`app/services/ai_inspection_runner.rb`)

Main orchestrator. Coordinates the four sub-components below.

```ruby
class AiInspectionRunner
  def self.call(property:, user:)
    new(property:, user:).call
  end

  def call
    text = Inspection::PropertyDataAssembler.call(@property)
    items = InspectionItem.ordered
    prompt = Inspection::InspectionPromptBuilder.call(property_text: text, items: items)
    response = LlmAdapter.for(:anthropic).analyze(system: prompt[:system], prompt: prompt[:user])
    Inspection::InspectionResultMapper.call(
      response: response, property: @property, user: @user, items: items
    )
  end
end
```

### 2. PropertyDataAssembler (`app/services/inspection/property_data_assembler.rb`)

Converts Property + associations into a structured text block for the LLM prompt.

**Input:** Property (with sale_detail, appraisal_points eager loaded)
**Output:** String

```
[물건 기본 정보]
사건번호: 2025타경102360
물건종류: 아파트
소재지: 서울특별시 관악구 신림동 1425-4 9층904호
감정가: 96,000,000원
최저입찰가: 25,166,000원
...

[매각물건명세서]
소멸되지않는권리: 매수인에게 대항할 수 있는 을구 5번 임차권등기가...
물건명세비고: (정보 없음)
...

[감정평가서 주요사항]
- 본건은 서울특별시 관악구 신림동 1425-4 소재 건물의 9층 904호이다.
- 본건은 지하철 2호선 신림역 인근에...
...

[토지 내역]
- 전유 서울특별시 관악구 신림동 1425-4 대 176.2 3.324/416.20
...

[경매 일정]
- 2025-01-14 매각기일 최저가=96,000,000 결과=유찰
...
```

Rules:
- nil/blank fields render as "(정보 없음)" so LLM recognizes data absence
- Monetary values formatted with commas for readability
- All available data included; nothing filtered out

### 3. InspectionPromptBuilder (`app/services/inspection/inspection_prompt_builder.rb`)

Builds system and user prompts.

**Input:** property_text (String), items (InspectionItem collection)
**Output:** `{ system: String, user: String }`

**System prompt:**
```
당신은 대한민국 부동산 경매 권리분석 전문가입니다.
법원경매 물건 데이터를 분석하여 아래 점검 항목에 대해 판정해주세요.

[판정 규칙]
- 각 항목에 대해 has_risk(위험 여부), confidence(확신도), reasoning(판정 근거)을 반환하세요.
- 데이터가 부족하여 판단할 수 없는 항목은 has_risk: null, confidence: "none"으로 반환하세요.
- yes_means_safe=false인 항목은 "예"가 위험을 의미합니다. has_risk는 항상 "이 항목이 위험한가?"를 기준으로 판정하세요.
- reasoning은 반드시 데이터에서 확인한 구체적 근거를 인용하세요.

[응답 형식]
반드시 아래 JSON 형식으로만 응답하세요. 다른 텍스트를 포함하지 마세요.
{
  "results": {
    "<item_code>": {
      "has_risk": true | false | null,
      "confidence": "high" | "medium" | "none",
      "reasoning": "판정 근거 (한국어)"
    }
  }
}
```

**User prompt:**
```
[물건 데이터]
{property_text}

[점검 항목]
rights-001: 등기부에 말소기준권리보다 앞선 선순위 가처분이 있습니까? (yes_means_safe=false, priority=상)
rights-002: 매각물건명세서 '소멸되지 아니하는 것'... (yes_means_safe=true, priority=상)
...전체 29건...
```

### 4. LlmAdapter (`app/adapters/llm_adapter.rb`)

Base class with mock/real switching.

```ruby
class LlmAdapter
  def self.for(provider = :anthropic)
    if ENV["USE_MOCK"] == "true"
      MockLlmAdapter.new
    else
      AnthropicLlmAdapter.new
    end
  end

  def analyze(system:, prompt:)
    raise NotImplementedError
  end
end
```

**MockLlmAdapter** (`app/adapters/mock_llm_adapter.rb`):
- Returns fixture JSON from `test/fixtures/files/ai_inspection_response.json`
- Fixture contains realistic 29-item response based on simulation results

**AnthropicLlmAdapter** (`app/adapters/anthropic_llm_adapter.rb`):
- Uses `anthropic` gem or direct HTTP to Claude API
- Model: `claude-sonnet-4-20250514` (cost-effective for structured analysis)
- Max tokens: 4096
- Timeout: 30 seconds
- API key: `ENV["ANTHROPIC_API_KEY"]` or Rails credentials

### 5. InspectionResultMapper (`app/services/inspection/inspection_result_mapper.rb`)

Maps LLM JSON response to InspectionResult records.

**Input:** parsed JSON response, property, user, items
**Output:** Array of InspectionResult records (saved)

**Mapping rules:**
| LLM confidence | source_type | has_risk | evidence |
|---------------|-------------|----------|----------|
| "high" | ai | LLM value | `{ source_label: "AI 분석", reasoning: "...", confidence: "high" }` |
| "medium" | ai | LLM value | `{ source_label: "AI 분석 (추론)", reasoning: "...", confidence: "medium" }` |
| "none" | nil | nil | nil (remains unanswered) |

**Preservation rules:**
- Manual answers (`source_type: "manual"`) are never overwritten
- Previous AI answers are overwritten on re-analysis
- Previous auto answers (from InspectionRunner) are overwritten by AI

## DB Changes

### InspectionResult.source_type enum

```ruby
# Current
enum :source_type, { auto: 0, manual: 1 }

# New
enum :source_type, { auto: 0, manual: 1, ai: 2 }
```

No migration needed — integer column already exists, just adding enum value.

### No new tables or columns

AI reasoning stored in existing `evidence` JSON field. Confidence stored within evidence JSON.

## File Structure

```
app/
  adapters/
    llm_adapter.rb                          # Base class (new)
    mock_llm_adapter.rb                     # Mock implementation (new)
    anthropic_llm_adapter.rb                # Real implementation (new, stub for Phase 1)
  services/
    ai_inspection_runner.rb                 # Main orchestrator (new)
    inspection/
      property_data_assembler.rb            # Property → text (new)
      inspection_prompt_builder.rb          # Prompt generation (new)
      inspection_result_mapper.rb           # LLM response → DB (new)
    property_inspection_service.rb          # Add try/fallback (modify)
    inspection_runner.rb                    # Unchanged
  models/
    inspection_result.rb                    # Add ai: 2 to source_type enum (modify)
test/
  fixtures/files/
    ai_inspection_response.json             # Mock response fixture (new)
  services/
    ai_inspection_runner_test.rb            # (new)
    inspection/
      property_data_assembler_test.rb       # (new)
      inspection_prompt_builder_test.rb     # (new)
      inspection_result_mapper_test.rb      # (new)
```

**Summary: 8 new files, 2 modified files**

## Testing Strategy

- Unit tests for each sub-component (assembler, prompt builder, mapper)
- Integration test: AiInspectionRunner with MockLlmAdapter end-to-end
- Fallback test: AiInspectionRunner failure triggers InspectionRunner
- Manual override preservation test

## Future Extensions (out of scope)

- Phase 2: Additional scraping (tenant lists, field inspection reports) → 27-28/29 coverage
- Phase 3: External registry API (Tilko/IROS) → 29/29 coverage
- UI: Differentiate AI confidence levels with visual indicators
- Cost monitoring: Track API usage per property analysis
