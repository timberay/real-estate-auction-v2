# Transfer Tax Matrix — Execution Plan (T1.2)

**작성일**: 2026-05-14
**기술 설계**: `docs/superpowers/specs/2026-05-14-transfer-tax-matrix-design.md`
**관련**: 마스터 TODO T1.2

> 본 plan 은 설계 문서의 §10 커밋 시퀀스를 실행 가능 형태로 풀어낸 체크리스트다. TDD: Red → Green → Refactor. Tidy First: 구조 변경과 동작 변경은 다른 커밋.

---

## Task 1 — Migration: `transfer_tax_rates` 테이블 (구조)

**Red**: `test/models/transfer_tax_rate_test.rb` 작성
- valid record 생성
- `household_tier` inclusion 검증 (잘못된 값 → invalid)
- `holding_period` inclusion 검증
- `total_rate` 범위 검증 (0~1)
- `property_type` 필수 (`belongs_to :property_type`)

**Green**:
- `bin/rails g migration CreateTransferTaxRates`
- 컬럼: `property_type_id (FK)`, `household_tier:string`, `holding_period:string`, `regulated_region:boolean (nullable)`, `total_rate:decimal{5,4}`, timestamps
- 인덱스: `(property_type_id, household_tier, holding_period, regulated_region)` lookup
- `app/models/transfer_tax_rate.rb` 신규
  - `HOUSEHOLD_TIERS = AcquisitionTaxRate::HOUSEHOLD_TIERS` 재사용
  - `HOLDING_PERIODS = %w[under_1y btw_1_2y over_2y].freeze`
  - validations
- `bin/rails db:migrate`
- 모델 테스트 통과 확인

**Commit**: `feat(T1.2): create transfer_tax_rates table`

---

## Task 2 — Seed: `db/seeds/transfer_tax_matrix.json` (구조)

**Green** (Red 없음 — 데이터):
- `db/seeds/transfer_tax_matrix.json` 작성. 설계 §5 의 14 행 매트릭스, 주거용 property_type 3종 (아파트/단독주택/빌라) 각각에 동일 매트릭스
- `db/seeds.rb` 에 idempotent upsert 블록 추가 — C-4 의 `acquisition_tax_rates_seed` 블록 패턴 그대로
- `bin/rails db:seed` 로 채워졌는지 확인 (`TransferTaxRate.count` ≥ 42)

**Commit**: `feat(T1.2): seed transfer_tax_rates with 2026 effective rates`

---

## Task 3 — `TransferTaxCalculator.call` (동작)

**Red**: `test/services/transfer_tax_calculator_test.rb`
- 12 매트릭스 케이스 (4 tier × 3 holding × regulated 분기) 의 expected rate
- 와일드카드 NULL 우선순위 ("multi_home_2 + over_2y + true 가 NULL 보다 우선")
- `RateNotFoundError` 발생 (시드 없는 property_type_id)
- `tax_manwon` = `(rate * taxable_gain).round`, 음수 gain 입력 시 0

**Green**:
- `app/services/transfer_tax_calculator.rb` 작성. 설계 §6 시그니처 그대로
- `Result = Data.define(:rate, :tax_manwon, :rate_source)`
- `lookup_row` 의 ORDER BY 로 NULL 우선순위 처리 (C-4 패턴)
- `Rails.logger.info` 한 줄 (관측성 §11)
- 테스트 통과

**Commit**: `feat(T1.2): TransferTaxCalculator with bracket-aware lookup`

---

## Task 4 — `TransferTaxCalculator.matrix_for` (동작)

**Red**: `test/services/transfer_tax_calculator_test.rb` 에 추가
- 출력 형태: `{"homeless" => {"under_1y" => 0.7, "btw_1_2y" => 0.6, "over_2y" => 0.06}, ...}`
- `regulated_region: true` 와 `false` 입력 시 multi_home_2/over_2y 값이 다름
- 시드 비어 있을 때 빈 해시 반환

**Green**:
- `TransferTaxCalculator.matrix_for(property_type_id:, regulated_region:)` 클래스 메서드 추가
- 단일 SQL 로 모든 (tier × holding) 조합 가져와 nested hash 직렬화

**Commit**: `feat(T1.2): TransferTaxCalculator.matrix_for for client-side lookup`

---

## Task 5 — `ProfitCalculatorComponent#transfer_tax_matrix` + 뷰 주입 (동작)

**Red**: `test/components/profit_calculator_component_test.rb` 에 추가
- 컴포넌트 렌더 결과에 `data-profit-calculator-cgt-matrix-value` 어트리뷰트 존재
- 어트리뷰트 JSON 파싱 시 4 tier × 3 holding 키 모두 존재
- 다주택 + 조정 BudgetSetting → 비조정과 매트릭스 값이 다름

**Green**:
- `app/components/profit_calculator_component.rb` 에 `transfer_tax_matrix` 헬퍼 추가 (설계 §7)
- `app/components/profit_calculator_component.html.erb` 의 `data-controller="profit-calculator"` 블록에 `data-profit-calculator-cgt-matrix-value="<%= transfer_tax_matrix.to_json %>"` 추가

**Commit**: `feat(T1.2): inject transfer tax matrix into profit calculator component`

---

## Task 6 — `profit_calculator_controller.js` 매트릭스 사용 (동작)

**Red**: 기존 `test/system/profit_calculator_test.rb` 에 회귀 케이스 1개 추가하여 현재 하드코딩 동작과 새 매트릭스 동작 차이를 드러내기 (예: 다주택 비조정 over_2y → 0.40 대신 0.24 노출 검증). 처음엔 실패해야 함.

**Green**:
- `static CGT_RATES = {...}` 제거
- `static values` 에 `cgtMatrix: Object` 추가
- 라디오 값 `"1to2y"` → `"btw_1_2y"` 로 통일 (뷰 + JS 둘 다)
- `selectedHoldingPeriod()` 키 변경 반영
- `calculate()` 의 CGT 룩업: `matrix[ownership]?.[holdingPeriod] ?? this.constructor.CGT_FALLBACK_RATE`
- `static CGT_FALLBACK_RATE = 0.20` 추가

**Commit (구조)**: `refactor(T1.2): unify holding period key (1to2y → btw_1_2y)`
**Commit (동작)**: `feat(T1.2): use server-driven transfer tax matrix in profit calculator`

---

## Task 7 — 시스템 테스트 회귀 케이스 (검증)

추가:
- 다주택 + 조정 + 2년+ 시 표시 양도세율 ≠ 비조정 케이스
- 1주택 2년+ 시 양도세 0
- under_1y 시 70% 일관 (모든 tier)

**Commit**: `test(T1.2): regression cases for transfer tax matrix`

---

## Task 8 — 기능 검사 (실 브라우저 + fix loop)

`bin/dev` (또는 동등 커맨드) 로 Rails dev 서버 띄우고, 시드 매물 1개 (BudgetSetting 완료 사용자) 의 `/properties/:id` 페이지 양도세 행을 직접 조작하며 검증:
- ownership 라디오 4종 변경 시 양도세 행이 즉시 갱신됨
- 보유기간 라디오 3종 변경 시 갱신됨
- BudgetSetting region 을 조정대상지역으로 바꾼 뒤 다시 진입 → multi_home over_2y 셀의 율 다름
- bid 슬라이더 조작 시 양도세 정확히 재계산

**오동작 발견 시**: 원인 파악 → 코드 수정 → 시스템 테스트 추가 → 다시 검사 (루프).

**커밋 정책**: 각 fix 마다 별도 commit (이유: 회귀 검사 가능).

---

## Task 9 — 단일 PR 생성

전체 테스트 스위트 통과 확인 후 `/push2gh` 스킬 호출. PR 제목 후보:

> `feat(T1.2): server-driven transfer tax matrix in profit calculator`

설명에 마스터 TODO T1.2 링크 + 후속 follow-up (F-A~F-D) 명시.

---

## 자체 점검 (실행 전 체크)

- [x] 설계 §10 의 7 단계가 Task 1~7 에 1:1 매핑
- [x] 모든 Task 가 TDD Red → Green 분리
- [x] 구조/동작 커밋 분리 (Task 6 의 라벨 통일은 별도 commit)
- [x] 마이그레이션 안전성: 새 테이블 + 시드 누락 fallback (설계 §9)
- [x] 후속 follow-up 명시 (설계 §12) — 이 PR 범위 외

---

**End of plan.**
