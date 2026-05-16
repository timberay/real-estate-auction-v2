# E2E 초보자 페르소나 — 수정 필요 항목 (Findings Report)

> **🚫 STATUS: CLOSED — WON'T FIX (2026-05-16 결정)**
>
> - P0 4건 (B-002 / B-003 / B-005 / B-008) 은 PR #181 에서 처리 완료.
> - **잔여 P1+ 항목 (B-001, B-004, B-006~B-007, B-009~B-011, U-001~U-013, C-001) 은 작업하지 않기로 결정.** 활성 작업 목록에서 제외.
> - 결정 기록: [`docs/decisions/2026-05-16-2026-05-15-qa-rounds-wontfix.md`](decisions/2026-05-16-2026-05-15-qa-rounds-wontfix.md)
> - 본 문서는 이력 보존용 — 향후 같은 항목을 재발견하면 그때 다시 분류.

- **테스트 일시**: 2026-05-15
- **테스터 페르소나**: 처음 부동산 경매를 알아보는 일반인 (도메인 지식·앱 사용 경험 모두 없음)
- **테스트 대상**: `http://localhost:3000` (Rails dev server)
- **스코프**: **신규 기능 제안 제외.** 변경/수정해야 할 **기존 항목**만 — 기능 오류 + 사용 모호성
- **실행 도구**: Playwright MCP (browser_snapshot + browser_click + screenshots)
- **세션 상태**: 익명(비로그인)에서 접근 가능한 모든 경로

> ⚠️ **테스트 범위 한계 (Follow-up 필요)**
> dev 환경에 OAuth(Google/Kakao/Naver) 자격증명이 설정되지 않아 **실제 로그인 후 흐름**(온보딩 step2~3, 물건 추가 후 inspection 탭, source-doc review, 권리분석 리포트, 알림 mark_read, 즐겨찾기, 설정의 API credential 등)은 본 보고서에서 **확인하지 못함**. 별도 작업으로 dev 인증 우회 마련 후 2차 테스트 권장.

---

## ID 규칙

| Prefix | 의미 | 예 |
|---|---|---|
| `B-###` | Bug — 기능 오류 | 검증 실패, 피드백 부재, 500 에러 |
| `U-###` | Usability — 사용 모호성 | 라벨 불일치, 상태 표시 누락, 문맥 부재 |
| `C-###` | Copy — 문구/번역 | 영어 노출, 디버그 텍스트 |

**Severity**

| | 의미 |
|---|---|
| **P0** | 차단/에러/데이터 노출 — 즉시 |
| **P1** | 혼동·실수 유발 — 다음 스프린트 |
| **P2** | 개선 — 백로그 |

---

## Summary (검출 26건)

| ID | Sev | Title | Page |
|----|-----|-------|------|
| [B-001](#b-001) | P1 | 빈 입력 검증 메시지가 영어 | `/properties` |
| [B-002](#b-002) | P0 | "추가" 클릭 후 성공/실패 피드백 0, 입력값 소실 | `/properties` |
| [B-003](#b-003) | P0 | 조건검색 200 OK인데 결과 영역 미출력 | `/search` |
| [B-004](#b-004) | P1 | "프롬프트 복사" 버튼 클릭 후 토스트 없음 | `/analyses/new` |
| [B-005](#b-005) | P0 | 익명에 QA 디버그 알림 노출 + 헤더/페이지 카운트 불일치 | `/notifications` |
| [B-006](#b-006) | P1 | CSV 파일 입력 컨트롤이 브라우저 기본 영어 | `/properties/bulk_import` |
| [B-007](#b-007) | P1 | 벌크 임포트 빈 submit: 네트워크 요청 0, 피드백 0 | `/properties/bulk_import` |
| [B-008](#b-008) | **P0** | `/properties/:id` 익명 접근 시 ActiveRecord 500 (인증 검사 부재) | `/properties/1` |
| [B-009](#b-009) | P1 | 보호된 페이지 접근 시 무음 redirect (`/analyses/history` → `/properties`) | `/analyses/history` |
| [B-010](#b-010) | P1 | `/admin/*` 익명 접근 시 RoutingError 노출 (401/403 일관성 부재) | `/admin/*` |
| [B-011](#b-011) | P1 | "조건검색" 폼이 GET이 아닌 POST `/search_results` — URL 공유/북마크 불가 | `/search` |
| [U-001](#u-001) | P1 | 사이드바 "물건 찾기" ↔ 페이지 제목 "물건 목록" 라벨 불일치 | `/search` |
| [U-002](#u-002) | P2 | 시뮬레이터 첫 질문에 "진행률 0%" — 분수 표시가 더 직관적 | `/eviction_guide/simulator/...` |
| [U-003](#u-003) | P1 | "AI 자동분석 [일시 중단]" 탭 disabled — 안내·시각 강조 부재 | `/analyses/new` |
| [U-004](#u-004) | P2 | 사이드바 "AI 분석" ↔ 페이지 제목 "AI 수동분석" 라벨 불일치 | `/analyses/new` |
| [U-005](#u-005) | P2 | 매뉴얼 워크북 5단계만 상태 라벨(완료/미시작) 누락 | `/manual` |
| [U-006](#u-006) | P1 | 익명 `/` → `/properties` "내 물건" 직행 — 정체성 혼란 | `/` |
| [U-007](#u-007) | P1 | 예산 페이지 디폴트값 자동 채움 + "최대입찰가 8,006만원" — 근거 안내 부재 | `/settings/budget` |
| [U-008](#u-008) | P2 | 예산 페이지 도메인 용어(DSR/LTV/누진식) — 초보자 친절도 ↓ | `/settings/budget` |
| [U-009](#u-009) | P1 | 명도 가이드 30+ 단계 평면 리스트 — 자기 케이스 식별 어려움 | `/eviction_guide` |
| [U-010](#u-010) | P1 | 명도 단계 prefix(S/JT-S/ST-S/DO-S/IO-S)에 그룹 헤더 없음 | `/eviction_guide` |
| [U-011](#u-011) | P2 | 시뮬레이터 점유자 유형 4가지 — "모르겠음" 옵션 없음 | `/eviction_guide/simulator/select_type` |
| [U-012](#u-012) | P2 | AI 수동분석 4단계 — 진행 게이지 없음 | `/analyses/new` |
| [U-013](#u-013) | P2 | 명도 시뮬레이터 "직접 입력으로 진행 중" 라벨 — 클릭 가능한지 모호 | `/eviction_guide/simulator/...` |
| [C-001](#c-001) | P1 | 알림 항목 본문 "QA 테스트 알림 / 실 브라우저 검증용 알림" 그대로 노출 | `/notifications` |
| [C-002](#c-002) | P2 | 사건번호 placeholder "예: 2026타경1234" — 빈 폼 검증 trigger 시 잔존 | `/properties` |

---

## Details

### B-001
**제목**: 빈 입력으로 "추가" 클릭 시 검증 메시지가 영어 ("Please fill out this field.")
**페이지**: `/properties` — 사건번호 추가 폼
**Severity**: P1
**증거**: `docs/screenshots/explore/02-empty-add-click.png`
**초보자 반응**: "한국어 앱인데 갑자기 영어로 뜨네 — 깨진 건가?"
**원인 추정**: HTML5 `required` 속성의 브라우저 기본 메시지 사용. `setCustomValidity()` 또는 서버측 flash 미적용.
**제안 변경**: 입력칸에 `oninvalid="this.setCustomValidity('사건번호를 입력해주세요.')"` 또는 한국어 placeholder + 클라이언트 검증 메시지 로컬라이즈.

---

### B-002
**제목**: 사건번호 추가 후 성공/실패 안내 없음, 입력값 소실
**페이지**: `/properties`
**Severity**: P0
**증거**: `docs/screenshots/explore/03-bad-case-no.png`, network log: `POST /properties 302 → GET /properties 200`
**재현**: "abc123" 입력 → "추가" 클릭 → 같은 페이지로 돌아오는데 flash 없음, 입력칸은 비워짐
**초보자 반응**: "내가 누른 거 맞나? 잘못된 형식인지, 추가됐는지, 로그인 필요한 건지 알 수 없음"
**원인 추정**: PropertiesController#create 가 invalid input/anonymous user 케이스에서 flash 메시지 없이 redirect.
**제안 변경**:
1. flash[:alert] = "사건번호 형식이 올바르지 않습니다. (예: 2026타경1234)" 추가
2. 익명 사용자라면 flash[:notice] = "로그인 후 사용 가능합니다" + /auth/login 으로 redirect
3. 실패 시 입력값 보존 (`@case_number = params[:case_number]`)

---

### B-003
**제목**: 조건검색 폼 submit이 200 OK이지만 결과 영역 미렌더링
**페이지**: `/search` → POST `/search_results`
**Severity**: P0
**증거**: `docs/screenshots/explore/07-search-results.png` — 클릭 전/후 화면 완전 동일
**재현**: `/search` → "조건검색" 클릭 → `POST /search_results 200` 응답하나 본문에 결과 영역 자체가 없음
**초보자 반응**: "이거 검색되는 기능 맞나? 0건이면 0건이라도 표시되어야지"
**원인 추정**: SearchResultsController#create 의 응답이 redirect_back인데 /search 페이지에 turbo-frame 또는 결과 partial가 없음. 익명 사용자 케이스 미처리.
**제안 변경**:
1. /search 페이지에 결과 출력 영역(turbo-frame 또는 컨테이너) 추가
2. 결과 0건일 경우 "조건에 맞는 물건이 없습니다" 명시
3. 익명일 경우 "로그인 후 결과를 저장할 수 있습니다" 안내

---

### B-004
**제목**: "프롬프트 복사" 버튼 클릭 후 토스트/시각 피드백 없음
**페이지**: `/analyses/new` — 1단계 프롬프트 복사
**Severity**: P1
**증거**: `docs/screenshots/explore/13-prompt-copy.png` — 클릭 전/후 화면 동일
**초보자 반응**: "버튼 눌렀는데 아무 일도 안 일어남. 클립보드에 실제로 들어갔는지 확신 못함"
**원인 추정**: Stimulus controller에 `navigator.clipboard.writeText()` 만 호출, "복사됨" 토스트 미구현.
**제안 변경**: 클릭 후 버튼 라벨을 "복사됨 ✓" 으로 2초간 변경하거나, 토스트 컴포넌트 호출.

---

### B-005
**제목**: 익명 사용자에게 "QA 테스트 알림 / 실 브라우저 검증용 알림" 노출 + 헤더 카운트(0건)와 페이지 실제 건수(1건) 불일치
**페이지**: `/notifications` (헤더 전역)
**Severity**: P0
**증거**: `docs/screenshots/explore/15-notifications.png` — 헤더 "알림 0건" + 본문 1건
**문제**:
1. 디버그용/QA용 데이터가 프로덕션 빌드에도 살아있음
2. 헤더 알림 배지 카운트 로직과 페이지 컨트롤러 쿼리가 다름
**제안 변경**:
1. `Notification.where(title: "QA 테스트 알림")` seed 또는 dev 전용 fixture 분리 — production 자동 제거
2. 헤더 배지 카운트와 페이지 index를 동일 scope(`unread_for(user)`)로 통일

---

### B-006
**제목**: CSV 파일 업로드 컨트롤이 브라우저 기본 영어("Choose File / No file chosen")
**페이지**: `/properties/bulk_import`
**Severity**: P1
**증거**: `docs/screenshots/explore/19-bulk-import.png`
**제안 변경**: `<input type="file">` 를 hidden 처리하고 커스텀 한글 라벨("파일 선택 / 선택된 파일 없음") + Stimulus 컨트롤러로 표시.

---

### B-007
**제목**: 벌크 임포트 빈 textarea + 빈 file → "한 번에 추가하기" 클릭 시 네트워크 요청 0, 피드백 0
**페이지**: `/properties/bulk_import`
**Severity**: P1
**증거**: `docs/screenshots/explore/20-bulk-empty-submit.png`
**원인 추정**: 클라이언트 검증이 submit 자체를 막지만 시각 피드백이 전혀 없음.
**제안 변경**: 두 필드 모두 비어 있으면 빨간 보더 + "최소 한 개의 사건번호 또는 CSV 파일을 입력해주세요." 메시지.

---

### B-008
**제목**: `/properties/1` 익명 접근 시 `ActiveRecord::RecordNotFound` 발생 (`Couldn't find UserProperty with [WHERE "user_properties"."user_id" = ? AND "user_properties"."property_id" = ?]`)
**페이지**: `/properties/:id`
**Severity**: **P0**
**증거**: `docs/screenshots/explore/22-property-1-error.png`
**원인**: `PropertiesController#set_user_property`(line 12)에서 `current_user.user_properties.find_by!(...)` 호출. 익명 사용자 케이스 보호 부재.
**제안 변경**:
1. 컨트롤러 상단 `before_action :authenticate_user!`(또는 그에 상응) 추가
2. 또는 `find_by!` → `find_by` + nil 검사 후 404 응답

---

### B-009
**제목**: 보호된 페이지 접근 시 안내 없이 redirect (`/analyses/history` → `/properties`)
**페이지**: 다수 (history, settings 등 추정)
**Severity**: P1
**증거**: `docs/screenshots/explore/26-history-redirect.png` — flash 없음
**제안 변경**: redirect 시 `flash[:notice] = "로그인 후 분석 이력을 볼 수 있어요."` + `/auth/login` 이동 (정책: 보호된 페이지 → 로그인 페이지 + 원래 URL을 stored_location 으로 보존).

---

### B-010
**제목**: `/admin/*` 익명 접근 시 `Routing Error / Not Found` 노출 (require_admin)
**페이지**: `/admin/acquisition_tax_rates` 등
**Severity**: P1
**증거**: `docs/screenshots/explore/25-admin-anon-error.png`
**원인**: `Admin::BaseController#require_admin`(line 13) — `raise ActionController::RoutingError, "Not Found"` 패턴. 라우트가 아닌 인증 실패인데 404로 위장.
**제안 변경**: 익명이면 `/auth/login` 으로 redirect, 일반 사용자(non-admin) 이면 `head :forbidden` 또는 안전한 404 페이지 렌더. dev/prod 일관 동작.

---

### B-011
**제목**: 검색 폼이 POST `/search_results` 로 submit — URL이 결과 상태를 반영하지 않음
**페이지**: `/search`
**Severity**: P1
**근거**: routes.rb `resources :search_results, only: [:index, :create]` + `get "/search"` 별도 매핑. 검색 조건이 URL query-string에 없음 = 새로고침/공유/북마크 시 검색 상태 소실.
**제안 변경**: 검색 폼을 GET `/search?region=...` 으로 변경, results는 같은 URL의 GET 응답으로 렌더.

---

### U-001
**제목**: 사이드바 라벨 "물건 찾기" vs 페이지 제목 "물건 목록" — 라벨/콘텐츠 불일치
**페이지**: `/search`
**Severity**: P1
**증거**: `docs/screenshots/explore/06-search.png` — 사이드바 "물건 찾기" 클릭 → 제목 "물건 목록"인데 목록은 없고 검색 폼만
**제안 변경**: 사이드바 라벨과 페이지 제목을 동일하게("물건 찾기"). 본문은 검색 폼 + 결과 목록 영역 두 섹션.

---

### U-002
**제목**: 시뮬레이터 첫 질문에서 "진행률 0%" — 분수("1/8") 또는 "1단계 / 총 8단계" 표기가 더 직관적
**페이지**: `/eviction_guide/simulator/question/JT-Q1`
**Severity**: P2
**증거**: `docs/screenshots/explore/11-simulator-q1.png`

---

### U-003
**제목**: "AI 자동분석 [일시 중단]" 탭이 disabled, 왜 중단되었는지/언제 재개되는지 안내 없음
**페이지**: `/analyses/new`
**Severity**: P1
**증거**: `docs/screenshots/explore/12-analyses-new.png`
**제안 변경**: disabled 탭에 hover/tap 시 툴팁 "현재 자동분석은 정책상 일시 중단 중입니다. 수동분석을 이용해주세요." (또는 ETA 안내)

---

### U-004
**제목**: 사이드바 "AI 분석" → 페이지 제목 "AI 수동분석" — 라벨 불일치
**페이지**: `/analyses/new`
**Severity**: P2
**증거**: `docs/screenshots/explore/12-analyses-new.png`
**제안 변경**: 사이드바 라벨도 "AI 분석" 그대로 두되, 페이지 제목을 "AI 분석"로 통일 (탭 라벨에 "자동분석/수동분석" 구분 이미 있음).

---

### U-005
**제목**: 매뉴얼(워크북) 6단계 중 5단계 "명도 가이드"만 상태 라벨(완료/미시작/진행중) 누락
**페이지**: `/manual`
**Severity**: P2
**증거**: `docs/screenshots/explore/14-manual.png` — 1단계 "완료", 2/3/4/6단계 "·미시작", 5단계만 라벨 없음

---

### U-006
**제목**: 익명 사용자가 `/` 진입 시 곧장 `/properties` "내 물건"으로 직행 — 로그인 안 했는데 "내 ___" 식 표현
**페이지**: `/` → `/properties`
**Severity**: P1
**증거**: `docs/screenshots/explore/01-home-anon.png`
**초보자 반응**: "로그인 안 했는데 '내 물건'이라는 헤더가 뜸. 누구의 물건이라는 거지?"
**제안 변경**:
- (a) 익명일 때 `/`를 랜딩 페이지(서비스 소개 + 시작하기)로 유지하고 `/properties`로 자동 redirect 하지 않거나
- (b) 페이지 제목을 "물건 목록" 같은 중립적 표현으로 변경

---

### U-007
**제목**: 예산 페이지 모든 항목 디폴트값 자동 채움 + "현재 최대입찰가 8,006만원" 자동 계산 — 출처/근거 안내 부재
**페이지**: `/settings/budget`
**Severity**: P1
**증거**: `docs/screenshots/explore/04-onboarding-anon.png`
**초보자 반응**: "내가 입력한 적 없는데 3,000만원 / 8,006만원이 어디서 나왔지?"
**제안 변경**: 디폴트값 옆에 작은 안내 "(예시값이에요. 실제 금액을 입력해주세요.)" + 첫 진입 시 모든 input을 placeholder로 비워두는 옵션.

---

### U-008
**제목**: 예산 페이지의 도메인 용어(DSR, LTV, "취득세 정밀 모드(6~9억 누진식)", "(가액×2/3 − 3) / 100" 수식) — 초보자에게 외계어
**페이지**: `/settings/budget`
**Severity**: P2
**제안 변경**: 각 용어 옆에 ⓘ 아이콘 클릭 시 한 줄 정의 + 예시. (e.g., "LTV = 부동산 가격 대비 대출 가능 한도. 70%면 1억짜리에 7천 빌려준다는 뜻이에요.")

---

### U-009
**제목**: 명도 가이드 30+ 단계가 평면 펼침 리스트로 일괄 표시 — 자기 케이스 식별 곤란
**페이지**: `/eviction_guide`
**Severity**: P1
**증거**: `docs/screenshots/explore/08-eviction-guide.png`
**초보자 반응**: "단계가 너무 많고 S, JT-S, ST-S, DO-S, IO-S 다 섞여 있어서 압도됨"
**제안 변경**: 점유자 유형별로 섹션 분리(접힘 헤더), 또는 "내 케이스부터 시뮬레이터로 확인" CTA 우선 노출.

---

### U-010
**제목**: 명도 단계 prefix(S/JT-S/ST-S/DO-S/IO-S)에 그룹 헤더 또는 prefix 설명 없음
**페이지**: `/eviction_guide`
**Severity**: P1
**증거**: `docs/screenshots/explore/08-eviction-guide.png`
**제안 변경**: 각 prefix 블록 시작 위에 헤더("기본(S) | 후순위 임차인(JT-S) | 선순위 임차인(ST-S) | 채무자/소유자(DO-S) | 불법점유자(IO-S)") 추가.

---

### U-011
**제목**: 시뮬레이터 점유자 유형 선택 4개에 "모르겠음" 또는 "유형부터 확인하고 싶어요" 옵션 없음
**페이지**: `/eviction_guide/simulator/select_type`
**Severity**: P2
**증거**: `docs/screenshots/explore/10-simulator-select-type.png`
**제안 변경**: 5번째 옵션 "잘 모르겠어요 — 가이드부터 보기" → /eviction_guide 로 이동 또는 간단 유형 판별 q&a.

---

### U-012
**제목**: AI 수동분석 4단계 워크플로우 — 현재 단계 진행도 시각 게이지 없음
**페이지**: `/analyses/new`
**Severity**: P2
**제안 변경**: 4단계 각 카드 상단에 "1/4, 2/4, ..." 진행도 + 완료 카드 체크 상태 표시.

---

### U-013
**제목**: 시뮬레이터 상단 "[연필 아이콘] 직접 입력으로 진행 중" 칩 — 클릭 가능한지/모드 변경 가능한지 모호
**페이지**: `/eviction_guide/simulator/question/JT-Q1`
**Severity**: P2
**증거**: `docs/screenshots/explore/11-simulator-q1.png`
**제안 변경**: 클릭 가능하면 호버 시 보더/포인터, 클릭 불가면 칩 색을 회색으로 + 아이콘 제거.

---

### C-001
**제목**: 알림 본문 텍스트 "QA 테스트 알림 / 실 브라우저 검증용 알림" — 디버그/QA 문구가 일반 사용자에 노출
**페이지**: `/notifications`
**Severity**: P1
**B-005 와 직결**. 디버그 데이터를 환경별로 분리해야 함.

---

### C-002
**제목**: 사건번호 입력칸 placeholder "예: 2026타경1234" — placeholder가 빈 폼에서도 회색으로 표시되어 검증 트리거 시 사용자가 "예시값이 입력값으로 들어간 줄" 착각 가능
**페이지**: `/properties`
**Severity**: P2
**제안 변경**: placeholder는 그대로 두되, 입력칸 위에 라벨("사건번호") 명시 추가. 또는 placeholder 색상을 더 흐리게.

---

## 환경/보안 메모 (수정 항목)

| | 내용 |
|---|---|
| Dev error page | 익명 사용자가 임의 ID로 접근하면 dev 모드에서 ActiveRecord 스택트레이스가 노출됨 (`/properties/1`, `/admin/*`). dev에서도 익명 케이스는 사전 차단되어야 함 — 디버그 정보 누출 방지. |
| Console preload warnings | 모든 페이지에서 `tailwind-*.css`, `application-*.css` preload 경고 2건. `<link rel="preload" as="style">` `as` 속성/사용 시점 정합성 점검. |
| OAuth in dev | dev에서 OAuth 자격증명 부재 → 로컬 개발자가 로그인된 흐름을 테스트 할 방법이 사실상 없음. dev 전용 mock OAuth(`OmniAuth.config.test_mode = true` + developer strategy) 또는 `bin/rails dev:seed_user` 같은 명령이 필요. (※ 본 보고서가 인증 후 흐름을 다루지 못한 직접적 원인) |

---

## 우선순위 권장

**P0 (즉시)**
- B-002, B-003, B-005, B-008

**P1 (다음 스프린트)**
- B-001, B-004, B-006, B-007, B-009, B-010, B-011
- U-001, U-003, U-006, U-007, U-009, U-010
- C-001

**P2 (백로그)**
- U-002, U-004, U-005, U-008, U-011, U-012, U-013, C-002

---

## Follow-up (다음 테스트 라운드)

본 1차 라운드에서 다루지 못한 영역 — dev 인증 가능해진 뒤 2차 진행 권장:

1. 온보딩 step1 → step2 → step3 → complete 전체 흐름 + 각 단계 뒤로가기
2. 사건번호 정상 입력 → 물건 추가 → 분석 retry → 권리분석 리포트 (`/properties/:id/report/...`)
3. Inspection 탭(`/properties/:id/inspections/tabs/...`) 입력 검증, source-doc review, grade
4. 즐겨찾기 toggle, 물건 삭제, documents/photos 업로드 (multipart)
5. 알림 mark_read 한 건/전체, 알림 0건 상태
6. 설정의 budget/region/data_sources/api_credentials (verify/destroy)
7. eviction simulator 끝까지(질문 → 결과 → step_detail, branch_detail)
8. 모바일 viewport(375×812) 전수 — 사이드바 햄버거, 표 가로스크롤, 폼 onfocus 위치

스크린샷은 `docs/screenshots/explore/01-*.png` ~ `26-*.png` 27장 첨부.
