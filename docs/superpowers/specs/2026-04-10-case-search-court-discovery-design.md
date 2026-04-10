# Case Search Court Auto-Discovery

## Problem

The `CaseSearchClient` (HTTP API, PGJ159M00) requires a `court_code` parameter, but users only input a case number (e.g., `2026타경1234`). Currently, `PropertiesController#create` bypasses this client entirely and uses `PropertyDataSyncService` → `BrowserClient` (Playwright), which is slower.

## Solution

Add a court auto-discovery method to `CaseSearchService` that iterates through all 60 courts to find which court holds the case. Once found, delegate to `PropertyDataSyncService` for full detail parsing via the existing browser-based flow.

## Flow

```
User inputs case number
  → PropertiesController#create
    → CaseSearchService.find_by_case_number(case_number:)
      → CaseNumberParser extracts year, type, serial
      → Iterate 60 courts with adaptive rate limiting
      → First match → early return (court_code + raw_data)
      → No match → nil
    → If found → PropertyDataSyncService.call(case_number:) for full detail
    → Create UserProperty
```

## Components

### 1. CaseSearchService — New Class Method

```ruby
CaseSearchService.find_by_case_number(case_number:)
# Returns: Result(properties:, error:)
```

- Iterates courts in priority order (see below)
- Calls `CaseSearchClient#search(court_code:, case_number:)` per court
- Returns on first valid response (early return)
- Returns error if all courts exhausted or too many consecutive HTTP failures

### 2. Court Priority Order

Courts are ordered by volume to minimize average search time:

1. **Seoul** (5): 서울중앙, 서울동부, 서울서부, 서울남부, 서울북부
2. **Gyeonggi** (7): 수원, 성남, 안산, 안양, 의정부, 고양, 남양주
3. **Incheon** (2): 인천, 부천
4. **Remaining** (46): All other courts in existing COURT_CODES order

### 3. Adaptive Rate Limiting

| State | Delay |
|---|---|
| Normal (valid response or "not found") | 0.5s |
| HTTP error (timeout, 5xx, connection) | Double previous delay |
| Maximum delay | 5.0s |
| Reset to normal | After any successful response |
| Abort threshold | 5 consecutive HTTP errors |

### 4. PropertiesController#create — Modified Flow

```
Before:
  case_number → PropertyDataSyncService.call(case_number:)

After:
  case_number → CaseSearchService.find_by_case_number(case_number:)
  → if found → PropertyDataSyncService.call(case_number:, user:)
  → if not found → error message
```

Error handling reuses existing `error_message_for` patterns.

### 5. UI Changes

None. Existing case number input + "+" button remain unchanged.

## Error Handling

| Scenario | User Message |
|---|---|
| All 60 courts — not found | 해당 사건번호의 물건을 찾을 수 없습니다. |
| Aborted due to consecutive HTTP errors | 법원경매 사이트에 접속할 수 없습니다. 잠시 후 다시 시도해주세요. |
| Found but detail fetch fails | Existing PropertyDataSyncService error handling |
| Invalid case number format | 사건번호 형식이 올바르지 않습니다. (예: 2026타경1234) |

## Testing Strategy

- **Unit**: `CaseSearchService#find_by_case_number` with mocked adapter
  - Court iteration order verification
  - Early return on first match
  - Adaptive rate limiting (delay increase on error, reset on success)
  - Abort after 5 consecutive errors
  - All courts exhausted → not found
- **Controller integration**: `PropertiesController#create` with new flow
  - Success path: find → sync → redirect with notice
  - Not found path: error message
  - Already exists path: unchanged behavior

## Decisions

- **Sync over async**: Users already expect waiting (current BrowserClient is slow). Background job adds complexity without UX gain at this stage.
- **raw_data only from discovery, full parse from sync**: PGJ159M00 response format differs from PGJ151F00. Reusing PropertyDataSyncService avoids building a new parser. Can optimize later by parsing PGJ159M00 directly.
- **Priority ordering**: Seoul/Gyeonggi/Incheon courts handle the majority of auction volume. Trying them first reduces average discovery time.
