# 초보자 페르소나 E2E 점검 보고서

- **수행 일자**: 2026-05-12
- **대상 URL**: http://localhost:3000
- **페르소나**: 부동산 경매/법률 도메인 지식 없음. 첫 방문 사용자. UX 모호함과 라벨 부재에 민감.
- **세션 종류**: 게스트 세션 (`/onboarding` 1·2·3단계 통과 후)
- **수집 스크린샷**: 34장 (`docs/screenshots/beginner/{before,after,error}/`)

> 모든 라우트는 위 의무 리스트에 따라 직접 방문했고, 가능한 모든 GNB 링크/사이드바/푸터 항목과 폼 검증(빈/0/음수/큰 수/한·영 혼용)을 시도했다.

---

## 라우트별 결과 표

| 라우트 | 상태 | 모호함/문제 | 스크린샷 |
|--------|------|-------------|----------|
| `/` (홈) | AMBIGUOUS | 1) 게스트 세션이 한 번 생기면 `/`로 진입해도 자동 `/properties`로 리다이렉트되어 홈 카피·CTA를 다시 볼 길이 없음. 2) 푸터에 약관·개인정보 링크 부재. | `before/00-home.png` |
| `/onboarding` (Step1 현금) | FAIL | 다음 버튼이 **아이콘만**(텍스트·aria-label 없음). 헤더는 "현금"인데 "관심 지역" select가 함께 노출돼 단계 의미 불명확. 0 입력해도 검증 없이 다음으로 넘어감. | `before/01-onboarding-step1.png`, `error/03-step1-zero-submit.png` |
| `/onboarding` (Step2 예비비) | AMBIGUOUS | "수선비/취득세/법무사비/이사비/미납 관리비" 도움말이 "평균 4.8억 기준"이라는 캡션만 — 초보자는 4.8억이 어디서 온 기준치인지 모름. 이전 화살표 링크 라벨 없음. | `before/04-onboarding-step2.png` |
| `/onboarding` (Step3 대출 설정) | FAIL | 완료 버튼이 **아이콘만**(라벨·aria 없음). 클릭하면 step1 처음으로 되돌아가 모든 요약(최대입찰가 등)이 "—"로 초기화되어 보임. LTV 슬라이더 범위 안내가 `0% / 70% / 90%`인데 같은 데이터를 다루는 `/settings/budget`에서는 `30% / 70% / 100%` — 일관성 깨짐. | `before/05-onboarding-step3.png`, `error/06-completed-but-reset.png` |
| `/onboarding/complete` | AMBIGUOUS | "관리비"가 결과 카드에서 "—"로 표시(step2에서 0 입력값을 비어 있음으로 처리). 두 개의 CTA(`/`, `/settings/budget`)가 **아이콘만** — 어디로 가는지 모름. | `after/07-onboarding-complete.png` |
| `/auth/login` | FAIL | 직접 진입 시 즉시 `/search`로 리다이렉트. 로그인 화면이 사실상 존재하지 않음 (헤더의 "로그인" 링크는 의미 없음). | `before/08-auth-login.png`, `before/09-auth-login-redirected-to-search.png` |
| `/terms` | AMBIGUOUS | 5개 섹션 본문이 전부 **"정식 법무 검토 후 교체 예정"** 플레이스홀더. 실제 약관 부재. 푸터에 진입 경로도 없음. | `before/10-terms.png` |
| `/privacy` | AMBIGUOUS | 7개 섹션 중 6개가 동일 플레이스홀더. 단, 4번(외부 LLM API 제공사)만 실 내용 — 사용자가 "어디까지가 진짜 정보인지" 혼란. | `before/11-privacy.png` |
| `/manual` (직접 URL) | FAIL | 직접 진입 시 `/search`로 리다이렉트되어 H1이 "물건 목록"으로 바뀜. **GNB에서 클릭할 때만** "사용자매뉴얼" 페이지가 정상 렌더링 — 일관성 부재. | `before/12-manual.png`, `before/28-manual-via-gnb.png` |
| `/manual` (GNB 경유) | PASS | 컨텐츠 정상. 단 "분석할 능력을 길러드립니다"라는 카피와 사이드바 CTA "AI 분석"이 충돌(자동분석은 일시중단 상태). | `before/28-manual-via-gnb.png` |
| `/eviction_guide` | AMBIGUOUS | 전체 단계명에 `S1/JT-S1/ST-S1/DO-S1/IO-S1` 같은 약어가 라벨 없이 그대로 노출. JT/ST/DO/IO가 점유자 유형 코드라는 안내 없음. | `before/13-eviction-guide.png` |
| `/eviction_guide/simulator` | AMBIGUOUS | 첫 직접 진입 시 시뮬레이터 카피가 보이다가 약 1초 후 페이지가 자동으로 `/properties`나 `/properties/bulk_import`로 이동(아래 BUG-3 참조). 클릭 흐름으로 들어가야만 안정적. | `before/14-simulator.png`, `before/15-simulator-landing.png`, `before/16-simulator-direct.png` |
| `/eviction_guide/simulator/select_type` | AMBIGUOUS | 점유자 유형 라벨 — "후순위 임차인(배당 수령)", "선순위 임차인(대항력 有)" — 용어 도움말 없음. 난이도만 표기. | `before/17-simulator-select-type.png` |
| `/eviction_guide/simulator/question/DO-Q1` | FAIL | "네" 또는 "아니오" 클릭 시 다음 질문으로 진행되지 않고 `/eviction_guide` 또는 다른 페이지로 이탈. 콘솔/네트워크에 `GET /eviction_guide/simulator/question/INVALID 404` 기록 — **시뮬레이션 분기 로직이 깨짐**. | `before/18-simulator-question1.png`, `error/19-simulator-broken-redirect.png` |
| `/search` | AMBIGUOUS | 페이지가 너무 빈약 — 관심 지역 select 1개와 "조건검색" 버튼만. 결과·도움말·필터 부재. "조건검색" 버튼을 눌러도 같은 화면(결과 없음 안내 없음). | `before/20-search.png`, `after/21-search-result.png` |
| `/properties` | AMBIGUOUS | 사건번호 입력에 `예: 2026타경1234` placeholder는 있지만 형식 안내 없음. 잘못된 입력(`abc-한글-99999999999`) 시 검증 메시지 0개 — **무반응**. | `before/22-properties.png`, `error/23-properties-bad-input-no-feedback.png` |
| `/properties/bulk_import` | AMBIGUOUS | "법원이름,사건번호" 텍스트 입력 — **실제 예시 한 줄도 없음**. 초보자는 어떻게 채우는지 모름. | `before/33-bulk-import.png` |
| `/settings/budget` | AMBIGUOUS / FAIL | 1) 음수 입력 시 검증 메시지 "수선비**은(는)** 0 이상이어야 합니다" — 조사 처리 오류(받침 없는 명사 + "은"). 2) 매우 큰 값(`99999999999`)을 검증 없이 수용. 3) LTV 슬라이더 범위가 onboarding과 다름(30~100% vs 0~90%). 4) 지역 select 변경 시 `PATCH /settings/budget/update_region` **500 Internal Server Error**(BUG-1). | `before/24-settings-budget.png`, `error/25-budget-negative-validation.png`, `error/02-region-500.png` |
| `/analyses/new` | AMBIGUOUS | "AI 자동분석 일시 중단" 배너 + 사용자가 직접 ChatGPT/Claude/Gemini로 가서 결과를 복사·붙여넣어야 하는 4단계 매뉴얼 흐름. 초보자에겐 "JSON"이라는 단어 자체가 진입장벽. | `before/26-analyses-new.png`, `before/27-analyses-paste-tab.png` |
| 다크모드 토글 | PASS | 동작은 함. 단, 토글하면 페이지가 자동으로 `/settings/budget`으로 이동되는 현상 동반(BUG-3와 연관). | `after/29-darkmode-toggled.png` |
| 사이드바 접기 토글 | PASS | 동작은 함. 페이지에 따라 `GET /settings/budget 422` 콘솔 에러 동반. | `after/30-sidebar-collapsed.png` |
| 모바일 뷰(375px) | AMBIGUOUS | 사이드바가 항상 펼쳐져 있어 본문 영역이 좁아짐. 햄버거 메뉴 없음. | `after/31-mobile-properties.png`, `after/32-mobile-manual.png` |

---

## 🤯 초보자 입장에서 헷갈렸던 것 TOP 10

1. **"다음/완료" 버튼이 아이콘 only** — Onboarding step1·step3 그리고 onboarding/complete 페이지의 주요 CTA가 화살표·체크 아이콘만 표시. 텍스트도 aria-label도 없음. 초보자는 "이게 다음 버튼인지, 그냥 장식인지" 헷갈림. 화면리더 사용자에겐 완전 차단. (`before/01-onboarding-step1.png`, `before/05-onboarding-step3.png`, `after/07-onboarding-complete.png`)
2. **단계 헤더와 입력 필드 불일치** — Step1 헤더는 "현금"인데 첫 필드가 "관심 지역" select고 "쓸 수 있는 현금"이 그 아래. 왜 지역이 "현금" 단계에 있나?  (`before/01-onboarding-step1.png`)
3. **LTV 슬라이더 범위가 페이지마다 다름** — Onboarding step3: `0% / 70% / 90%`. Settings/budget: `30% / 70% / 100%`. 같은 값을 다른 단위로 보여줘 같은 사용자가 두 번 보면 혼란. (`before/05-onboarding-step3.png` ↔ `before/24-settings-budget.png`)
4. **시뮬레이터 답변이 다음 단계로 안 감** — "네/아니오" 클릭하면 명도 가이드 또는 임의의 페이지로 튕김. 진행률 0%로 멈춰 있어 "내가 뭘 잘못한 거지?" 느낌. (`error/19-simulator-broken-redirect.png`)
5. **약관/개인정보가 모두 "정식 법무 검토 후 교체 예정"** — 동의해도 되는 건지 판단 불가. 푸터에 진입 링크조차 없어서 우연히 발견함. (`before/10-terms.png`, `before/11-privacy.png`)
6. **로그인 페이지가 없음** — 헤더 "로그인" 버튼 클릭 → `/auth/login`이 즉시 `/search`로 리다이렉트. 가입/로그인 흐름이 존재하지 않는데 GNB는 계속 "로그인"을 권유. (`before/09-auth-login-redirected-to-search.png`)
7. **사건번호 형식 안내 부족** — `/properties`에서 placeholder만 `예: 2026타경1234`. "타경"이 뭔지 모르는 초보자는 어디서 사건번호를 가져와야 하는지 불분명. 잘못된 입력에도 검증 메시지가 없어 "추가 됐는지 안 됐는지" 모름. (`error/23-properties-bad-input-no-feedback.png`)
8. **AI 분석이 사실상 "내가 직접 ChatGPT 가서 복붙해 와"** — "AI 분석" 메뉴를 초보자가 클릭하면 외부 LLM, PDF, 프롬프트, JSON 같은 단어로 가득한 4단계 매뉴얼. "AI"의 기대치(자동)와 실제 흐름(수동) 미스매치. (`before/26-analyses-new.png`)
9. **명도 가이드의 코드명(JT/ST/DO/IO/S1)** — 점유자 유형 약어가 라벨 없이 그대로 노출. JT가 무엇의 약자인지 본문에서 매핑하지 않음. (`before/13-eviction-guide.png`)
10. **검색 페이지가 너무 미니멀** — `/search`에 들어가면 select와 버튼 둘. "조건검색"을 눌러도 결과·로딩·에러 안내가 없음. "여기가 진짜 검색 페이지가 맞나?" 의심. (`before/20-search.png`, `after/21-search-result.png`)

---

## 💥 명백한 버그/오류

| # | 증상 | 라우트/액션 | 증거 |
|---|------|-------------|------|
| BUG-1 | **지역 변경 시 500 Internal Server Error** — `PATCH /settings/budget/update_region`. UI는 변경이 적용된 듯 보이지만 서버 에러로 영구 저장 실패 가능. | Onboarding step1에서 지역 select 변경. | `error/02-region-500.png`, console 로그 `[ERROR] ... 500 ... /settings/budget/update_region` |
| BUG-2 | **시뮬레이터 분기 라우팅 깨짐** — `DO-Q1`에서 "네" 클릭 시 `GET /eviction_guide/simulator/question/INVALID` 404. 다음 노드 식별자가 `"INVALID"` 그대로 전달되는 듯. | `/eviction_guide/simulator` → 채무자 본인 → DO-Q1 → 네. | `error/19-simulator-broken-redirect.png`, network log `GET .../question/INVALID => 404` |
| BUG-3 | **페이지가 자기 멋대로 다른 라우트로 이동** — 사용자가 가만히 있어도 `/`→`/properties`, `/manual`→`/search`, `/analyses/new`→`/terms`, `/eviction_guide/simulator`→`/properties` 등으로 1초 내 자동 이동. Stimulus controller 또는 polling 응답이 redirect를 따라가는 것으로 추정. | 여러 라우트 직접 진입 시. | `before/09-auth-login-redirected-to-search.png`, `before/12-manual.png` |
| BUG-4 | **시드/데이터 부재로 인한 다수 404** — `/properties/1`, `/analyses/1`, `/analyses/1/prompt`, `/analyses/1/manual`, `/analyses/1/history`, `/properties/1/rights_analysis_report`, `/properties/1/inspections`, `/properties/1/inspections/tabs/case_doc`, `/eviction_guide/simulator/current`, `/settings/budget/api_credentials`, `/settings/budget/api_credentials/new`, `/settings/budget/data_sources` 등이 백그라운드로 fetch되며 404. | 게스트 세션에서 발생. ID 1 데이터가 없거나 라우트 미구현. | console errors (위 콘솔 로그 18개 라인) |
| BUG-5 | **조사 처리 오류** — "수선비**은(는)** 0 이상이어야 합니다" — 받침 없는 명사에 "은" 사용. | `/settings/budget` 음수 입력. | `error/25-budget-negative-validation.png` |
| BUG-6 | **Step1 검증 누락** — "쓸 수 있는 현금" = 0 또는 빈 값에도 step2로 진행. | `/onboarding` step1 0 제출. | `error/03-step1-zero-submit.png` |
| BUG-7 | **상한 검증 누락** — `/settings/budget`에서 수선비/취득세 등에 `99999999999` 같은 비현실 큰 수를 검증 없이 수용. | `/settings/budget` 큰 수 제출. | (재현 가능, 422 없이 적용) |
| BUG-8 | **CSS preload 경고** — `tailwind-...css`, `application-...css`가 preload 후 사용되지 않아 매 페이지마다 동일 경고 2건. | 모든 페이지. | console warnings |

---

## ✨ 개선 제안 (작은 카피/도움말 변경으로 즉시 해결 가능)

1. **아이콘 only 버튼에 텍스트 추가** — Onboarding의 다음/완료/이전 버튼에 "다음", "완료", "이전" 텍스트와 `aria-label`을 추가. 1줄 수정으로 접근성과 명확성 동시 개선.
2. **Step1 헤더와 필드 매칭** — "관심 지역"을 step1의 보조 필드가 아니라 헤더("쓸 수 있는 현금 입력")와 일치시키거나, 별도 step(0 또는 sub-step)으로 분리.
3. **LTV 범위 통일** — Onboarding step3과 `/settings/budget`의 슬라이더 min/max를 동일하게(권장: `0~100% (기본 70)` 또는 `30~100`).
4. **결과 없음 안내 추가** — `/search`, `/properties` 빈 상태 카드를 "조건에 맞는 물건이 없어요. 다른 지역을 시도해 보세요" 같은 EmptyState 문구로 채우기. 이미 일부는 있으므로 통일만 하면 됨.
5. **사건번호 예시 옆에 외부 링크** — placeholder `예: 2026타경1234` 옆에 "(법원경매 사이트에서 확인)" 작은 링크. 이미 본문에 있는 안내를 입력 옆으로 옮기면 됨.
6. **시뮬레이터 점유자 유형 옆에 한 줄 도움말** — "후순위 임차인(배당 수령) = 보증금을 배당으로 받는 임차인" 정도의 1줄 추가.
7. **명도 가이드 코드명 옆 풀네임** — `JT-S1` → `JT(후순위 임차인)-S1` 또는 섹션 헤더에 매핑 표 1개.
8. **약관/개인정보 플레이스홀더 명시** — "정식 법무 검토 후 교체 예정"을 그대로 두지 말고, "🚧 베타 단계 — 정식 약관 준비 중" 배너 1개로 묶어 사용자에게 메타정보 전달.
9. **푸터에 약관·개인정보 링크** — `<footer>`에 `/terms`, `/privacy` 링크 2개 추가. 5분 작업.
10. **AI 분석 페이지 첫 화면에 모드 선택** — "자동 분석은 일시 중단되었어요. 직접 입력 모드로 진행할까요? (예/아니오)" 같은 게이트 카드로 흐름 진입 명확화.
11. **조사 처리** — Rails I18n에 한국어 조사 처리(이/가, 은/는) 헬퍼 도입 또는 메시지를 "수선비는 0 이상이어야 합니다"로 하드코딩.
12. **로그인 메뉴 정리** — 가입/로그인 기능이 아직 없다면 헤더의 "로그인" 링크를 숨기거나 "로그인 (준비 중)"으로 표시.

---

## 한 줄 요약

total **22 라우트/플로우** / passed **3** / ambiguous **13** / failed **6** — 콘솔 에러 19건, 명백한 버그 8건, 초보자 모호함 10건 + 라우트별 다수 발견. 가장 시급한 것은 **자동 라우팅 이탈(BUG-3)** 과 **시뮬레이터 분기 로직 깨짐(BUG-2)**, **지역 변경 500(BUG-1)**.
