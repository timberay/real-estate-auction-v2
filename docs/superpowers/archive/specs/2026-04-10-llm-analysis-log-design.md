# LLM Analysis Log — Design Spec

## Summary

Extend the existing `AiInspectionRunner` pipeline to persist LLM prompts and responses in a new `llm_analysis_logs` table. This enables audit/debugging (trace why a judgment was made) and re-execution (replay a saved prompt against a different LLM provider/model).

## Context

The current pipeline (`AiInspectionRunner` → `PropertyDataAssembler` → `InspectionPromptBuilder` → `Llm::Base.for.analyze` → `InspectionResultMapper`) is transient — prompts and raw LLM responses are not stored. This makes it impossible to audit past decisions or re-run analysis with different models.

## Data Model

### New table: `llm_analysis_logs`

| Column | Type | Description |
|---|---|---|
| `id` | integer (PK) | Auto-increment |
| `property_id` | references (FK) | Target property |
| `user_id` | references (FK, nullable) | User who triggered the analysis. Null for system-triggered (automatic) runs. |
| `system_prompt` | text | Full system prompt |
| `user_prompt` | text | Full user prompt |
| `response_json` | json | Raw LLM response |
| `provider` | string | LLM provider name (anthropic, openai, etc.) |
| `model` | string | Model identifier (e.g., claude-sonnet-4-20250514) |
| `status` | integer | Enum — pending: 0, completed: 1, failed: 2 |
| `error_message` | text | Error details on failure |
| `executed_at` | datetime | Timestamp when LLM call completed |
| `created_at` | datetime | |
| `updated_at` | datetime | |

### Associations

- `Property has_many :llm_analysis_logs`
- `User has_many :llm_analysis_logs`
- `LlmAnalysisLog belongs_to :property`
- `LlmAnalysisLog belongs_to :user, optional: true` (nullable for system-triggered runs)

## Pipeline Flow

### Modified flow (changes marked with `*`)

```
PropertyDataAssembler (* include raw_data section)
  → InspectionPromptBuilder
  → * LlmAnalysisLog.create!(status: :pending, prompts saved)
  → Llm::Base.for.analyze
  → * LlmAnalysisLog update (status: :completed, response_json saved)
  → InspectionResultMapper (writes latest results to InspectionResult)
  [on failure] → * LlmAnalysisLog update (status: :failed, error_message saved)
```

### Execution triggers

1. **Manual** — User clicks "AI 분석" button on property detail page (existing)
2. **Automatic** — `AiInspectionJob` (Solid Queue) enqueued when property data is synced

### Re-execution flow

1. Load existing `LlmAnalysisLog` record
2. Copy `system_prompt` and `user_prompt` to a new log (status: pending)
3. Call LLM with the copied prompts
4. Update new log with response
5. Run `InspectionResultMapper` to update `InspectionResult` with latest

### History policy

- All `LlmAnalysisLog` records are retained (full history)
- `InspectionResult` always reflects the latest completed analysis
- Manual user overrides (`source_type: manual`) are never overwritten by AI results

## File Changes

### Modified files

1. **`app/services/inspection/property_data_assembler.rb`**
   - Add `raw_data_section` method that includes `Property#raw_data` JSON
   - Append to existing sections list

2. **`app/services/ai_inspection_runner.rb`**
   - Create `LlmAnalysisLog` (pending) after prompt generation
   - Update log (completed/failed) after LLM call
   - Pass provider/model metadata from adapter

3. **`app/adapters/llm/base.rb`**
   - Add `provider_name` and `model_id` accessor methods
   - Each subclass returns its provider/model info

### New files

4. **`app/models/llm_analysis_log.rb`**
   - Validations: presence of property, system_prompt, user_prompt (user is optional)
   - Enum for status
   - Scopes: `completed`, `failed`, `latest_for(property)`

5. **`db/migrate/XXXXXX_create_llm_analysis_logs.rb`**
   - Migration for the new table
   - Indexes on `property_id`, `user_id`, `status`

6. **`app/jobs/ai_inspection_job.rb`**
   - Solid Queue job that calls `AiInspectionRunner.call`
   - Enqueued from `PropertyDataSyncService` after successful sync

## Error Handling

- **LLM API timeout/error** → `LlmAnalysisLog` status: failed, error_message recorded. Existing `InspectionResult` unchanged.
- **JSON parse failure** → Raw response saved as string in response_json, status: failed.
- **Existing fallback preserved** — `PropertyInspectionService` falls back to rule-based `InspectionRunner` when AI fails.

## Testing Strategy

- **`LlmAnalysisLog` model test** — validations, enum, associations, scopes
- **`AiInspectionRunner` integration test** — log creation on success, failure, and re-execution
- **`PropertyDataAssembler` test** — verify raw_data section is included
- **`AiInspectionJob` test** — job enqueue and execution
- All tests use `Llm::Mock` adapter (USE_MOCK=true)

## Out of Scope

- UI for browsing analysis history
- Manual prompt editing
- Cost/token tracking
- Batch analysis across multiple properties
