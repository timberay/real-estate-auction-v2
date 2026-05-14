# 다음 세션 시작 프롬프트 (세션 2 진입용)

**작성일**: 2026-05-15 (세션 1 종료 직후)
**용도**: 다음 Claude Code 세션에 아래 코드 블록을 그대로 paste 해서 자동 진행 모드 진입.

---

## 다음 세션에 paste 할 내용

```text
다음 지침을 기준으로 real-estate-auction 프로젝트의 잔여 작업을 진행해줘.

## 이전 세션까지의 진행 상태 (2026-05-15 기준)

| Theme | 상태 |
|-------|------|
| 1. 계산 엔진 신뢰성 | 4/6 완료 — T1.1·T1.2·T1.4(b)·T1.5 ✅, **T1.3·T1.4(a) 대기** |
| 2. 운영 가시성 + 안전망 | 7.5/8 — T2.1~T2.5·T2.7·T2.8 ✅, **T2.6 Vitest 사용자 결정 대기** |
| 3. 권리분석/매물 다양성 | ✅ 완료 (T3.1~T3.6, 6/6) |
| 4. UX 폴리시 + 외부 정리 | 9/9 ✅ — **T4.6·T4.8 완료, T4.9 W0-4 완료, 외부 게이트 4건만 잔여** |

**지난 세션 머지된 PR**:
- **2026-05-14**: #157~#162 (Theme 4 묶음 6건)
- **2026-05-15 (세션 1)**: #163~#167 (T4.8 3 묶음 + T4.6 axe-core baseline + T4.9 W0-4)

진실 소스 / reference:
- 마스터 TODO: `docs/superpowers/plans/2026-05-14-master-todo.md`
- 원본 roadmap: `docs/superpowers/plans/2026-05-10-post-launch-roadmap.md`
- 부채 감사: `docs/superpowers/plans/2026-05-12-existing-feature-debt.md`
- UX backlog: `docs/superpowers/plans/2026-05-10-ux-audit-remaining-backlog.md`

## 작업 패턴 (2 세션 검증됨)

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
11. 새 controller/view 회귀 가드 테스트 추가 시 의미 검증: 액션을 일시 깨뜨려서 RED → 복구 → GREEN 루프 한 번 돌릴 것.

## 전체 잔여 항목 (8건 + 인프라 3건)

### Theme 1 — 계산 엔진 (2건)

| ID | 항목 | 원본 ref |
|----|------|---------|
| T1.3 | 소액임차인 최우선변제 자동 계산 (DividendSimulator) | W1-4 / C25 / E-27 |
| T1.4(a) | 인근 낙찰가 통계 + 경쟁률 (스크래퍼 + AuctionResult 모델) | W2-1 / C22 / E-24 |

### Theme 2 — 운영 가시성 (1건, 사용자 결정 대기)

| ID | 항목 | 원본 ref |
|----|------|---------|
| T2.6 | Vitest 인프라 도입 결정 (system test 보강은 이미 완료) | A3 |

### Theme 4 — 외부 게이트 (4건)

| ID | 항목 | 원본 ref |
|----|------|---------|
| T4.9 W0-1 | CSP report_only → enforce 플립 (1주 csp.violation 로그 0건 후) | W0-1 |
| T4.9 W0-2 | OAuth 콘솔 redirect URI (Google/Naver/Kakao) — **운영 도메인 확정 후** | W0-2 |
| T4.9 W0-3 | SNS self-review 4건 (multi-tab/account settings/rack-attack/terms·privacy) | W0-3 |
| T4.9 W0-5 | Branch protection 정책 — GitHub Pro / public 전환 / status check polling | W0-5 |

### Theme 4 — a11y 부채 (T4.6 axe baseline 후속, 4건)

세션 1 PR #166 으로 axe-core baseline 도입. 발견된 KNOWN_VIOLATIONS 4종을 후속 PR 로 fix:

| 규칙 | impact | 위치 / 작업 |
|------|--------|------------|
| html-has-lang | serious | `app/views/layouts/application.html.erb`: `<html lang="ko" class="h-full">` 한 줄 |
| select-name | critical | `properties#index` 의 `<select id="court_code">` 에 `aria-label="법원 선택"` |
| heading-order | moderate | properties#index empty-state `<h3>` → 페이지 heading 순서에 맞게 재검토 |
| color-contrast | serious | slate-400/500 텍스트가 light 배경에서 4.5:1 미달. 디자인 토큰 일괄 정비 |

각 fix 후 `test/system/a11y_baseline_test.rb` 의 `KNOWN_VIOLATIONS` 에서 해당 규칙 제거 + baseline 재실행으로 검증.

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

### T1.3 소액임차인 최우선변제 (DividendSimulator) — **세션 2 메인**

근거: 전문가 audit E-27. B1 (PR #92) 으로 임차인 미배당 잔액 시뮬레이터까지는 갔으나, 소액임차인 최우선변제 우선순위가 자동 계산되지 않음.

minimum viable:
- DividendSimulator 서비스: 매각가 입력 → 집행비용 → 최우선변제 → 당해세 → 우선변제 → 일반채권 순서의 단계별 배당 시뮬
- profit_calculator/권리분석 결과에 노출
- TDD + Tidy First. PR title: `feat(rights): small tenant first-priority dividend simulator (C25, E-27)`

원본: `docs/superpowers/plans/2026-05-10-post-launch-roadmap.md` W1-4 절.

### T1.4(a) 인근 낙찰가 통계 + 경쟁률

근거: 전문가 audit E-24. (b) 회차별 저감률은 T1.4(b) PR #141 에서 완료. (a) 인근 낙찰가 + 경쟁률은 스크래퍼 인프라 영향 큼 — Telegram 추천 후 사용자 확인 필요.

minimum viable:
- 신규 `AuctionResult` 모델 (case_number, sale_price, bidder_count, sold_at)
- 법원경매 사이트 낙찰 결과 스크래퍼 인프라
- profit_calculator 에 인근 매물 통계 + 경쟁률 표시
- PR title: `feat(profit-calculator): nearby winning bid statistics (C22, E-24)`

### T2.6 Vitest 인프라 (사용자 결정 대기)

옵션:
- (a) Vitest + happy-dom + import-maps shim — 인프라 도입
- (b) 현재 system test 그대로 유지 — 추가 작업 없음

### D1 Gemfile / .ruby-version 표준화

- `Gemfile` 의 `:windows` 심볼 (Ruby 3.0 + 구 Bundler 에서 파싱 실패) 정리
- `.ruby-version` 확정 + Bundler 버전 명시 → dev 환경 표준화

### D2 preferred_purchase_risk 라벨 의미 충돌

- A6 follow-up. TODO 코멘트로 표시되어 있는 라벨 의미 충돌 정리 (스코프 작음, 한 PR)

### D3 TODOS.md 사건번호 후속 3건

- 60-법원 auto-discovery fallback (ActiveJob 필요)
- `Property#refresh_from_court_auction!`
- CaseSearchService race-rescue 테스트 (`case_search_service.rb:39-40` dead branch)
- (메타) `TODOS.md` 폐기 또는 단일 통합 권장 — existing-feature-debt 의 메타 권장사항. 처리 시 master TODO 로 일원화.

### I1~I3 인프라

- **I1** lograge 운영 1주 후 GlitchTip(self-hosted, 무료) 또는 Sentry(SaaS free tier 5K events/월) 도입 검토
- **I2** self-hosted GH Actions runner — `.github/workflows/*.yml.disabled` 부활. Cafe24 서버에 runner agent 설치 → `runs-on: self-hosted` 로 변경
- **I3** 출시 후 1개월+ 시점에 Litestream 외부 백업 검토

---

## 세션 분할 가이드 (Opus 4.7 1M 컨텍스트 + 자동 압축; PR 단위로 끊는 게 정확도/속도 유리)

### 세션 2 (이번 세션 권장) — 계산 엔진 T1.3 단독 OR a11y fix 묶음

추정: T1.3 단독 ~150–300k / a11y fix 묶음 ~150–250k.

**옵션 A — T1.3 DividendSimulator 단독 (권장 if 우선순위가 베테랑 신뢰)**:
- 새 서비스 + 권리분석 통합 + TDD. 단일 PR.
- minimum viable: 매각가 입력 → 집행비용 → 최우선변제 → 당해세 → 우선변제 → 일반채권 순서의 단계별 배당 시뮬 서비스 + profit_calculator/권리분석 결과 통합.
- PR title: `feat(rights): small tenant first-priority dividend simulator (C25, E-27)`

**옵션 B — a11y fix 빠른 묶음 (권장 if 인프라 정리 우선)**:
1. **묶음 1** (가장 단순, 단일 PR): html-has-lang (`<html lang="ko">`) + select-name (`aria-label`) + heading-order (empty-state h3 재검토)
2. **묶음 2**: color-contrast — slate-400/500 → slate-600 일괄 토큰 정비 (영향 범위 큼, 단독 PR)

각 PR 머지 후 `KNOWN_VIOLATIONS` 에서 해당 규칙 제거.

### 세션 3 — 환경 부채 D1/D2/D3

추정: ~100–200k.

순서:
1. **D1 Gemfile `:windows` + `.ruby-version` 표준화** — 단일 PR
2. **D2 `preferred_purchase_risk` 라벨 의미 충돌** — 단일 PR (TODO 코멘트 해소)
3. **D3 TODOS.md 사건번호 후속 3건** — 단일 PR 묶음. 처리 시 TODOS.md 폐기/통합도 함께.

### 추후 세션 — 사용자 결정 필요 (B 카테고리)

Telegram 추천 후 진행:
- **T1.4(a)** 인근 낙찰가 통계 — 스크래퍼 인프라 영향 큼. 별도 세션 권장 (~200–400k).
- **T2.6** Vitest 도입 의향 — 인프라 결정 (system test 유지 vs 도입). 결정만 받으면 짧음.
- **T4.9 W0-3** SNS self-review 4건 — 스코프 정의 필요.
- **T4.9 W0-5** Branch protection 정책 — GitHub Pro 구독 / public 전환 결정.

### 대기 (외부 조건)

- **T4.9 W0-2** OAuth 콘솔 redirect URI — 운영 도메인 확정 후
- **T4.9 W0-1** CSP enforce 플립 — 1주 csp.violation 로그 확인 후
- **I1** GlitchTip/Sentry — lograge 1주 운영 후
- **I2** self-hosted GH Actions runner — CI/CD 우선순위 결정 후
- **I3** Litestream 백업 — 출시 후 1개월+

## 시작 명령

**기본 권장 — 옵션 A (T1.3 DividendSimulator)**:
> 마스터 TODO 정독 + 필요 시 grep/부분 읽기로 컨텍스트 확보 후, T1.3 소액임차인 최우선변제 (DividendSimulator) 단독으로 위 패턴 그대로 진행. PR 머지 후 Telegram 으로 결과 보고 + 사용자에게 다음 세션 진입 여부 확인 요청. 컨텍스트 50% 초과 시 Telegram 보고 + 잔여 항목을 다음 세션으로 미룰지 사용자 확인.

**다른 옵션 선호 시 (Telegram 추천 후 전환)**:
- 옵션 B (a11y fix) → 빠른 위인 (3 fix 묶음 + 1 color-contrast 단독)
- 세션 3 (환경 부채) → D1+D2+D3 단일 PR 또는 묶음

## 메모리

`~/.claude/projects/-home-tonny-projects-real-estate-auction/memory/`
- `feedback_thorough_qa.md` — 검사 통과 표현 + 충분한 검사 루프
- `feedback_telegram_milestone_pings.md` — 자주 핑
- `feedback_no_launch_schedule.md` — 일정 추적 X, 기능만
- `project_xcom_daily_post_format.md` — X.com 일일 build-in-public 포맷 (별도)

이대로 다음 세션에 붙여 넣으면 자동 진행 모드 (자율 의사결정 + minimum viable + 단일 PR + Telegram milestone ping) 로 진입.
```

---

## 세션 1 마무리 노트 (2026-05-15)

세션 1 (UX 폴리시 + a11y) 5 PR 머지 완료:

| PR | 작업 | 검사 |
|----|-----|------|
| #163 | T4.8 묶음 1: 영문 validation 한국어화 + LegalDisclaimerComponent role="note" + base_right_date GET 컨트롤러 테스트 (#3, #6, #14) | unit 1644/4352 system 85/235 |
| #164 | T4.8 묶음 2: BidOpinionComponent disclaimer 중복 제거 + analyses/history.html.erb tooltip 500자 truncate (#5, #8) | unit 1645/4355 system 86/238 |
| #165 | T4.8 묶음 3: overflow-menu Esc/focus + property/show heading hierarchy + nested-card 회귀 가드 (#7, #11, #12) | unit 1647/4358 system 89/249 |
| #166 | T4.6 axe-core a11y baseline 인프라 — assert_axe_clean 헬퍼 + /auth/login + /properties baseline + 4종 KNOWN_VIOLATIONS 캡처 | unit 1647/4358 system 91/251 |
| #167 | T4.9 W0-4 OAuth Symbol provider 회귀 테스트 가드 | unit 1649/4369 system 91/251 |

발견된 후속:
- a11y 부채 4종 (html-has-lang / select-name / heading-order / color-contrast) — KNOWN_VIOLATIONS 로 캡처, follow-up PR 대상
- BidOpinionComponent dedup 시 LegalDisclaimerComponent compact 만 책임 문구 유지 — 후속 카드에서도 같은 패턴 적용 검토

세션 1 종료 시 Theme 4 9건 100% 완료. 잔여는 외부 게이트 4건 + Theme 1 잔여 2건 + 환경 부채 3건 + 인프라 3건.
