# Convert Numeric-Input Checklist Questions to Yes/No Selection

**Date:** 2026-04-08
**Status:** Approved

## Problem

The `checklist_items_summary.json` contains 11 inspection items with numeric comparison logic (e.g., `">= 85"`, `"< 10"`). These items require users to input a number, but the current codebase only supports yes/no binary answers:

- `InspectionItemComponent#logic_present?` checks for `logic["yes"]` — numeric items are invisible
- `InspectionResult` stores `has_risk` as boolean — no numeric value storage
- Stimulus controller only handles yes/no radio toggle

Building a numeric input UI would require changes across component, controller, Stimulus, and service layers.

## Decision

Convert all 11 numeric-input questions to yes/no format by embedding the threshold value directly in the question text. This eliminates the need for a separate numeric input UI and unifies all items under the existing yes/no architecture.

**`answer_type` column is retained** for potential future use — no schema changes needed.

## Conversion Table

| # | ID | Tab | Current Question | Converted Question |
|---|-----|-----|-----|-----|
| 1 | `tax-006` | 건축물대장 | 주택의 전용면적은 몇 ㎡입니까? | 주택의 전용면적이 85㎡(약 25평) 미만입니까? |
| 2 | `market-002` | 온라인조회 | 일반 급매물 또는 KB시세 대비 현재 경매 최저가가 최소 몇 % 이상 저렴한가? | 일반 급매물 또는 KB시세 대비 현재 경매 최저가가 10% 이상 저렴합니까? |
| 3 | `market-004` | 온라인조회 | 최근 한 달 기준 실거래 건수는 평균 몇 건입니까? | 최근 한 달 기준 실거래 내역이 있습니까? |
| 4 | `market-006` | 온라인조회 | 검색하려는 아파트 단지의 총 세대수는 몇 세대입니까? | 단독(나홀로) 건물이 아닌 단지형 아파트(또는 오피스텔·빌라 등)입니까? |
| 5 | `market-008` | 온라인조회 | 금액대가 비슷한 주변 신축 아파트의 입주 시기까지 남은 기간(개월)은? | 금액대가 비슷한 주변 신축 아파트의 입주 시기가 3개월 이상 남아 있습니까? |
| 6 | `market-012` | 온라인조회 | 경매 사이트에 표시된 해당 물건의 조회수는 얼마입니까? | 경매 사이트에 표시된 해당 물건의 조회수가 500회 미만입니까? |
| 7 | `tax-004` | 온라인조회 | 해당 주택의 공시 가격은 얼마입니까? (단위: 만원) | 해당 주택의 공시가격이 9억 원 이하입니까? |
| 8 | `tax-005` | 온라인조회 | 인구 감소 지역 내 주택의 공시가격은 얼마입니까? (단위: 만원) | 인구 감소 지역(또는 지방 저가 주택)이면서 공시가격이 4억 원 이상입니까? |
| 9 | `rights-017` | 현장임장 | 말소기준권리 설정일과 세금 압류 송달 일자의 간격은 몇 년입니까? | 말소기준권리 설정일과 세금 압류 송달 일자의 간격이 1년 이상입니까? |
| 10 | `market-011` | 현장임장 | 예상 매도가에서 모든 비용을 뺀 순수익과 수익률(%)은 얼마입니까? | 예상 매도가에서 모든 비용을 뺀 순수익이 0원 초과(흑자)입니까? |
| 11 | `bidding-002` | 기타 | 동일 종목으로 사전에 직접 찾아본 비교 물건은 총 몇 개입니까? | 동일 종목으로 사전에 직접 비교 물건 탐색을 수행하였습니까? |

## Logic Changes

Most items map naturally: the "safe" threshold becomes `yes`, the "risky" threshold becomes `no`.

**Exception — `tax-005`:** The question is inverted ("4억 원 이상입니까?"), so yes = risk, no = safe:

```json
{
  "yes": "지방 저가 주택 요건을 초과하여 특례 적용이 불가합니다.",
  "no": "1세대 1주택 비과세 특례 유지, 종부세 합산 배제, 취득세 최대 50% 감면 혜택 적용이 가능합니다."
}
```

All other items: `yes` = safe answer, `no` = risky answer (consistent with existing convention).

## Description Updates

Some `description` fields reference numeric input context and should be updated to match the new question style:

| ID | Current Description (excerpt) | Updated Description |
|----|------|------|
| `market-004` | "실거래 건수로 현재의 거래 활성도를 구체적 숫자로 파악합니다." | "최근 실거래 유무로 현재의 거래 활성도를 파악합니다." |
| `market-006` | "세대수가 적은 단지는 거래가 드물어 환금성이 낮습니다. 대단지(500세대+)가 유리합니다." | "단독(나홀로) 건물은 거래가 드물어 환금성이 낮습니다. 단지형 건물이 유리합니다." |
| `market-011` | "최종 수익을 구체적 숫자와 퍼센트로 산출했는지 확인합니다. (통합: 순수익 금액 + 수익률 %)" | "최종 수익이 흑자인지 확인합니다. 예상 매도가에서 모든 비용(취득세, 중개수수료, 수리비 등)을 차감하여 판단합니다." |
| `bidding-002` | "비교 물건을 충분히 보지 않으면 적정 입찰가 판단이 불가능합니다. 최소 5~10개 이상 비교해야 합니다." | "비교 물건을 충분히 보지 않으면 적정 입찰가 판단이 불가능합니다. 동일 종목의 다른 물건을 탐색하여 비교 분석해야 합니다." |

Other items' descriptions remain valid as-is since they already explain the threshold context.

## Impact Analysis

### Files Modified

| File | Change | Effort |
|------|--------|:------:|
| `db/seeds/checklist_items_summary.json` | Update 11 items: `question`, `logic`, `description` | Low |

### Files NOT Modified (zero code changes)

| File | Reason |
|------|--------|
| `app/components/inspection_item_component.rb` | `logic_present?` checks `logic["yes"]` — works automatically |
| `app/components/inspection_item_component.html.erb` | Renders `logic["yes"]`/`logic["no"]` — works automatically |
| `app/javascript/controllers/inspection_item_controller.js` | Yes/no radio toggle — works automatically |
| `app/controllers/inspections/tabs_controller.rb` | `has_risk` boolean — works automatically |
| `app/services/inspection_runner.rb` | These 11 items have no auto-detection rules |
| `app/services/inspection_rating_service.rb` | Rating based on `has_risk` — works automatically |
| `app/models/inspection_item.rb` | `answer_type` retained, no schema change |
| `db/seeds.rb` | Seed loader unchanged |

### Post-Change Verification

After updating the JSON and running `bin/rails db:seed`:
1. All 11 items should display yes/no logic text in the UI (previously hidden)
2. Existing `InspectionResult` records for these items remain valid (`has_risk` boolean)
3. Tab ratings and overall grades are unaffected

## Priority Review

All 11 items retain their current priority (8 items: 상, 3 items: 중). The question rewording preserves the original risk assessment intent.
