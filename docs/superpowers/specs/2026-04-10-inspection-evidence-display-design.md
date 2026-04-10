# Inspection Auto-Selection Evidence Display

Show users the actual data that drove each auto-selected checklist answer, so they can verify the reasoning behind the "자동" badge.

## Problem

The inspection screen shows "자동" badges on auto-selected items but provides no visibility into what data was used to make the determination. Users have no way to verify whether the auto-selection logic is correct without manually looking up the source documents.

## Decisions

- **Evidence format**: Original data excerpt (field values, keyword match results) — not summarized
- **Placement**: Dedicated evidence block below the Yes/No logic section, always visible for auto items
- **Missing keywords**: Show `해당 없음` (not raw text excerpts)
- **Source labels**: Always show which document/source the data came from
- **No backward compat**: All DETECTION_RULES return Hash with evidence — no boolean fallback
- **Approach**: InspectionRunner generates evidence at detection time, stored in DB

## Data Model

Add `evidence` JSON column to `inspection_results`:

```ruby
add_column :inspection_results, :evidence, :json
```

### Evidence JSON Structure

```json
{
  "source_label": "현황조사서, 물건명세서",
  "fields": [
    { "label": "물건종류", "value": "아파트" }
  ],
  "keywords": {
    "searched": ["유치권", "법정지상권"],
    "found": false
  }
}
```

Two evidence types:

| Type | When | Structure |
|------|------|-----------|
| **Field comparison** | Simple value check (property_type, area, etc.) | `fields` array with label/value pairs |
| **Keyword matching** | Regex pattern against text fields | `keywords` with searched terms and found boolean |

Both types always include `source_label`. A single evidence can have both `fields` and `keywords` if the rule checks both.

## InspectionRunner Changes

Each lambda in `DETECTION_RULES` returns `Hash` or `nil`:

```ruby
# Return format (replaces boolean return)
{ has_risk: true/false, evidence: { source_label: "...", fields: [...], keywords: { ... } } }

# nil = indeterminate (unchanged)
nil
```

Processing logic:

```ruby
detected = rule.call(@property)
if detected.nil?
  # unanswered — unchanged
else
  result.assign_attributes(
    source_type: "auto",
    has_risk: detected[:has_risk],
    evidence: detected[:evidence]
  )
end
```

## Evidence Mapping Per Rule

### Auto Grade (deterministic)

| Code | Question | Type | source_label | Data |
|------|----------|------|-------------|------|
| rights-002 | 소멸되지 않는 인수 권리 | field | 매각물건명세서 | `소멸되지 않는 권리: {value or "없음"}` |
| rights-011 | 유치권·법정지상권 기재 | keyword | 비고, 물건명세서, 현황조사서 | `["유치권", "법정지상권"]` |
| rights-019 | 토지·건물 일체 매각 | field | 법원경매 물건정보 | `물건종류: {val}`, `토지구분: {val}` |
| rights-020 | 유치권 신고 | keyword | 비고, 물건명세서, 현황조사서 | `["유치권"]` |
| property-001 | 비지분 물건 | field | 매각물건명세서 | `지분 내역: {value or "없음"}` |
| property-002 | 벽체 구분·불법 구조변경 | keyword | 비고, 물건명세서, 현황조사서 | `["벽체", "구조변경", "불법증축", "불법개축"]` |
| property-006 | 물건 종류 아파트 여부 | field | 법원경매 물건정보 | `물건종류: {val}` |
| tax-006 | 전용면적 85㎡ 미만 | field | 법원경매 물건정보 | `전용면적: {val}㎡` |
| market-012 | 조회수 500회 미만 | field | 법원경매 물건정보 | `조회수: {val}회` |
| resale-003 | 지상층 위치 | field | 법원경매 물건정보 | `층 정보: {val}` |

### Partial Grade (risk-only auto, nil = leave for user)

| Code | Question | Type | source_label | Data |
|------|----------|------|-------------|------|
| rights-005 | 사용 승인 정상 건물 | keyword | 물건명세서, 감정평가서 | `["무허가", "미등기", "사용승인 미", "허가 미취득"]` |
| rights-021 | 전세사기 우선매수권 | keyword | 특별매각조건, 비고, 물건명세서 | `["우선매수", "전세사기", "특별법"]` |
| inspect-001 | 감정평가서 특이사항 | keyword | 감정평가서 | `["불법증축", "무허가", "환경오염", "면적불일치", "균열", "누수", "침수"]` |
| market-006 | 단지형 건물 | field | 법원경매 물건정보 | `물건종류: {val}`, `건물명: {val}` |
| bidding-001 | 경매 진행 상태 | field | 법원경매 물건정보 | `진행상태: {val}` |

## UI Design

### Evidence Block (InspectionItemComponent)

Rendered below the Yes/No logic section, only when `evidence` is present.

**Visual style:**
- Left border: indigo (`#6366f1`) for safe, red (`#ef4444`) for risk
- Background: subtle tint matching border color
- Header: `📋 판정 근거 · {source_label}`

**Field comparison display:**
```
📋 판정 근거 · 법원경매 물건정보
물건종류: 아파트
```

**Keyword matching display (not found):**
```
📋 판정 근거 · 비고, 물건명세서, 현황조사서
매칭 키워드: "유치권"
결과: 해당 없음
```

**Keyword matching display (found):**
```
📋 판정 근거 · 비고, 물건명세서, 현황조사서
매칭 키워드: "유치권"
결과: 발견
```

### Component Changes

`InspectionItemComponent`:
- New helper method `evidence_present?` — checks `@result.evidence.present?`
- New helper method `evidence_border_classes` — indigo for safe, red for risk
- New partial or inline ERB block rendering the evidence data from JSON

## Testing

- Unit tests for each DETECTION_RULE verifying both `has_risk` and `evidence` structure
- Component test for InspectionItemComponent verifying evidence block renders correctly for field and keyword types
- Component test verifying evidence block is absent when evidence is nil (manual items)
- Integration test: run PropertyInspectionService and verify evidence persisted in DB
