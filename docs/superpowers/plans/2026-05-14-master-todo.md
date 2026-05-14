# 마스터 TODO — Theme 기반 (2026-05-14 진실 소스)

**작성일**: 2026-05-14
**역할**: 앞으로 진행할 모든 작업을 4개 흐름(Theme 1~4)으로 묶은 단일 진실 소스.
**선행 문서들과의 관계**:
- 본 문서가 **진실 소스**.
- 기존 3개 문서는 *원본 컨텍스트/실행 프롬프트 reference* 로만 사용.
  - `2026-05-10-post-launch-roadmap.md` — Wave 분류 + 실행 프롬프트 원본
  - `2026-05-10-ux-audit-remaining-backlog.md` — PR #107~#125 follow-up 22건 원문
  - `2026-05-12-existing-feature-debt.md` — 코드베이스 부채 감사
- `TODOS.md` — 본 문서를 가리키는 스텁.

> 일정/Wave 분류는 의도적으로 제거. 진행 순서는 흐름(Theme) 우선순위로 결정.

---

## 흐름(Theme) 한눈에

| Theme | 핵심 질문 | 상태 |
|-------|----------|------|
| **1. 계산 엔진 신뢰성** | "숫자가 진짜 맞나?" — 베테랑 retention | T1.1·T1.2·T1.4(b)·T1.5 완료, T1.3·T1.4(a) 대기 |
| **2. 운영 가시성 + 안전망** | "깨지면 보이고, 사용자 작업이 보호되나?" | T2.1·T2.3 완료, 잔여 6건 |
| **3. 권리분석/매물 다양성 확장** | "다룰 수 있는 매물 범위는 어디까지?" | 대기 |
| **4. UX 폴리시 + 외부 정리** | "이미 되는 걸 매끄럽게" | 대기 |

권장 진행 순서: **Theme 1 → Theme 2 → Theme 3 → Theme 4**.
같은 흐름 내 항목은 의존성/임팩트 순으로 진행.

---

## Theme 1 — 계산 엔진 신뢰성

베테랑이 보고 1초 만에 "이 도구 못 믿어" 라고 하지 않게 만들기. 매트릭스 정밀화 + 권리분석 정확도.

| ID | 항목 | 상태 | 원본 ref |
|----|------|------|---------|
| T1.1 | 취득세 매트릭스 (입찰가 연동 bracket iteration + admin UI + audit log) | ✅ 완료 (#131~#138) | C-4 plan, F-A~F-D |
| T1.2 | 양도세 매트릭스 (서버 매트릭스 + Stimulus 주입, 한시 유예 반영) | ✅ 완료 (#140) | W1-3 / C23 / E-25 |
| T1.3 | 소액임차인 최우선변제 자동 계산 (DividendSimulator) | 대기 | W1-4 / C25 / E-27 |
| T1.4(b) | 차회 매각가 자동 계산 (8할 저감 산식 표시) | ✅ 완료 (#141) | W2-1 / C22 / E-24 |
| T1.4(a) | 인근 낙찰가 통계 + 경쟁률 (스크래퍼 + AuctionResult 모델) | 대기 | W2-1 / C22 / E-24 |
| T1.5 | DSR 한도 초과 경고 (BudgetSetting + DsrCalculator + profit calc 배너) | ✅ 완료 (#142) | W2-2 / C26 / E-29 |

**T1.2 출하 시점 후속 (별도 PR로 분리)**:
- T1.2-F-A 양도세 admin UI (취득세 F-D 패턴)
- T1.2-F-B 1주택자 9억 초과 누진 정밀 모드 + 12억 비과세 거주요건 분기 (취득세 F-C 패턴)
- T1.2-F-C 양도세율 변경 audit log (취득세 F-D-3 패턴)
- T1.2-F-D property_type 별 매트릭스 (오피스텔/상가/토지) → Theme 3 T3.1 에서 흡수

---

## Theme 2 — 운영 가시성 + 안전망

운영 시 무엇이 깨지는지 보이고, 깨져도 사용자 작업이 손실되지 않게.

| ID | 항목 | 원본 ref |
|----|------|---------|
| T2.1 | lograge 구조화 로깅 (1요청 1JSON, production+test 활성, custom payload: request_id/user_id/guest/exception) | ✅ 완료 (#144) — W1-1 |
| T2.2 | AI 재분석 silent overwrite 방지 (`user_edited` 보존) | W1-2 / Follow-up #13 |
| T2.3 | 컨트롤러 bang-method rescue systemic fix (ApplicationController `rescue_from ActiveRecord::RecordInvalid` — HTML→redirect_back+flash, JSON→422+errors) | ✅ 완료 (#143) — A1 |
| T2.4 | LLM truncation 감지 통일 — Gemini/Ollama 우선 + 공통 `LlmTruncationError` | A2 / Follow-up #2 |
| T2.5 | PDF/LLM rescue 분기 (retryable vs fatal) | A4 |
| T2.6 | Stimulus JS 테스트 인프라 (Vitest 도입 또는 system test 보강) | A3 |
| T2.7 | InspectionResultVersion 동시성 + N+1 | Follow-up #9, #10 |
| T2.8 | B27/B10 controller 견고화 (T2.3 systemic fix 후 잔여) | Follow-up #15, #16, #17, #18, #19 |

권장 순서: **T2.3 (systemic fix) → T2.1 (lograge) → T2.2 → T2.4 → T2.5 → T2.6 → T2.7 → T2.8**.

---

## Theme 3 — 권리분석/매물 다양성 확장

아파트 외 케이스(오피스텔/상가/토지/공유지분) + 알림 + 데드라인 추적.

| ID | 항목 | 원본 ref |
|----|------|---------|
| T3.1 | property_type 분기 (주거/업무/상가/토지) | W2-4 / C27 / E-31 |
| T3.2 | 공유지분 매물 보증금 비율 적용 | W2-5 / C28 / E-32 |
| T3.3 | 인도명령 6개월 D-day 추적 | W2-6 / C29 / E-33 |
| T3.4 | Notification 채널 (이메일 + in-app) | W2-7 / C30 / E-34 |
| T3.5 | B9 비교 보드 확장 (CSV / 예상순이익 / sortable / sessionStorage 영속 시스템 테스트) | Follow-up #20, #21, #22, #23 |
| T3.6 | B11 50건 sync 25s → background job | Follow-up #24 |

T3.4 Notification 인프라가 T3.3 D-day 알림 의존. 따라서 **T3.4 → T3.3** 순서.

---

## Theme 4 — UX 폴리시 + 외부 정리

이미 작동하는 부분의 디테일 + 외부 게이트(OAuth/CSP/도메인) 마무리.

| ID | 항목 | 원본 ref |
|----|------|---------|
| T4.1 | 모바일 정렬 묶음 6건 — 한 PR | W3-1: C1, C2, C3, C7, C13, C17 |
| T4.2 | 내부 코드 노출 제거 묶음 3건 — 한 PR | W3-2: C4, C5, C20 |
| T4.3 | 인지 흐름 정리 묶음 5건 — 한 PR | W3-3: C6, C9, C10, C15, C18 |
| T4.4 | 안내/가이드 묶음 4건 — 한 PR | W3-4: C8, C14, C16, C19 |
| T4.5 | 빈 상태/진행 표시 묶음 2건 — 한 PR | W3-5: C11, C12 |
| T4.6 | a11y 점검 패스 (axe-core 통합) | W4-1 / C34 |
| T4.7 | `analyses#prompt` 인증/rate-limit | W4-2 / C31 / E-39 |
| T4.8 | Backlog P3 묶음 (한국어화 / disclaimer / menu Esc / tooltip / heading / nested cards / base_right_date 컨트롤러 테스트) | Follow-up #3, #5, #6, #7, #8, #11, #12, #14 |
| T4.9 | 외부 게이트 5건 — CSP enforce 플립, OAuth 콘솔 redirect URI, SNS self-review (multi-tab/account settings/rack-attack/terms·privacy), OAuth Symbol provider 회귀 테스트, branch protection 정책 결정 | W0-1~5 |

---

## 코드 부채 잔여 (Theme 외 — 환경/도구)

| ID | 항목 | 원본 ref |
|----|------|---------|
| D1 | `Gemfile` `:windows` 플랫폼 심볼 + `.ruby-version` 표준화 | C3 (debt) |
| D2 | `preferred_purchase_risk` 라벨 의미 충돌 (TODO 코멘트 기 표시) | C1 (debt) |
| D3 | TODOS.md 사건번호 후속 3건: 60-법원 auto-discovery / `Property#refresh_from_court_auction!` / CaseSearchService race-rescue 테스트 | C2 (debt) |
| I1 | GlitchTip 또는 Sentry 검토 (lograge 1주 운영 후) | I-1 |
| I2 | self-hosted GitHub Actions runner | I-2 |
| I3 | Litestream 외부 백업 검토 | I-3 |

---

## 작성 규칙

새 항목 추가 시:
1. Theme 1~4 중 분류 (없으면 D/I)
2. 한 줄 설명 + 원본 ref(있으면)
3. 의존성 명시 (다른 Theme 항목 또는 외부 데이터)

완료 시: 상태를 ✅ + PR 번호로 표시. 구체 실행 프롬프트는 원본 ref 문서에서 그대로 복사.

---

## 진행 순서 의사결정 가이드

다음 항목을 고를 때 묻는 질문:
1. **현재 활성 흐름 안에 미완 항목이 남았는가?** → 그 흐름을 끝낸 뒤 다음 흐름으로
2. **블로커가 있는가?** (예: T3.3 D-day 알림은 T3.4 Notification 인프라 의존) → 의존 항목 먼저
3. **외부 결정 대기 중인가?** (T4.9 OAuth 콘솔 등) → 백그라운드, 다른 항목과 병행

—
**End of master TODO.**
