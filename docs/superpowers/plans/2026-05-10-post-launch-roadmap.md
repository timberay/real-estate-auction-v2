# 출시 후 구현 로드맵 + 실행 프롬프트 모음

**작성일**: 2026-05-10 (출시 D-9)
**범위**: 2026-05-19 정식 출시 이후 처리할 모든 코드 변경 항목.
**근거**:
- `docs/audits/2026-05-09-ux-audit-expert.md` (전문가 페르소나 44건)
- `docs/audits/2026-05-09-ux-audit-beginner.md` (초보자 페르소나 45건)
- `docs/superpowers/plans/2026-05-09-ux-audit-fixes-plan.md` (Phase A 13 / Phase B 22 / Phase C 36)
- `docs/superpowers/plans/2026-05-10-ux-audit-remaining-backlog.md` (세션 follow-ups 24건)

## 사용 방법

각 항목 하단에 **실행 프롬프트** 가 붙어 있다. 새 세션에서 Claude Code 에 그대로 붙여넣으면 된다.

표준 진행 방식:
1. 새 세션 시작 → 해당 프롬프트 paste
2. Claude 가 4-phase pipeline (`/office-hours` → `/plan-eng-review` → `/superpowers:brainstorming` → `/superpowers:writing-plans`) 거치거나, 작은 항목은 바로 implementer subagent 호출
3. 구현 완료 시 `/push2gh` → automerge

각 항목의 effort 추정:
- **XS**: <2h, 단일 파일 변경
- **S**: 2~4h, 1~2 파일
- **M**: 4~8h, 다중 파일 + 테스트
- **L**: 8~16h, 신규 컨트롤러/서비스/마이그레이션 포함

## 우선순위 분류

### ⚫ Wave 0 — Deploy/외부 게이트 (출시 ~ D+7)

운영 배포 완료 + 외부 결정(도메인 확정, 정책 검토)에 막혀 있는 항목. 능동적 개발보다는 외부 이벤트 감시 + 작은 후속 작업.

- **W0-1 CSP report_only → enforce** — 운영 1주 후 `csp.violation` 0건 확인 후 플립 (OAuth Hardening Phase 5)
- **W0-2 OAuth 콘솔 redirect URI 등록** — Google/Naver/Kakao, 운영 도메인 확정 후
- **W0-3 SNS 로그인 self-review (4건)** — Multi-tab session sync, Account settings, rack-attack 확장, `/terms` `/privacy` 본문
- **W0-4 OAuth Symbol provider 회귀 테스트** — test/infra debt
- **W0-5 Branch protection 정책 재평가** — GitHub Pro 구독 / public 전환 / status check polling 중 택일

### 🔴 Wave 1 — 출시 직후 1~2주 (D+1 ~ D+14)

신뢰성/베테랑 retention 직결. 출시 후 사용자 onboarding 흐름이 안정되는 첫 2주 안에 처리.

- **C23 양도세 매트릭스 정밀화** — 베테랑이 1초 만에 신뢰 잃는 항목
- **C25 소액임차인 최우선변제 자동 계산** — 권리분석 정확도 핵심
- **Follow-up #13 AI 재분석 silent overwrite 보호** — 사용자 편집 손실 방지
- **Follow-up #4 lograge 도입** — 운영 신호 가시화 (출시 직후 가장 먼저)

### 🟡 Wave 2 — 출시 후 3~6주 (D+14 ~ D+42)

Phase C-2 (전문가 retention) 핵심.

- **C22 회차별 저감률 + 낙찰가 통계 시드**
- **C26 DSR 한도 계산**
- **C24 취득세 매트릭스** (C23 후속)
- **C27 property_type 분기** (오피스텔/상가/토지)
- **C28 공유지분 매물**
- **C29 인도명령 6개월 D-day**
- **C30 Notification 채널** (이메일 + in-app)

### 🟢 Wave 3 — 출시 후 6~12주 (D+42 ~ D+84)

Phase C-1 폴리시 (모바일 + 인지 + 빈 상태) — 작은 단위 빠르게 처리.

### 🔵 Wave 4 — Phase C-3 + 잔여

a11y 점검 패스 + 보안 jaguar (C31 endpoint 노출 축소).

---

# Wave 0 — Deploy/외부 게이트 (출시 ~ D+7)

## W0-1. CSP report_only → enforce (OAuth Hardening Phase 5)

**근거**: `docs/superpowers/plans/2026-04-22-oauth-hardening.md` Phase 5. Phase 4 까지 출하 완료.

**Gate**: 운영 ≥ 1주 + `csp.violation` 로그 0건 (chrome-extension / moz-extension / safari-web-extension scheme 제외) 확인.

**산출물**:
- `config/initializers/content_security_policy.rb:25` — `config.content_security_policy_report_only = false`
- report-mode 가정에 의존하는 테스트 정리

**실행 프롬프트**:
```
일주일 이상 csp.violation 로그를 확인했고 first-party 트래픽에서 0건이면 OAuth Hardening Phase 5 플립을 진행해줘.

작업:
1. config/initializers/content_security_policy.rb:25 의 report_only = true → false
2. 관련 테스트의 report-mode 가정 제거
3. log/production.log 에서 csp.violation 1주치 grep 결과를 PR 설명에 첨부

원본 plan: docs/superpowers/plans/2026-04-22-oauth-hardening.md Phase 5

TDD + Tidy First. push2gh + automerge. PR title: feat(security): enforce CSP after 1-week clean observation window
```

---

## W0-2. OAuth 콘솔 redirect URI 등록 (운영 도메인 확정 후)

코드 변경 없음, 외부 작업.

- Google Cloud Console → OAuth 2.0 클라이언트 → Authorized redirect URIs 에 운영 도메인 callback 추가
- Naver Developers → 애플리케이션 정보 → Callback URL 갱신
- Kakao Developers → 카카오 로그인 → Redirect URI 갱신

각 콘솔 갱신 후 staging/prod 양쪽에서 actual login round-trip 1회씩 검증.

---

## W0-3. SNS 로그인 self-review (4건)

`docs/superpowers/plans/2026-04-22-sns-login-plan.md` 출하 후 후속 — 노트북 메모 carry-over.

- **Multi-tab session sync (Turbo Cable)** — 한 탭에서 로그아웃 시 다른 탭도 즉시 반영
- **Account settings 페이지** — provider 연결/해제, 사용자 데이터 내보내기 (GDPR/개인정보보호법 대비)
- **rack-attack 확장** — progressive backoff, denylist (재시도 폭주 차단)
- **`/terms` `/privacy` 본문 작성** — 출시 전 법적 요구 사항 가능성, 본문 미작성 시 회원가입 단계 차단 가능

각 항목 별도 PR. **`/terms` `/privacy` 는 출시 차단 가능성** 있으므로 우선순위 최상.

---

## W0-4. OAuth Symbol provider 회귀 테스트

**근거**: 노트북 메모, test/infra debt.

**작업**:
- `test/controllers/auth/omniauth_callbacks_controller_test.rb` 에 provider 가 `Symbol` (`:google`) vs `String` (`"google"`) 분기 케이스 추가
- 원인 시나리오 확정: git log + PR 이력에서 Symbol/String 변환 회귀가 있었는지 먼저 확인 후 정확한 가드 작성

---

## W0-5. Branch protection 정책 재평가

**현재 상태**: private repo + GitHub Pro 미구독 → main branch protection rule 설정 불가.

**옵션**:
- (a) GitHub Pro 구독 ($4/월/user) — 가장 단순
- (b) Public 전환 — 코드 노출 허용 여부 검토 필요
- (c) Status check polling — GitHub Actions 기반 자체 가드 스크립트

출시 후 운영 데이터 + 팀 구성 확정 후 결정. 코드 작업 없음, 정책 결정.

---

# Wave 1 — 출시 직후 1~2주

## W1-1. lograge 구조화 로깅 (출시 후 즉시)

**근거**: launch_schedule 메모리 결정사항. Sentry 대체로 lograge 채택. 운영 신호 가시화의 첫 단추.

**산출물**:
- Gemfile: `gem "lograge"`
- `config/initializers/lograge.rb` — `Lograge.enabled = true`, JSON formatter, custom payload (request_id, user_id, controller, action, status, duration, db, view)
- `config/environments/production.rb` — request log silencing
- 테스트: 한 요청 → JSON 한 줄 출력 확인

**실행 프롬프트**:
```
lograge gem 도입해서 production 로그를 한 요청당 한 줄 JSON 으로 압축해줘. 출시 후 운영 신호 가시화가 목적.

요구사항:
- Gemfile 에 lograge + lograge-sql (옵션) 추가
- config/initializers/lograge.rb 작성: enabled, base_controller_class = ["ActionController::Base", "ActionController::API"], formatter = Lograge::Formatters::Json.new
- custom_payload 에 request_id, user_id (current_user&.id), guest 여부, params (sensitive 제외) 포함
- production.rb 에서 Rails 기본 verbose 로깅 끄기 (config.lograge.keep_original_rails_log = false)
- ActionController::Live (예: Turbo Streams) 호환 확인
- test/integration/logging_test.rb: 단일 요청 → 단일 JSON 라인, request_id 포함

TDD + Tidy First. push2gh 로 PR 생성, automerge 적용. PR title: feat(ops): structured request logs via lograge
```

---

## W1-2. AI 재분석 silent overwrite 방지 (Follow-up #13)

**근거**: B27 PR #123 follow-up. `RightsAnalysisReport#report_data` 가 통째로 교체되므로 `tenants[*]["user_edited"]` 플래그가 무시됨.

**산출물**:
- 옵션 (a): 재분석 진입 전 confirm UI ("사용자 편집 임차인 N명이 있습니다. 재분석하면 초기화됩니다. 계속하시겠습니까?")
- 옵션 (b): merge 로직 (user_edited 행은 보존, 나머지만 교체)
- 옵션 (c): 재분석 직후 diff 화면

**실행 프롬프트**:
```
B27 follow-up #13: AI 재분석이 사용자 편집 임차인을 silent overwrite 하는 문제 해결.

배경: 임차인 행을 사용자가 inline edit 하면 tenants[*]["user_edited"] = true 가 stamp 되고 "사용자 수정" 배지 노출. 그런데 /analyses/new 로 AI 재분석 실행 시 RightsAnalysisReport.report_data 가 통째로 교체되므로 user_edited 행 모두 손실됨.

옵션 분석을 먼저 office-hours 로 진행해줘. 후보:
(a) 재분석 진입 전 confirm modal — 단순, 사용자 통제권 명확
(b) merge 로직 — user_edited=true 행은 보존, 나머지만 교체. 베테랑 워크플로우 자연스럽
(c) diff view — 재분석 직후 변경 항목 보여주고 채택/거절 선택

영향 범위: app/services/inspection/inspection_result_mapper.rb (manual? 항목 보존 로직 유사), app/controllers/analyses_controller.rb 의 /analyses/new POST 흐름.

TDD + Tidy First. 결정 후 plan-eng-review 거쳐 구현. push2gh 로 PR + automerge.
```

---

## W1-3. C23 양도세 매트릭스 정밀화 (베테랑 retention)

**근거**: `docs/audits/2026-05-09-ux-audit-expert.md` E-25.
> 양도세율이 단순 평균치로 하드코딩 (`profit_calculator_controller.js:32-43`). 1주택자 비과세는 9억 초과/조정대상지역 시 다름; 다주택 40% 는 조정대상 중과 기준. 비조정지역은 다르다. 베테랑이 보면 1초만에 "이 도구 못 믿어" 결론.

**산출물**:
- `db/seeds/transfer_tax_matrix.json` (또는 yaml) — 보유기간/소유형태/조정대상지역 매트릭스
- `app/services/tax/transfer_tax_calculator.rb` — 매트릭스 룩업 서비스
- `app/javascript/controllers/profit_calculator_controller.js` — 하드코딩 제거, fetch API 호출
- `app/views/properties/show.html.erb` — 조정대상지역 입력 추가
- 테스트: 12 매트릭스 케이스

**실행 프롬프트**:
```
C23 (전문가 audit E-25): 양도세 매트릭스 정밀화. 베테랑 retention 직결.

현재 상태: app/javascript/controllers/profit_calculator_controller.js:32-43 에 양도세율이 단순 평균치로 하드코딩. 1주택자 비과세 조건/조정대상지역 중과/비조정 차등 미반영.

목표:
- db/seeds/transfer_tax_matrix.json 생성 — (보유기간, 소유형태, 조정대상지역, 가액구간) 4차원 매트릭스
- app/services/tax/transfer_tax_calculator.rb 신규 — 입력 → 세율 + 산식 노출
- profit_calculator UI 에 조정대상지역 토글 + 보유기간 input 추가
- 산식 토글 (C15) 와 함께 "이 세율은 X 매트릭스의 Y행" 출처 표시 (베테랑 검증 가능)
- 출시 후이므로 마이그레이션 없는 seeds JSON 우선

먼저 office-hours 로 매트릭스 출처 신뢰성 (국세청 vs 사용자 입력 vs 추정) 결정. 그 다음 plan-eng-review.

TDD: 12개 케이스 (1주택 vs 다주택 × 2년 미만/이상 × 조정대상 yes/no) 의 expected 세율부터 작성.

push2gh 로 PR + automerge. PR title: feat(profit-calculator): seed-driven transfer tax matrix with 조정대상지역 input (C23, E-25)
```

---

## W1-4. C25 소액임차인 최우선변제 자동 계산

**근거**: `docs/audits/2026-05-09-ux-audit-expert.md` E-27.
> 배당표 시뮬레이션이 아예 없다. 매각대금 → 집행비용 → 최우선변제(소액임차인) → 당해세 → 우선변제 → 일반채권 순서의 시뮬레이션이 없다.

**산출물**:
- `db/seeds/small_tenant_priority_table.json` — 시기별/지역별 보증금 한도 + 최우선변제액 매트릭스 (시행령 별표)
- `app/services/inspection/dividend_simulator.rb` — 매각가 입력 → 단계별 배당 시뮬
- `app/components/dividend_simulator_component.{rb,html.erb}` — 결과 카드
- B1 (인스펙션 distribution simulator) 와 통합

**실행 프롬프트**:
```
C25 (전문가 audit E-27): 소액임차인 최우선변제 자동 계산. 권리분석 정확도 핵심.

현재 상태: B1 (PR #92) 으로 임차인 미배당 잔액 시뮬레이터까지는 갔으나, 소액임차인 최우선변제 우선순위가 자동 계산되지 않음.

목표:
- 시행령 별표 (지역별/시기별 보증금 한도 + 최우선변제액) 시드 데이터 작성. 현행 + 과거 5개 시기 정도
- DividendSimulator 서비스: 매각가 입력 → 집행비용 → 최우선변제 → 당해세 → 우선변제 → 일반채권 순서의 단계별 배당 시뮬
- 결과 카드: "예상 매각가 X 일 때 임차인 미배당 잔액 = 인수금액 Y" 명시
- B1 의 distribution_simulator 와 통합 또는 그것을 확장

먼저 office-hours 로 시드 데이터의 신뢰성 + 갱신 주기 결정. plan-eng-review 로 단계별 우선순위 알고리즘 검증.

TDD: 시행령 시기별 (예: 서울 2023.2 ~ 현재) 케이스 + 매각가 시나리오 매트릭스.

push2gh + automerge. PR title: feat(rights): small tenant first-priority dividend simulator (C25, E-27)
```

---

# Wave 2 — 출시 후 3~6주 (Phase C-2 핵심)

## W2-1. C22 회차별 저감률 + 낙찰가 통계 시드

**근거**: E-24. 입찰가 산정 보조 도구 빈약. 베테랑은 (a) 인근 낙찰가 통계, (b) 회차별 저감률(20%), (c) 경쟁률 — 셋을 종합.

**의존**: court auction 낙찰 결과 데이터 수집 (현재 검색만 있고 결과 없음). 별도 수집 인프라 필요.

**실행 프롬프트**:
```
C22 (전문가 audit E-24): 입찰가 산정 보조 — 회차별 저감률 + 인근 낙찰가 통계.

배경:
- (b) 차회 매각가 = 최저가 × 0.8 자동 계산: 즉시 가능 (단순 산식)
- (a) 인근 낙찰가 통계: 법원경매 사이트에서 낙찰 결과 데이터 수집 인프라 필요
- (c) 경쟁률: 데이터 수집 후 가능

먼저 office-hours 로 (a) 데이터 수집 방식 결정 — 옵션:
1. 사용자가 "이 물건 추가" 시 즉시 매각결과까지 한 번 스크래핑
2. 백그라운드 잡 — 진행 중 매물의 매각기일 다음날 결과 수집
3. 일괄 cron 으로 지난 1년 낙찰결과 import
4. (a) 보류, (b) 만 빠르게 추가

데이터 출처: courtauction.go.kr 검색 결과 페이지. CourtAuction adapter 확장 필요.

저장 모델: 신규 AuctionResult 모델 (case_number, sale_price, bidder_count, sold_at).

(b) 부터 빠르게 시작하고 (a) 는 별도 PR 로 분리 권장.

TDD + Tidy First. push2gh + automerge. PR title: feat(profit-calculator): next-round price + winning bid statistics (C22, E-24)
```

---

## W2-2. C26 DSR 한도 계산

**근거**: E-29. 연봉/부채 입력 → DSR 한도 계산 → 입찰가 상한 산출.

**실행 프롬프트**:
```
C26 (전문가 audit E-29): DSR 한도 계산.

현재 상태: 예산 wizard (BudgetSetting) 는 LTV 만 다룸. DSR 미반영 → 실제 대출 거절 가능.

목표:
- BudgetSetting 에 annual_income (연봉), existing_debt_payment (월 부채상환액) 컬럼 추가 (마이그레이션)
- DsrCalculator 서비스: (annual_income, existing_debt, new_loan_principal, rate, term) → DSR 비율 + 한도 충족 여부
- 예산 wizard step 4 추가 또는 step 3 확장
- profit_calculator UI 에 DSR 경고 배너: "이 입찰가는 DSR 한도 초과"

먼저 office-hours 로 DSR 입력값 신뢰성 (사용자 자기보고만 vs 향후 마이데이터 연계) 결정.

TDD: 보수적 DSR 40% 기준 + 다양한 부채 시나리오.

push2gh + automerge. PR title: feat(budget): DSR-based loan limit + warning on profit calculator (C26, E-29)
```

---

## W2-3. C24 취득세 매트릭스 (C23 후속)

**의존**: C23 의 조정대상지역 입력 재사용.

**실행 프롬프트**:
```
C24 (전문가 audit E-26): 취득세 매트릭스 정밀화. C23 후속.

현재 상태: 취득세도 단순 평균. 면적/지역/가액 분기 미반영.

목표:
- db/seeds/acquisition_tax_matrix.json — 면적/지역/가액 매트릭스
- AcquisitionTaxCalculator 서비스
- profit_calculator 통합 (C23 의 조정대상지역 입력 재사용)

TDD + Tidy First. push2gh + automerge. PR title: feat(profit-calculator): acquisition tax matrix (C24, E-26)
```

---

## W2-4. C27 property_type 분기 (오피스텔/상가/토지)

**근거**: E-31. 시드의 property_types: 아파트/단독주택/빌라만. 오피스텔(주거용 vs 업무용 — 세금 다름), 상가(임대차보호 다름), 토지(법정지상권), 공장/창고 — 권리분석/세무 로직 모두 다름.

**실행 프롬프트**:
```
C27 (전문가 audit E-31): property_type 4분류 분기 (주거/업무/상가/토지).

현재 상태: db/seeds/property_types — 아파트/단독주택/빌라만. 베테랑이 다루는 (a) 다세대/다가구 구분, (b) 오피스텔(주거용 vs 업무용), (c) 상가(임대차보호 다름), (d) 토지(법정지상권) — 모두 권리분석/세무 로직 다른데 도구는 "아파트면 X" 정도만 분기.

목표:
- 4분류(주거용/업무용/상가/토지) 만이라도 권리분석/세무 로직에서 분기
- InspectionItem.visible_for? 에 property_type 분기 추가
- TenantValidator / RightsValidator 가 상가/토지 케이스 별도 처리 (예: 상가 임대차는 환산보증금 5억 한도)
- 세무 매트릭스(C23/C24) 도 property_type 별로

먼저 office-hours 로 4분류만 vs 8분류(다세대/다가구 추가 등) 결정.

TDD: 각 type 별 시나리오 매트릭스. 기존 아파트 케이스 회귀 가드 필수.

push2gh + automerge. PR title: feat(property): property_type-aware rights/tax branching (C27, E-31)
```

---

## W2-5. C28 공유지분 매물 + 보증금 비율 적용

**근거**: E-32. 일부 지분만 경매면 임차인 보증금 인수가 지분 비율대로 적용되는데 도구는 100% 인수로 계산.

**의존**: A6 (공유자 우선매수권 항목)

**실행 프롬프트**:
```
C28 (전문가 audit E-32): 공유지분 매물 보증금 비율 적용.

현재 상태: 일부 지분만 경매여도 임차인 보증금 인수가 100% 로 계산됨.

목표:
- Property.share_ratio (decimal, default 1.0) 컬럼 추가
- AuctionScrapingService 가 매각물건명세서에서 지분 비율 추출 (LLM prompt 보강)
- RightsValidator: assumed_amount 계산 시 share_ratio 곱하기
- UI: share_ratio < 1.0 시 "일부지분 매각 (X/Y)" 배지 + 인수금액 옆 "지분비율 적용됨" 표시

A6 와 함께 — 공유자 우선매수권 신고 여부도 같이 표시하면 시너지.

TDD + Tidy First. push2gh + automerge. PR title: feat(rights): partial-share property handling for assumed amount (C28, E-32)
```

---

## W2-6. C29 인도명령 6개월 D-day 추적

**의존**: B12 (D-day 배지 패턴 재사용)

**실행 프롬프트**:
```
C29 (전문가 audit E-33): 인도명령 6개월 D-day 추적.

배경: 잔금 납부 후 6개월 내 인도명령 신청 안 하면 명도소송으로 가야 함 (시간/비용 폭증). 시뮬레이터는 단계별 질문만 하고 마감일 추적 없음.

목표:
- UserProperty 에 balance_paid_on (잔금 납부일) 컬럼 추가
- "잔금 납부일 입력" UI (eviction simulator 결과 페이지 또는 user property settings)
- 입력 시 "인도명령 신청 마감일 D-XX" 자동 표시 (B12 D-day 배지 컴포넌트 재사용)
- D-30 / D-7 알림 (C30 Notification 채널 의존)

C30 의존성: 알림은 C30 시스템 셋업 후 추가.

TDD + Tidy First. push2gh + automerge. PR title: feat(eviction): possession-order deadline countdown (C29, E-33)
```

---

## W2-7. C30 Notification 채널 (이메일 + in-app)

**근거**: E-34. 입찰일/매각기일 알림 시스템 부재.

**실행 프롬프트**:
```
C30 (전문가 audit E-34): Notification 채널 (이메일 + in-app).

현재 상태: Notification 모델/큐 없음. 매물별 D-day 카운터 없음.

목표:
- Notification 모델 (user, channel: in_app|email, payload, sent_at, read_at)
- NotificationDispatchJob — Solid Queue, 매일 cron 으로 enqueue
- NotificationPolicy — D-7/D-3/D-day 알림 결정 로직
- 이메일: ActionMailer + Cafe24 SMTP 또는 Gmail SMTP
- in-app: 헤더 종소리 아이콘 + 카운트, 클릭 시 목록
- B12 의 next_auction_schedule + C29 의 balance_paid_on 둘 다 트리거

먼저 office-hours 로 SMTP 공급자 + 비용 결정 (Mailgun 무료 5,000건/월, SendGrid 무료 100건/일, Cafe24 자체 SMTP).

TDD: NotificationPolicy 의 D-day 결정 매트릭스, NotificationDispatchJob idempotent (동일 이벤트 중복 발송 안 됨).

push2gh + automerge. PR title: feat(notify): email + in-app notifications for auction D-day events (C30, E-34)
```

---

# Wave 3 — Phase C-1 폴리시 (3~6주, 묶음 처리 권장)

22건이 모두 작은 단위. 카테고리별 1 PR 로 묶음.

## W3-1. 모바일 정렬 묶음 (C1, C2, C3, C7, C13, C17)

**실행 프롬프트**:
```
Phase C-1 모바일 폴리시 6건 묶음 처리. 작은 단위이므로 한 PR.

대상:
- C1 (B-23): inspection_tabs_component.html.erb sm 이하 드롭다운 전환 (B30 PR #118 에서 일부 처리됨 — 잔여 부분만)
- C2 (B-24): onboardings/step1.html.erb:29-39 세로 스택
- C3 (B-25): simulator_question_component.html.erb:46-74 위/아래 스택
- C7 (B-31): 헤더 예산 뱃지 모바일 햄버거 이동
- C13 (B-38): 시뮬 결과 카드 grid sm:1
- C17 (B-42): 인스펙션 sticky header 2단 분리

각 항목마다 system test 로 mobile viewport (375px) screenshot 검증. 회귀 가드.

TDD + Tidy First. push2gh + automerge. PR title: refactor(mobile): viewport-aware layout polish — 6 items (C1, C2, C3, C7, C13, C17)
```

---

## W3-2. 내부 코드 노출 제거 묶음 (C4, C5, C20)

**실행 프롬프트**:
```
Phase C-1 내부 코드 노출 제거 3건 묶음.

대상:
- C4 (B-26): "F02" 같은 내부 모듈 코드 화면 노출 제거 (f02_prefill_component, 시뮬레이터 result 페이지 등)
- C5 (B-27): simulator_question_component:31-34 의 "Q3" 같은 질문 코드 숨김
- C20 (B-45): 에러 메시지의 "F02-Q3" 같은 코드 표기 제거

내부 코드는 디버깅/로그용으로 유지하되, 사용자 화면에는 한국어 의미만 노출.

TDD: 각 view component 의 rendered HTML 에서 "F02" / "Q\\d+" 패턴 부재 assertion.

push2gh + automerge. PR title: refactor(ux): hide internal module/question codes from user-facing copy (C4, C5, C20)
```

---

## W3-3. 인지 흐름 정리 묶음 (C6, C9, C10, C15, C18)

**실행 프롬프트**:
```
Phase C-1 인지 흐름 정리 5건 묶음.

대상:
- C6 (B-30): onboardings/complete.html.erb:35 진입 화면 변경
- C9 (B-33): 사이드바 라벨 정리 (물건 목록 vs 내 물건 헷갈림 해소)
- C10 (B-34): 분석 전/후 카드 버튼 분기 (properties/show.html.erb:30-44) — 분석 전엔 "분석하기", 후엔 "보고서 보기"
- C15 (B-40): step3 산식 공개 토글 — "이 숫자가 어디서 나왔는지" detail
- C18 (B-43): 온보딩 step2 점진적 공개 (한 번에 다 보여주지 말기)

각 항목마다 변경 전후 system test screenshot 비교.

TDD + Tidy First. push2gh + automerge. PR title: refactor(ux): cognitive load polish — 5 items (C6, C9, C10, C15, C18)
```

---

## W3-4. 안내 / 가이드 묶음 (C8, C14, C16, C19)

**실행 프롬프트**:
```
Phase C-1 안내/가이드 4건 묶음.

대상:
- C8 (B-32): 매뉴얼 헤로 직후 "지금 시작하기" CTA
- C14 (B-39): 등급 페이지 PDF 옆 "전문가 상담" CTA (외부 링크 또는 안내 페이지)
- C16 (B-41): 헤더 "❓도움말" 상시 노출 + FAQ 페이지 (manuals 컨트롤러 확장)
- C19 (B-44): 시뮬레이터 "약 N개 질문 / 3분" 안내 (소요시간 예측)

먼저 office-hours 로 C14 "전문가 상담" 의 destination 결정 (제휴 변호사? 자체 상담 폼? 외부 링크?).

TDD + Tidy First. push2gh + automerge. PR title: feat(guide): contextual help and CTAs across key pages (C8, C14, C16, C19)
```

---

## W3-5. 빈 상태 / 진행 묶음 (C11, C12)

**실행 프롬프트**:
```
Phase C-1 빈 상태/진행 표시 2건 묶음.

대상:
- C11 (B-35): 물건 상세 진행 표시기 (분석 % / 체크리스트 답변 %)
- C12 (B-36): 카드 "?" 호버 → 클릭 토글 (모바일 호환 — 호버는 모바일에서 작동 안 함)

TDD + Tidy First. push2gh + automerge. PR title: feat(ux): progress indicator + mobile-friendly tooltip toggle (C11, C12)
```

---

# Wave 4 — Phase C-3 + 잔여

## W4-1. C34 a11y 점검 패스

**실행 프롬프트**:
```
C34: 접근성 (a11y) 점검 패스.

대상: 전 페이지의 aria-label, focus trap, 키보드 네비게이션, color contrast, 스크린리더 호환성.

도구: axe-core (Capybara 통합), pa11y, 또는 lighthouse a11y 점수.

목표: 모든 페이지 a11y score ≥ 95.

TDD: system test 에 axe-core assertion 추가. 회귀 발견 시 수정 후 재테스트.

push2gh + automerge. PR title: chore(a11y): full accessibility audit pass via axe-core (C34)
```

---

## W4-2. C31 analyses#prompt endpoint 노출 축소

**실행 프롬프트**:
```
C31 (전문가 audit E-39): analyses#prompt endpoint 보안 점검.

배경: LLM 프롬프트 텍스트가 GET endpoint 로 노출. 인증 없이 호출 가능한지 + rate-limit 적용 여부 점검.

목표:
- 인증 없이 호출 가능하면 require_authenticated_user before_action 추가
- rate-limit 미적용이면 rack-attack 룰 추가 (per-IP 60req/min 정도)
- prompt 내용 캐싱 + 정적화 검토 (응답이 매번 동일하다면)

TDD: 비인증 요청 → 401/302, 인증된 요청 빠르게 60회 → 429.

push2gh + automerge. PR title: fix(security): authenticate analyses#prompt endpoint + rate limit (C31, E-39)
```

---

# 세션 follow-ups (24건)

오늘 (2026-05-10) 처리한 PR 들에서 reviewer 가 잡아낸 follow-up 항목.

## 출시 전 차단 항목 (이미 #119 로 처리됨)

- ✅ #1 TZ default Asia/Seoul → PR #119
- ✅ #4 support email placeholder → PR #119

## 출시 후 처리 가능 (22건)

각 항목 상세는 `docs/superpowers/plans/2026-05-10-ux-audit-remaining-backlog.md` §"Follow-ups discovered" 참조.

### 우선순위 1 (출시 직후 1주 내)

**Follow-up #13** — AI 재분석 silent overwrite (W1-2 위에 별도 항목으로 추출)

**Follow-up #2** — Other LLM adapter truncation detection
```
B30 follow-up #2: Anthropic 외 LLM adapter (Gemini/OpenAI/OpenRouter/Ollama) 도 max_tokens 잘림 감지 적용.

배경: B30 PR #118 에서 Anthropic adapter 만 finish_reason 기반 truncation detect + 재시도 처리 추가됨. 다른 adapter 는 동일 이슈 발생 시 silent JSON parse failure 로 표면화.

목표: 각 adapter 의 응답에서 truncation signal 확인:
- Gemini: candidates[0].finishReason == "MAX_TOKENS"
- OpenAI: choices[0].finish_reason == "length"
- OpenRouter: OpenAI-호환
- Ollama: done == false + done_reason == "length"

공통 LlmTruncationError 던지고 service 단에서 retry with larger max_tokens.

TDD: 각 adapter 별 truncated response fixture + integration test.

push2gh + automerge. PR title: fix(llm): detect truncation across all adapters and retry with larger budget
```

### 우선순위 2 (출시 후 2~3주)

**Follow-up #9, #10** — InspectionResultVersion 동시성 + N+1
**Follow-up #15, #16, #19** — B27/B10 controller 응답 견고화
**Follow-up #17** — B10 사진 N+1 preload
**Follow-up #18** — B10 멀티파일 업로드
**Follow-up #20, #21, #22** — B9 비교 보드 확장 (CSV / 예상순이익 / sortable)
**Follow-up #23** — B9 sessionStorage 영속 system test
**Follow-up #24** — B11 50건 sync 25s 블로킹 → background job

각 항목별 prompt 는 backlog 파일 참조 후 동일 패턴 ("배경 / 목표 / TDD / push2gh + automerge") 으로 즉석 작성 가능.

### 우선순위 3 (출시 후 1개월+)

**Follow-up #3** — `reserve_fund_default.rb` 영문 validation 메시지 한국어화 (admin-only)
**Follow-up #5, #6** — Bid opinion 책임 문구 정리 + LegalDisclaimerComponent role="note"
**Follow-up #7** — Property card overflow menu Esc/focus management (WAI-ARIA menu)
**Follow-up #8** — error_message tooltip truncate
**Follow-up #11, #12** — property/show heading hierarchy + nested cards (재확인 필요 — B20 stepper 도입 후 부분 해결 가능성)
**Follow-up #14** — B27 base_right_date show 액션 controller test 추가

---

# 인프라 후속 (출시 직후)

## I-1. lograge → GlitchTip 또는 Sentry 검토

운영 1주 관찰 후 lograge 만으로 부족하면 GlitchTip (self-hosted, 무료) 또는 Sentry (SaaS, free tier 5K events/월) 도입 검토.

## I-2. self-hosted GitHub Actions runner

**근거**: 2026-05-10 GitHub Actions 결제 차단 → 워크플로 임시 비활성화 (`.disabled` 접미사). 출시 후 영구 해결.

**실행 프롬프트**:
```
GitHub Actions self-hosted runner 셋업. 현재 .github/workflows/*.yml.disabled 상태 (2026-05-10 결제 이슈로 비활성화).

목표:
1. Cafe24 서버에 GitHub Actions runner agent 설치 (GitHub → Settings → Actions → Runners → New self-hosted runner 메뉴 안내 따라)
2. .github/workflows/*.yml.disabled → *.yml 로 rename (4개)
3. 각 워크플로의 runs-on: ubuntu-latest → runs-on: self-hosted 로 변경
4. runner systemd 서비스 등록 (재부팅 시 자동 시작)
5. runner 보안: GitHub-recommended ephemeral runner 또는 isolated container 검토
6. 빌드 캐시 디렉토리 분리 (DB / Rails 별도)

리스크: Cafe24 4GB RAM 빠듯 — runner 가 빌드 시 OOM 가능. 빌드 최대 메모리 cap (Docker --memory 2g) 권장.

먼저 office-hours 로 cost/risk trade-off 확인. 그 다음 plan-eng-review 로 격리 전략 결정.

push2gh + automerge. PR title: ops: revive CI workflows on self-hosted runner
```

## I-3. Litestream (출시 후 1개월+)

**근거**: 백업이 현재 local-only. 디스크 fail 시 손실. 사용자 본인 명시적으로 외부 사본 거부했지만, 운영 1개월 후 재논의.

---

# Phase C 외 — 출시 후 발견될 미지의 것들

운영 1주 (5/12~5/18) 관찰 + 정식 출시 후 사용자 피드백으로 발견될 신규 항목은 별도 backlog 파일로 관리. 작성 시점:

- D+7 (2026-05-26): 첫 운영 회고 + 백로그 파일 신규 작성 (`docs/superpowers/plans/2026-05-26-post-launch-week1-backlog.md`)
- D+30 (2026-06-18): 한 달 회고 + Phase C 전체 우선순위 재조정

---

# 작성 규칙

새 항목 추가 시:
1. Wave 분류 (1~4) 먼저 정함
2. 실행 프롬프트는 다음 템플릿 따름:
   ```
   <항목 ID> (<감사 출처>): <한 줄 요약>.

   배경: <왜 필요한지>

   목표:
   - <구체 산출물 1>
   - <구체 산출물 2>

   <office-hours / plan-eng-review 필요 여부>

   TDD + Tidy First. push2gh + automerge. PR title: <type>(<scope>): <subject>
   ```
3. 의존성 (다른 항목 또는 외부 데이터) 명시
4. 이미 처리된 항목은 ✅ 표시 + PR 번호

---

**End of post-launch roadmap.**
