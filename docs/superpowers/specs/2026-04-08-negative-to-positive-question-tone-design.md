# Convert Negative Checklist Questions to Positive Tone

**Date:** 2026-04-08
**Status:** Approved

## Problem

The `checklist_items_summary.json` contains 18 questions phrased negatively ("~없습니까?"). Negative phrasing can confuse users because answering "Yes" to "Is there NO problem?" requires double-negative reasoning. Positive phrasing ("~있습니까?") is more intuitive.

## Decision

Convert all 18 negative questions to positive tone using two strategies:
1. **Simple swap** (11 items): Replace "없습니까?" with "있습니까?" — works when the question has a single condition
2. **Natural rewrite** (7 items): Rephrase compound conditions into a single positive question focused on the core risk

All conversions require **yes/no logic inversion**: the current `yes` response becomes the new `no`, and vice versa. After conversion, `yes` = risk detected, `no` = safe.

## Conversion Table

### Group 1: Simple Swap (11 items)

| # | ID | Tab | Current Question | Converted Question |
|---|-----|-----|-----|-----|
| 1 | `rights-011` | 매각물건명세서 | 매각물건명세서 비고란에 유치권 또는 법정지상권 기재가 없습니까? | 매각물건명세서 비고란에 유치권 또는 법정지상권 기재가 있습니까? |
| 2 | `rights-020` | 매각물건명세서 | 현황조사서에 유치권 신고 표시가 없습니까? | 현황조사서에 유치권 신고 표시가 있습니까? |
| 3 | `rights-001` | 등기부등본 | 등기부에 말소기준권리보다 앞선 선순위 가처분이 없습니까? | 등기부에 말소기준권리보다 앞선 선순위 가처분이 있습니까? |
| 4 | `rights-004` | 등기부등본 | 선순위 가등기가 없습니까? | 선순위 가등기가 있습니까? |
| 5 | `rights-007` | 등기부등본 | 등기부등본에 예고등기가 없습니까? | 등기부등본에 예고등기가 있습니까? |
| 6 | `rights-008` | 등기부등본 | 말소기준권리보다 앞선 선순위 세금 압류가 없습니까? | 말소기준권리보다 앞선 선순위 세금 압류가 있습니까? |
| 7 | `rights-022` | 등기부등본 | 경매정보지에 질권 표시가 없습니까? | 경매정보지에 질권 표시가 있습니까? |
| 8 | `rights-021` | 온라인조회 | 전세사기 피해자의 우선매수권 행사 가능성이 없습니까? | 전세사기 피해자의 우선매수권 행사 가능성이 있습니까? |
| 9 | `eviction-001` | 현장임장 | 현장 확인 결과 화재·누수·크랙 등 치명적 하자가 없습니까? | 현장 확인 결과 화재·누수·크랙 등 치명적 하자가 있습니까? |
| 10 | `exit-001` | 현장임장 | 집 내부에 악취나 환기 문제가 없습니까? | 집 내부에 악취나 환기 문제가 있습니까? |
| 11 | `manual-001` | 기타 | 토지에 분묘기지권이 없습니까? | 토지에 분묘기지권이 있습니까? |

### Group 2: Natural Rewrite (7 items)

| # | ID | Tab | Current Question | Converted Question | Rewrite Rationale |
|---|-----|-----|-----|-----|-----|
| 12 | `rights-003` | 매각물건명세서 | 채무자/소유자만 거주 중이며, 전입신고된 제3자 임차인이 없습니까? | 전입신고된 제3자 임차인이 거주하고 있습니까? | "채무자/소유자만 거주" is redundant when asking about third-party tenants directly |
| 13 | `rights-010` | 매각물건명세서 | 대항력 있는 임차인이 없거나, 보증금이 전액 배당되어 미배당 금액이 없습니까? | 대항력 있는 임차인의 미배당 보증금이 있습니까? | Compound OR simplified to core risk: unpaid deposit |
| 14 | `property-002` | 매각물건명세서 | 호실 간 벽체 구분이 명확하고 불법 구조변경이 없습니까? | 호실 간 벽체 구분이 불명확하거나 불법 구조변경이 있습니까? | AND(positive, negative) → OR(negative, positive) via De Morgan's |
| 15 | `rights-016` | 매각물건명세서 | 임차인이 없거나, 전입신고일이 말소기준일 이후여서 대항력이 없습니까? | 전입신고일이 말소기준일 이전인 대항력 있는 임차인이 있습니까? | OR of two safe conditions → single risk condition |
| 16 | `rights-012` | 등기부등본 | 선순위 임차권 등기가 없거나, 등기 이후 새로 전입한 미상 임차인이 없습니까? | 선순위 임차권 등기 또는 등기 이후 새로 전입한 미상 임차인이 있습니까? | OR structure preserved, negation removed |
| 17 | `inspect-001` | 온라인조회 | 감정평가서 특이사항에 중대한 문제 기재가 없습니까? | 감정평가서 특이사항에 중대한 문제가 기재되어 있습니까? | Word order adjusted for natural Korean |
| 18 | `inspect-013` | 현장임장 | 외부에서 섀시(창틀) 교체 여부 및 아랫집 누수 피해 여부를 확인하여 누수가 없습니까? | 외부에서 섀시(창틀) 및 아랫집 확인 결과 누수 흔적이 있습니까? | Verbose phrasing condensed to core question |

## Logic Changes

All 18 items follow the same pattern — swap `yes` and `no` logic values:

```
Before: yes = "safe message",  no = "risk message"
After:  yes = "risk message",  no = "safe message"
```

**Example — `rights-011`:**

Before:
```json
{
  "yes": "치명적인 특수 권리가 없습니다.",
  "no": "인수해야 할 중대 권리가 명시되어 있습니다."
}
```

After:
```json
{
  "yes": "인수해야 할 중대 권리가 명시되어 있습니다.",
  "no": "치명적인 특수 권리가 없습니다."
}
```

No logic text changes are needed — only the yes/no keys are swapped.

## Impact on Existing Code

**No code changes required.** The application reads `logic.yes` and `logic.no` from the JSON and displays them based on the user's answer. Swapping the values in the seed data is sufficient.

The existing `rights-002` question already uses this positive pattern ("기재가 없는 깨끗한 물건입니까?" with yes=safe), confirming the codebase handles both conventions.

## Scope

- **In scope:** 18 questions in `checklist_items_summary.json` — question text and logic swap
- **Out of scope:** The 13 existing positive questions (already in correct tone), description fields, data_source fields, priority fields
