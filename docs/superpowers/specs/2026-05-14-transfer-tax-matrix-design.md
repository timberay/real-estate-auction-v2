# Transfer Tax Matrix — Technical Design (T1.2)

**작성일**: 2026-05-14
**관련**: 마스터 TODO T1.2 / W1-3 / C23 / E-25
**선행**: C-4 취득세 매트릭스 (2026-05-12-c4-acquisition-tax-redesign-design.md, #131~#138 출하 완료)

---

## 1. 목표

`profit_calculator_controller.js:47-52` 의 12셀 하드코딩 `CGT_RATES` (양도세 effective rate 매트릭스) 를 **DB 시드 + 서버 매트릭스 주입** 으로 교체한다. 베테랑이 보고 "이 도구 못 믿어" 하지 않게 만드는 것이 목적.

C-4 취득세 매트릭스 패턴을 그대로 미러: 모델 + 시드 + Calculator + 컴포넌트가 매트릭스를 JSON 으로 Stimulus 에 주입.

## 2. 비목표 (Non-goals)

명시적으로 **이번 PR 에서 다루지 않는 것**:
- 양도세 admin UI (취득세의 F-D 처럼 후속 분리)
- 1세대1주택 9억 초과분 누진 정밀 계산 (취득세의 F-C 처럼 후속 분리)
- 1세대1주택 12억 비과세 거주요건 분기
- 양도소득기본공제 (250만원), 장기보유특별공제
- property_type 별 차등 (오피스텔/상가 등 — Theme 3 의 T3.1 에서 확장)

## 3. 현재 상태 진단

`app/javascript/controllers/profit_calculator_controller.js:47-52`:

```js
static CGT_RATES = {
  homeless:         { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.00 },
  single_home:      { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.00 },
  multi_home_2:     { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.40 },
  multi_home_3plus: { under_1y: 0.70, "1to2y": 0.60, over_2y: 0.40 }
}
```

**문제점**:
1. `regulated_region` 차원이 없음 → 다주택자 비조정지역 한시 유예(2022.5.10~) 미반영
2. JS 하드코딩 → 세법 개정 시 코드 배포 필요
3. 회귀 가드 0건 (Stimulus 테스트 없음)

## 4. 데이터 모델

### `transfer_tax_rates` 테이블

`acquisition_tax_rates` 구조 미러. 단 가액 구간 (`price_bucket_*`) 과 `area_over_85` 는 **제거** — 양도세 매트릭스에 무관한 차원.

| 컬럼 | 타입 | nullable | 의미 |
|------|------|---------|------|
| id | bigint | NO | PK |
| property_type_id | bigint | NO | FK → property_types |
| household_tier | string | NO | homeless / single_home / multi_home_2 / multi_home_3plus |
| holding_period | string | NO | under_1y / btw_1_2y / over_2y |
| regulated_region | boolean | YES | NULL = wildcard (양 케이스 모두 적용) |
| total_rate | decimal(5,4) | NO | 0.0000 ~ 1.0000 (effective 양도세율) |
| created_at, updated_at | datetime | NO | |

**인덱스**: `(property_type_id, household_tier, holding_period, regulated_region)` lookup 인덱스.

**룩업 우선순위**: 구체 일치(regulated_region 명시) > NULL 와일드카드. C-4 의 `Arel.sql("(regulated_region IS NULL)")` ORDER BY 패턴 재사용.

### `budget_settings` 변경 없음

기존 `household_tier` 컬럼과 `regulated_region?` 헬퍼 (region → regulated 매핑) 그대로 재사용. 신규 마이그레이션 없음.

## 5. 시드 데이터

`db/seeds/transfer_tax_matrix.json` — 한 줄 항목당 하나의 매트릭스 셀. 2026-05 기준 한국 양도소득세법 + 한시 유예 (다주택 비조정지역 중과 배제, 2022.5.10~) 반영.

| tier | holding_period | regulated_region | rate | 근거 |
|------|----------------|------------------|------|------|
| homeless | under_1y | NULL | 0.70 | 단기보유 70% (보유기간 우선 적용) |
| homeless | btw_1_2y | NULL | 0.60 | 단기보유 60% |
| homeless | over_2y | NULL | 0.06 | 일반 누진 6단계 첫 구간 효과치 (보수적) |
| single_home | under_1y | NULL | 0.70 | |
| single_home | btw_1_2y | NULL | 0.60 | |
| single_home | over_2y | NULL | 0.00 | 1세대1주택 비과세 가정 (12억 이하 + 2년 보유) |
| multi_home_2 | under_1y | NULL | 0.70 | |
| multi_home_2 | btw_1_2y | NULL | 0.60 | |
| multi_home_2 | over_2y | true | 0.44 | 일반 24% + 20%p 중과 (조정대상) |
| multi_home_2 | over_2y | false | 0.24 | 한시 유예 적용 (비조정) |
| multi_home_3plus | under_1y | NULL | 0.70 | |
| multi_home_3plus | btw_1_2y | NULL | 0.60 | |
| multi_home_3plus | over_2y | true | 0.54 | 일반 24% + 30%p 중과 (조정대상) |
| multi_home_3plus | over_2y | false | 0.24 | 한시 유예 적용 (비조정) |

총 14 행 (homeless·single_home·multi_2·multi_3 × 3 holding × 1 또는 2 regulated 분기). property_type_id 는 시드 시점 주거용 3종 (아파트/단독주택/빌라) 각각에 동일 매트릭스 부여. 향후 오피스텔/상가/토지는 T3.1 에서 별도 매트릭스.

`db/seeds.rb` 에 idempotent upsert 추가 (C-4 패턴 그대로).

## 6. 서비스 계층

### `TransferTaxCalculator`

`AcquisitionTaxCalculator` 패턴 미러:

```ruby
class TransferTaxCalculator
  class RateNotFoundError < StandardError; end
  Result = Data.define(:rate, :tax_manwon, :rate_source)

  def self.call(**kwargs) = new(**kwargs).call

  # JS 매트릭스 직렬화용
  def self.matrix_for(property_type_id:, regulated_region:)
    # {"homeless" => {"under_1y" => 0.70, "btw_1_2y" => 0.60, "over_2y" => 0.06}, ...}
  end

  def initialize(taxable_gain_manwon:, property_type_id:, household_tier:,
                 holding_period:, regulated_region:)
    ...
  end

  def call
    row = lookup_row
    raise RateNotFoundError, lookup_signature if row.nil?
    rate = row.total_rate.to_d
    Result.new(
      rate: rate,
      tax_manwon: (rate * @taxable_gain_manwon).clamp(0, Float::INFINITY).round,
      rate_source: row
    )
  end
end
```

`matrix_for` 는 Stimulus 가 슬라이더/토글 인터랙션 중에 서버 호출 없이 즉시 룩업할 수 있도록 매트릭스 전체를 한 번에 직렬화. `regulated_region` 은 BudgetSetting 시점에 결정되므로 컴포넌트 init 시 한 번만 매트릭스 생성하면 됨.

룩업 로직: `holding_period` 일치 + `household_tier` 일치 + `regulated_region` 일치 우선 (NULL 와일드카드 fallback).

## 7. 컴포넌트 / Stimulus 통합

### `ProfitCalculatorComponent` 변경

`acquisition_tax_brackets` 와 동일한 패턴으로 `transfer_tax_matrix` 헬퍼 추가:

```ruby
def transfer_tax_matrix
  return {} unless @budget&.property_type_id
  TransferTaxCalculator.matrix_for(
    property_type_id: @budget.property_type_id,
    regulated_region: @budget.regulated_region?
  )
end
```

뷰 (`profit_calculator_component.html.erb`) 에서 `data-profit-calculator-cgt-matrix-value="<%= transfer_tax_matrix.to_json %>"` 로 JS 에 주입.

### `profit_calculator_controller.js` 변경

- `static CGT_RATES = {...}` **제거**
- `static values` 에 `cgtMatrix: Object` 추가
- `selectedHoldingPeriod()` 의 라벨 키를 모델과 일치시킴: `under_1y` / `btw_1_2y` / `over_2y`
  - 현재 라디오 버튼이 사용하는 값 (`"1to2y"`) 도 매트릭스 키와 통일 — 뷰 템플릿에서도 동일 변경
- `calculate()` 의 CGT 룩업:
  ```js
  const matrix = this.cgtMatrixValue || {}
  const cgtRate = matrix[ownership]?.[holdingPeriod] ?? this.constructor.CGT_FALLBACK_RATE
  ```
- `static CGT_FALLBACK_RATE = 0.20` (server 가 매트릭스를 비웠을 경우 보수적 fallback, 기존 `|| 0.20` 와 동일 의미)

## 8. 테스트 전략

### Red 우선

1. `test/models/transfer_tax_rate_test.rb` — validations (household_tier inclusion, holding_period inclusion, total_rate 범위)
2. `test/services/transfer_tax_calculator_test.rb` —
   - 12 매트릭스 케이스 (4 tier × 3 holding × regulated 분기) 의 expected rate
   - 와일드카드 NULL 우선순위 ("multi_home_2 + over_2y + true 가 NULL 보다 우선")
   - `RateNotFoundError` 발생 (시드 없는 property_type_id)
   - `matrix_for` 출력 형태 (`{tier => {holding_period => rate}}`)
3. `test/components/profit_calculator_component_test.rb` — `cgtMatrixValue` 가 뷰에 주입되는지 + 매트릭스 값 정합성

### Green 단계

각 Red 통과시키는 최소 코드 → commit (Tidy First: 구조 변경과 동작 변경 분리).

### 시스템 테스트

기존 `test/system/profit_calculator_test.rb` 에 케이스 2~3개 추가:
- 다주택 + 조정 + 2년+ 시 표시되는 양도세율 ≠ 비조정 케이스
- 1주택 2년+ 시 양도세 0
- under_1y 시 70% 일관 (모든 tier)

## 9. 마이그레이션 안전성

- `transfer_tax_rates` 테이블 생성 → 기존 코드 영향 없음 (새 모델)
- `profit_calculator_controller.js` 변경 → 시드가 비어 있어도 fallback 0.20 으로 동작
- 시드 누락 환경 (테스트 fixtures, 기존 staging) 회복 경로:
  - `db/seeds.rb` 가 idempotent upsert → `bin/rails db:seed` 한 번 실행으로 채워짐
  - C-4 `seed-check` warning 메커니즘에 `transfer_tax_rates` 추가 (별도 Task — 선택)

## 10. 커밋 시퀀스 (Tidy First)

| # | 변경 | 종류 |
|---|------|------|
| 1 | `transfer_tax_rates` 마이그레이션 + 빈 모델 + 모델 테스트 | 구조 |
| 2 | seed JSON + `db/seeds.rb` wiring | 구조 |
| 3 | `TransferTaxCalculator` (Red → Green) | 동작 |
| 4 | `TransferTaxCalculator.matrix_for` (Red → Green) | 동작 |
| 5 | `ProfitCalculatorComponent#transfer_tax_matrix` + 뷰 주입 | 동작 |
| 6 | `profit_calculator_controller.js` 매트릭스 사용 + 라벨 키 통일 | 동작 |
| 7 | 시스템 테스트 회귀 케이스 추가 | 검증 |

PR 은 Theme 1·T1.2 단위 (즉, 위 모든 커밋을 한 PR 로 묶음).

## 11. 관측성

- `TransferTaxCalculator#call` 마지막에 `Rails.logger.info` 한 줄 (rate / source row id) — 운영 데이터 가시성
- raise 시 `lookup_signature` 포함 → grep 가능

## 12. 후속 (별도 PR, 명시적 비목표)

| ID | 항목 |
|----|------|
| T1.2-F-A | 양도세 admin UI (취득세의 F-D 패턴) |
| T1.2-F-B | 1세대1주택 9억 초과분 누진 정밀 모드 (취득세의 F-C 패턴) |
| T1.2-F-C | 양도세율 변경 audit log (취득세의 F-D-3 패턴) |
| T1.2-F-D | property_type 별 매트릭스 (오피스텔/상가/토지) — Theme 3 T3.1 에서 흡수 |

—
**End of design.**
