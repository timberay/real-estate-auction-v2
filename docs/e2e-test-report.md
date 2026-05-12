# E2E 전수검사 종합 보고서

- **일시**: 2026-05-12
- **대상**: http://localhost:3000 (Rails 부동산 경매 앱, Turbo + Stimulus)
- **방법**: Playwright MCP, 두 페르소나 병렬 실행 (초보자 / 도메인 베테랑), 코드 변경 없음
- **개별 보고서**: [초보자](./e2e-test-report.beginner.md) · [전문가](./e2e-test-report.expert.md)
- **스크린샷**: `docs/screenshots/{beginner,expert}/{before,after,error}/` (47장)

---

## 한눈에 요약

| 구분 | 초보자 | 전문가 | 합계 |
|---|---|---|---|
| 라우트/플로우 점검 | 22 | 19 | 41 점검 |
| PASS | 3 | 9 | — |
| AMBIGUOUS / SUSPECT | 13 | 8 | — |
| FAIL | 6 | 0 | — |
| 명백한 버그 | 8 | 5 | — |
| 도메인 의심 | — | 6 | — |

**가장 시급한 3건** (양 페르소나 모두 또는 영향이 큼):
1. ✅ `PATCH /settings/budget/update_region` **500 Internal Server Error** (지역 변경 ajax) — **FIXED**
2. **취득세가 입찰가에 연동되지 않음** — "평균 4.8억 × 1.1% = 528만원" 고정. 실제 사용자 최대입찰가 6,540만원에는 명백히 과대. 핵심 산식 결함 *(C-4, 별도 디자인 세션 권장)*
3. ✅ **시뮬레이터 분기 라우팅 깨짐** — `DO-Q1` "네" 클릭 시 `INVALID` 전송 의심. 조사 결과 병렬 E2E 에이전트의 탭 cross-contamination에 의한 false positive. 회귀 테스트로 잠금

**Critical 후속 작업 결과** (2026-05-12): C-1·C-2·C-3 처리 완료. C-2·C-3은 두 페르소나 에이전트가 같은 Playwright 브라우저 컨텍스트를 공유한 탓에 발생한 관찰 오류로 확정 — 코드 수정 없이 회귀 테스트만 추가. 향후 병렬 E2E를 돌릴 때는 별도 browser context 또는 순차 실행 권장.

---

## A. Critical 버그 (즉시 수정)

| # | 증상 | 위치 | 발견 | 상태 |
|---|---|---|---|---|
| C-1 | `PATCH /settings/budget/update_region` **500** | onboarding 지역 select 변경 | 초/전 공통 | ✅ **FIXED** (`bfa1a82`) — `current_user.budget_setting` nil 시 `build_budget_setting`으로 lazy 생성 + 회귀 테스트 |
| C-2 | 시뮬레이터 다음 노드 식별자 `"INVALID"` 전송 → 404 | `/eviction_guide/simulator/question/DO-Q1` "네" 클릭 | 초보자 | ✅ **FALSE POSITIVE** (`822394d`) — 두 에이전트가 같은 Playwright 컨텍스트 공유 → 전문가 에이전트가 의도적으로 친 `/question/INVALID` 요청이 초보자 네트워크 로그에 섞임. DB의 DO-Q1은 정확히 `yes_next_code: "DO-Q2"`. DO-Q1→DO-Q2 분기를 잠그는 E2E 테스트 + fixtures 추가 |
| C-3 | 페이지가 자기 멋대로 다른 라우트로 자동 이동 (`/manual`→`/search`, `/analyses/new`→`/terms`, `/eviction_guide/simulator`→`/properties` 등) | 다수 직접 진입 경로 | 초보자 | ✅ **FALSE POSITIVE** — 게스트 세션 curl 재현 결과 세 라우트 모두 200 정상 응답. 기존 컨트롤러 테스트(`manuals_controller_test.rb`, `analyses_controller_test.rb:12`, `eviction_guide_controller_test.rb:28`)가 이미 redirect 없이 200을 잠그고 있음. 병렬 에이전트 탭 격리 실패로 인한 관찰 오류. (`/` → `/properties`/`/onboarding`은 HomeController의 의도된 라우팅) |
| C-4 | 취득세 산식이 평균가 4.8억 기준 고정, 입찰가 연동 안 됨 (1,000만원 매물에서도 528만원으로 잡혀 입찰 불가하게 만듦) | `/onboarding` step2, `/settings/budget` | 전문가 | `expert/before/02-onboarding-step2.png`, `expert/before/10-settings-budget.png` |
| C-5 | ST-Q2 법률 근거 부정확 — "주임법 제3조의5"(임차권등기명령)는 매수인 인수 협상 근거가 아님. 제3조 제4항(대항력) 또는 제3조의2(우선변제권)가 맞음 | `/eviction_guide/simulator/question/ST-Q2` | 전문가 | 보고서 인용 |
| C-6 | `/settings/budget` GET 시 **422** 응답이 콘솔에 노출 (Turbo Stream 응답 처리 추정) | `/settings/budget` 단순 진입 | 초/전 공통 | `expert/error/13-settings-budget-422-on-load.png` |
| C-7 | LTV 200% 등 범위 초과 입력이 **silent ignore** (200 OK, 기본값 유지, 에러 메시지 없음) | `/settings/budget` 폼 | 전문가 | 보고서 인용 |
| C-8 | onboarding step1 "쓸 수 있는 현금" 0/빈 값 검증 누락 → step2 진행됨 | `/onboarding` step1 | 초보자 | `beginner/error/03-step1-zero-submit.png` |

## B. 도메인 정확성 의심 (다음 스프린트)

1. **이사비 기본 50만원** — 2026년 소형 이사 80~150만원이 현실. 60~120만원 또는 직접 입력 유도. (`expert/before/02-onboarding-step2.png`)
2. **행정구역 옵션 중복** — "강원도" + "강원특별자치도", "전라북도" + "전북특별자치도" 동시 노출. 시드 정리 필요. (`expert/before/01-onboarding-step1.png`)
3. **관심 지역 기본값 "제주특별자치도"** — 부동산 경매 도구로는 수도권 우선이 자연스러움. (3개 페이지 모두)
4. **법원 콤보박스 상단 "제주지방법원"** — 나머지는 가나다 정렬인데 첫 행만 어긋남. (`expert/before/05-properties-empty.png`)
5. **약관/개인정보처리방침 5+6개 절이 "정식 법무 검토 후 교체 예정" 자리표시자** — 베타 단계임을 단일 배너로 명시하고 푸터에 진입 링크 추가
6. **AI 분석 페이지가 "자동" 기대치 vs 실제 수동(외부 LLM 복붙) 워크플로 미스매치** — 첫 화면에 모드 게이트 카드 권장

## C. UX 모호함 (작은 카피/도움말로 즉시 해결)

1. Onboarding step1/step3 및 complete 페이지 **CTA가 아이콘만** (`다음`/`완료`/`이전`). 텍스트 + `aria-label` 추가 — 접근성과 명확성 동시 개선
2. **LTV 범위 불일치** — onboarding step3 `0~90%` vs `/settings/budget` `30~100%`. 단일 범위로 통일
3. **사건번호 형식 안내 부족** — placeholder `예: 2026타경1234` 옆에 "법원경매 사이트에서 확인" 외부 링크 1개로 해결
4. **명도 가이드 코드명(JT/ST/DO/IO, S1)** — 풀네임 또는 매핑 표 노출
5. **시뮬레이터 점유자 유형** — 후순위/선순위 임차인 1줄 도움말
6. **검색/매물 빈 상태** — EmptyState 문구 일관화 (`결과 없음 안내 추가`)
7. **bulk_import 빈 입력 200 OK** — "입력이 비어 있습니다" 1줄 메시지
8. **검증 메시지 조사 처리** — "수선비**은(는)** 0 이상..." 받침 없는 명사에 "은" 사용. I18n 헬퍼 또는 하드코딩으로 정리
9. **헤더 "로그인" 버튼** — 실제 로그인 흐름 부재 시 숨김 또는 "준비 중" 표시
10. **모바일 뷰(375px)** — 햄버거 메뉴 부재, 사이드바 항상 펼침으로 본문 좁아짐

## D. 데이터/시드 신뢰성

- **시드 매물 0건** — `/properties/1`, `/analyses/1/...`, `/properties/1/rights_analysis_report`, `/properties/1/inspections/...` 모두 404. 권리분석/임장 점검/등급 등 핵심 도메인 플로우는 **이번 회차에서 검증 불가**. 최근 commit `1e10969 feat(seed-check)`가 정확히 이 공백을 경고하기 위해 추가된 것으로 보임 — dev 시드 단계 보강 필요
- **CSS preload 경고** — `tailwind-*.css`, `application-*.css`가 preload 후 미사용 → 매 페이지마다 2건 경고

## E. PASS — 정상 작동 확인

- 매각허가결정 즉시항고 1주, 대금지급기한 30일 ✓
- 인도명령 + 점유이전금지가처분 동시 신청(잔금 납부일) ✓
- 명도소송 1심 6~12개월 / 강제집행 1~3개월 ✓
- 주임법 제3조 대항력 (인도 + 전입신고) ✓
- 민사집행법 제136조 본문/단서 ✓
- 4가지 점유자 유형 분기 (시뮬레이터 ↔ 명도 가이드 1:1 매칭) ✓
- 최대입찰가 산식 `(현금 − 예비비) / (1 − LTV)` ✓
- 시뮬레이터 잘못된 question code 직접 진입 시 친절한 404 처리 ("해당 질문을 찾을 수 없습니다") ✓
- 사건번호 형식 422 검증 메시지 ✓
- 매물 비교(`/properties/compare`) 2건 미만 안내 후 redirect ✓
- 다크모드 / 사이드바 접기 토글 동작 ✓ (단, BUG-C3 라우팅 이탈 동반 케이스 있음)

---

## 권장 다음 단계

1. **C-1 ~ C-3 즉시 픽스** (라우팅·서버 에러는 사용자에게 즉시 보이는 결함) — 별도 디버깅 세션
2. **C-4 산식 재설계** — 입찰가에 연동된 취득세 계산기 (1세대 무주택 누진, 다주택자 가중 분기). 영향 범위: onboarding step2, `/settings/budget`, 최대입찰가/예비비 카드 전체
3. **시드 보강 PR** — 권리분석/임장/분석 영역 검증을 위해 demo 매물 N건 시드. 후속 E2E 회차에서 깊이 점검 가능
4. **C 섹션(UX 카피/aria-label/EmptyState) 모아 하나의 "코드 청결" PR** — 변경 라인은 작지만 사용자 인지비용은 크게 떨어짐

> 본 보고서는 두 페르소나의 독립 관찰을 합친 것이며, 시드 부재로 점검하지 못한 깊은 도메인 플로우(권리분석 리포트, 임장 점검 탭, 분석 상세)는 시드 보강 후 별도 회차가 필요합니다.
