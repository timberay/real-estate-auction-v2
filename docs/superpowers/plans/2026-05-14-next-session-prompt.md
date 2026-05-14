# 다음 세션 시작 프롬프트 (전체 잔여 작업)

**작성일**: 2026-05-14 (확장: Theme 4 잔여 3건 → 전체 잔여 12건 + 인프라 3건)
**용도**: 다음 Claude Code 세션에 이 파일 내용을 그대로 paste 해서 전체 잔여 자동 진행 모드 진입.

---

## 다음 세션에 paste 할 내용

```text
다음 지침을 기준으로 real-estate-auction 프로젝트의 잔여 작업을 진행해줘.

## 이전 세션까지의 진행 상태 (2026-05-14 기준)

| Theme | 상태 |
|-------|------|
| 1. 계산 엔진 신뢰성 | 4/6 완료 — T1.1·T1.2·T1.4(b)·T1.5 ✅, **T1.3·T1.4(a) 대기** |
| 2. 운영 가시성 + 안전망 | 7.5/8 — T2.1~T2.5·T2.7·T2.8 ✅, **T2.6 Vitest 사용자 결정 대기** |
| 3. 권리분석/매물 다양성 | ✅ 완료 (T3.1~T3.6, 6/6) |
| 4. UX 폴리시 + 외부 정리 | 6/9 완료 — T4.1·T4.2·T4.3·T4.4·T4.5·T4.7 ✅, **T4.6·T4.8·T4.9 대기** |

**지난 세션 머지된 PR (2026-05-14)**: #157~#162 (Theme 4 6건)

진실 소스 / reference:
- 마스터 TODO: `docs/superpowers/plans/2026-05-14-master-todo.md`
- 원본 roadmap: `docs/superpowers/plans/2026-05-10-post-launch-roadmap.md`
- 부채 감사: `docs/superpowers/plans/2026-05-12-existing-feature-debt.md`
- UX backlog: `docs/superpowers/plans/2026-05-10-ux-audit-remaining-backlog.md`

## 작업 패턴 (이전 세션에서 검증됨)

1. 마스터 TODO 가 진실 소스. 새 작업 시작/완료 시마다 업데이트 + commit + push.
2. 의사결정 알아서 추천 방향. 기능 대폭 추가 피한다 — minimum viable 로 좁히고 follow-up 분리.
3. 단일 PR per task. 작업 끝나면 한 번에 PR.
4. Telegram 핑 (chat_id 8539138772) — 자주:
   - 시작 시 스코프 결정 공유
   - 마일스톤마다 짧게 ("검사 통과" 표현 사용)
   - 의미있는 상태 전이마다 (RED→GREEN, 풀 스위트 결과, PR 생성, 라벨 추가, 머지)
   - 결정 필요 시 Telegram 질문 + 시간 내 응답 없으면 추천대로 진행
   - 완료 시 PR 번호 + 다음 후보
5. 각 소기능 완료 전 충분한 검사 — TaskUpdate(completed) 전 반드시 통과:
   단위 → 시스템 → 전체 스위트 → 실 브라우저 QA (정상/경계/에러) → 콘솔/서버 로그 → 발견된 모든 오류 수정 → 재검사 루프.
6. TDD + Tidy First. pre-commit hook 이 풀 스위트를 돌리므로 작은 변경도 모두 통과 후에만 commit.
7. /push2gh 스킬 — Flow C: feature branch + PR + automerge 라벨 + gh pr merge 번호 --squash --delete-branch. 머지 후 main 동기화 + 마스터 TODO 업데이트 commit + push.
8. 중지("중지") 요청 시 즉시 정지, 상태 보고.
9. 실 브라우저 QA 시 `RAILS_ENV=development bundle exec rails server -d` 로 daemonized 시작 (background bash 는 harness 가 SIGTERM 보냄). 종료는 `cat tmp/pids/server.pid | xargs kill`.
10. tooltip toggle 같은 Stimulus interaction 은 system test 로 회귀 가드 (browser QA 는 자동화 보충용).

## 전체 잔여 항목 (12건 + 인프라 3건)

### Theme 1 — 계산 엔진 (2건)

| ID | 항목 | 원본 ref |
|----|------|---------|
| T1.3 | 소액임차인 최우선변제 자동 계산 (DividendSimulator) | W1-4 / C25 / E-27 |
| T1.4(a) | 인근 낙찰가 통계 + 경쟁률 (스크래퍼 + AuctionResult 모델) | W2-1 / C22 / E-24 |

### Theme 2 — 운영 가시성 (1건, 사용자 결정 대기)

| ID | 항목 | 원본 ref |
|----|------|---------|
| T2.6 | Vitest 인프라 도입 결정 (system test 보강은 이미 완료) | A3 |

### Theme 4 — UX 폴리시 (3건)

| ID | 항목 | 원본 ref |
|----|------|---------|
| T4.6 | a11y 점검 패스 (axe-core 통합) | W4-1 / C34 |
| T4.8 | Backlog P3 묶음 8건 (한국어화 / disclaimer / menu Esc / tooltip / heading / nested cards / controller test) | Follow-up #3/#5/#6/#7/#8/#11/#12/#14 |
| T4.9 | 외부 게이트 5건 (CSP / OAuth redirect URI / SNS self-review / Symbol provider 회귀 / branch protection) | W0-1~5 |

### 코드 부채 (3건, 환경/도구)

| ID | 항목 | 원본 ref |
|----|------|---------|
| D1 | `Gemfile` `:windows` 플랫폼 심볼 + `.ruby-version` 표준화 | C3 (debt) |
| D2 | `preferred_purchase_risk` 라벨 의미 충돌 (TODO 코멘트 기 표시) | C1 (debt) |
| D3 | TODOS.md 사건번호 후속 3건 (60-법원 auto-discovery / `Property#refresh_from_court_auction!` / CaseSearchService race-rescue 테스트) | C2 (debt) |

### 인프라 도입 검토 (3건, 운영 후 결정)

| ID | 항목 | 원본 ref |
|----|------|---------|
| I1 | GlitchTip 또는 Sentry 검토 (lograge 1주 운영 후) | I-1 |
| I2 | self-hosted GitHub Actions runner 부활 (`.yml.disabled` → 활성화) | I-2 |
| I3 | Litestream 외부 백업 검토 (출시 후 1개월+) | I-3 |

---

## 세부 내용

### T1.3 소액임차인 최우선변제 (DividendSimulator)

근거: 전문가 audit E-27. B1 (PR #92) 으로 임차인 미배당 잔액 시뮬레이터까지는 갔으나, 소액임차인 최우선변제 우선순위가 자동 계산되지 않음.

minimum viable:
- DividendSimulator 서비스: 매각가 입력 → 집행비용 → 최우선변제 → 당해세 → 우선변제 → 일반채권 순서의 단계별 배당 시뮬
- profit_calculator/권리분석 결과에 노출
- TDD + Tidy First. PR title: `feat(rights): small tenant first-priority dividend simulator (C25, E-27)`

원본: `docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` W1-4 절.

### T1.4(a) 인근 낙찰가 통계 + 경쟁률

근거: 전문가 audit E-24. 베테랑은 (a) 인근 낙찰가 통계, (b) 회차별 저감률(20%), (c) 경쟁률 — 셋을 종합. (b) 는 T1.4(b) PR #141 에서 완료.

minimum viable:
- 신규 `AuctionResult` 모델 (case_number, sale_price, bidder_count, sold_at)
- 법원경매 사이트 낙찰 결과 스크래퍼 인프라
- profit_calculator 에 인근 매물 통계 + 경쟁률 표시
- PR title: `feat(profit-calculator): nearby winning bid statistics (C22, E-24)`

스크래퍼 인프라 영향이 큼 — Telegram 추천 후 사용자 확인 필요.

원본: `docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` W2-1 절.

### T2.6 Vitest 인프라 (사용자 결정 대기)

근거: 부채 감사 A3. JS/Stimulus 테스트 0건. 현재 system test 로 cover 중. Vitest 도입 여부는 사용자 결정 필요.

옵션:
- (a) Vitest + happy-dom + import-maps shim — 인프라 도입
- (b) 현재 system test 그대로 유지 — 추가 작업 없음

원본: `docs/superpowers/plans/2026-05-12-existing-feature-debt.md` A3.

### T4.8 세부 (Follow-up 8건)

- #3 `reserve_fund_default.rb` 영문 validation 한국어화 (admin-only)
- #5 Bid opinion 책임 문구 정리
- #6 LegalDisclaimerComponent role="note"
- #7 Property card overflow menu Esc/focus management (WAI-ARIA menu)
- #8 error_message tooltip truncate
- #11 property/show heading hierarchy
- #12 property/show nested cards
- #14 B27 base_right_date show 액션 controller test

원본: `docs/superpowers/plans/2026-05-10-ux-audit-remaining-backlog.md` "Follow-ups discovered" 절.

### T4.9 세부

- W0-1 CSP report_only → enforce (1주 csp.violation 0건 확인 후 플립)
- W0-2 OAuth 콘솔 redirect URI (Google/Naver/Kakao, **운영 도메인 확정 후**)
- W0-3 SNS self-review 4건 — multi-tab session sync, account settings, rack-attack 확장, /terms·/privacy 본문
- W0-4 OAuth Symbol provider 회귀 테스트 (test/infra debt — 테스트만 추가)
- W0-5 Branch protection 정책 — GitHub Pro 구독 / public 전환 / status check polling

원본: `docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` Wave 0 절.

### D1 Gemfile / .ruby-version 표준화

- `Gemfile` 의 `:windows` 심볼 (Ruby 3.0 + 구 Bundler 에서 파싱 실패) 정리
- `.ruby-version` 확정 + Bundler 버전 명시 → dev 환경 표준화

원본: `docs/superpowers/plans/2026-05-12-existing-feature-debt.md` C3.

### D2 preferred_purchase_risk 라벨 의미 충돌

- A6 follow-up. TODO 코멘트로 표시되어 있는 라벨 의미 충돌 정리 (스코프 작음, 한 PR)

원본: `docs/superpowers/plans/2026-05-12-existing-feature-debt.md` C1.

### D3 TODOS.md 사건번호 후속 3건

- 60-법원 auto-discovery fallback (ActiveJob 필요)
- `Property#refresh_from_court_auction!`
- CaseSearchService race-rescue 테스트 (`case_search_service.rb:39-40` dead branch)
- (메타) `TODOS.md` 폐기 또는 단일 통합 권장 — existing-feature-debt 의 메타 권장사항. 처리 시 master TODO 로 일원화.

원본: `docs/superpowers/plans/2026-05-12-existing-feature-debt.md` C2.

### I1~I3 인프라

- **I1** lograge 운영 1주 후 GlitchTip(self-hosted, 무료) 또는 Sentry(SaaS free tier 5K events/월) 도입 검토
- **I2** self-hosted GH Actions runner — `.github/workflows/*.yml.disabled` 부활. Cafe24 서버에 runner agent 설치 → `runs-on: self-hosted` 로 변경. PR title: `ops: revive CI workflows on self-hosted runner`
- **I3** 출시 후 1개월+ 시점에 Litestream 외부 백업 검토

원본: `docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` I-1, I-2, I-3 절.

---

## 세션 분할 가이드

Opus 4.7 1M 컨텍스트 + 자동 압축이 있지만, **PR 단위로 압축 전에 끊고 새 세션을 여는 게** 정확도/속도 측면에서 유리하다 (압축 후 세부 디테일 손실 + 도구 출력 무게).

지난 세션 PR #157~#162 패턴 기준 1 PR ≈ 40–300k 토큰 (작업 복잡도에 따라). 아래 세션 분할은 한 세션 ≤ 50% 컨텍스트 사용을 목표로 한다.

### 세션 1 — UX 폴리시 + a11y (도메인 무관)

추정: ~300–450k 토큰 (압축 없이 마무리 가능).

순서:
1. **T4.8 첫 묶음**: #3 한국어화 + #6 role="note" + #14 controller test (가장 단순 3건, 단일 PR)
2. **T4.8 둘째 묶음**: #5 disclaimer + #8 tooltip truncate (단일 PR)
3. **T4.8 셋째 묶음**: #7 a11y menu + #11/#12 heading/cards (a11y 인접, 단일 PR)
4. **T4.6 axe-core a11y 인프라**: `axe-core-capybara` gem (or vendor axe.min.js) + ApplicationSystemTestCase helper + 핵심 페이지 1~2개 baseline assertion. 발견되는 a11y 이슈는 별도 PR로 분리하여 다음 세션으로.
5. **T4.9 W0-4 OAuth Symbol provider 회귀 테스트** — 테스트만 추가, 작음

세션 종료 조건: 위 5개 PR 머지 + 마스터 TODO 업데이트 + Telegram 으로 세션 결과 보고.

### 세션 2 — 계산 엔진 신뢰성 (T1.3 단독)

추정: ~150–300k 토큰 (단일 PR 집중).

내용:
- **T1.3 소액임차인 최우선변제 (DividendSimulator)** — 단일 PR.
- minimum viable: 매각가 입력 → 집행비용 → 최우선변제 → 당해세 → 우선변제 → 일반채권 순서의 단계별 배당 시뮬 서비스 + profit_calculator/권리분석 결과 통합.
- TDD + Tidy First. PR title: `feat(rights): small tenant first-priority dividend simulator (C25, E-27)`

세션을 단독으로 두는 이유: 새 서비스 + 권리분석 통합 + TDD 라 토큰 예산이 가장 크고, 압축이 발동하면 권리분석 도메인 디테일 손실 위험.

### 세션 3 — 환경 부채 (D1/D2/D3)

추정: ~100–200k 토큰.

순서:
1. **D1 Gemfile `:windows` + `.ruby-version` 표준화** — 단일 PR
2. **D2 `preferred_purchase_risk` 라벨 의미 충돌** — 단일 PR (TODO 코멘트 해소)
3. **D3 TODOS.md 사건번호 후속 3건** — 단일 PR 묶음 (60-법원 auto-discovery + `refresh_from_court_auction!` + CaseSearchService race-rescue 테스트). 처리 시 TODOS.md 폐기/통합도 함께.

세션 종료 후 master TODO 의 부채 D 섹션 비움.

### 추후 세션 — 사용자 결정 필요 (B 카테고리)

Telegram 추천 후 진행. 단일 세션에 묶지 말고 결정 후 별도 세션으로:
- **T1.4(a)** 인근 낙찰가 통계 — 스크래퍼 인프라 영향 큼. 별도 세션 권장 (~200–400k).
- **T2.6** Vitest 도입 의향 — 인프라 결정 (system test 유지 vs 도입). 결정만 받으면 짧음.
- **T4.9 W0-3** SNS self-review 4건 — 스코프 정의 필요.
- **T4.9 W0-5** Branch protection 정책 — GitHub Pro 구독 / public 전환 결정.

### 대기 (C/D 카테고리)

운영 도메인 또는 운영 로그 의존 — 외부 조건 충족 후:
- **T4.9 W0-2** OAuth 콘솔 redirect URI — 운영 도메인 확정 후
- **T4.9 W0-1** CSP enforce 플립 — 1주 csp.violation 로그 확인 후
- **I1** GlitchTip/Sentry — lograge 1주 운영 후
- **I2** self-hosted GH Actions runner — CI/CD 우선순위 결정 후
- **I3** Litestream 백업 — 출시 후 1개월+

## 시작 명령

**이번 세션은 세션 1 (UX 폴리시 + a11y) 만 작업한다.**

마스터 TODO + roadmap + remaining-backlog + feature-debt 문서를 (전체 정독이 아니라) **마스터 TODO 정독 + 나머지 grep/필요 시 부분 읽기** 로 훑은 뒤, 세션 1 의 1번 (T4.8 첫 묶음 #3+#6+#14) 부터 위 패턴 그대로 진행해줘. 매 PR 머지 후 Telegram 으로 다음 후보 공유. 세션 1 의 5개 PR 다 마치면 세션 종료 + Telegram 으로 세션 결과 보고 후 사용자에게 다음 세션 진입 여부 확인 요청.

세션 도중 컨텍스트 사용량이 50% 를 넘으면 Telegram 으로 보고 + 남은 항목을 다음 세션으로 미룰지 사용자에게 확인.

다른 흐름이 더 적합해 보이면 (예: 사용자가 T1.3 을 먼저 원함) Telegram 추천 후 세션 2 로 전환.

## 메모리

`~/.claude/projects/-home-tonny-projects-real-estate-auction/memory/`
- `feedback_thorough_qa.md` — 검사 통과 표현 + 충분한 검사 루프
- `feedback_telegram_milestone_pings.md` — 자주 핑
- `feedback_no_launch_schedule.md` — 일정 추적 X, 기능만
- `project_xcom_daily_post_format.md` — X.com 일일 build-in-public 포맷 (별도)

이대로 다음 세션에 붙여 넣으면 전체 잔여 자동 진행 모드 (자율 의사결정 + minimum viable + 단일 PR + Telegram milestone ping) 로 진입.
```

---

## 이번 세션 마무리 노트

- 지난 세션 (2026-05-14) Theme 4 진행: 6/9 (T4.1·T4.2·T4.3·T4.4·T4.5·T4.7) — 머지된 PR: #157~#162
- 풀 unit 1636+ runs / system 85 runs / 모두 통과
- 발견된 부가 이슈:
  - `ButtonComponent.new(...) { "text" }` block syntax 가 Class.new 에 binding 되어 텍스트 잃음. `do/end` 로 회피 (PR #159 complete.html.erb)
- **2026-05-14 확장 (1차)**: next-session prompt 가 Theme 4 잔여 3건만 → 전체 잔여 12건 + 인프라 3건 까지 포함하도록 확장
- **2026-05-14 확장 (2차)**: 우선순위 A/B/C/D 단순 나열 → **세션 분할 (세션 1/2/3 + 추후/대기)** 로 재구조화. 한 세션 ≤ 50% 컨텍스트 사용 목표, PR 단위로 끊고 새 세션 진입.
- 잔여 범위 (세션별 매핑):
  - **세션 1** (UX 폴리시 + a11y): T4.8 3 묶음 + T4.6 + W0-4 → 추정 300–450k
  - **세션 2** (계산 엔진): T1.3 단독 → 추정 150–300k
  - **세션 3** (환경 부채): D1 + D2 + D3 → 추정 100–200k
  - 추후 (사용자 결정): T1.4(a), T2.6, W0-3, W0-5
  - 대기 (외부 조건): W0-2, W0-1, I1, I2, I3
