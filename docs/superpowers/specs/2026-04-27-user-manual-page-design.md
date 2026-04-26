# User Manual Page — Design Spec

- **Date:** 2026-04-27
- **Status:** Draft (브레인스토밍 합의 결과)
- **Concept:** "경매 초보의 워크북" — 정보 제공이 아니라 분석 능력 배양

## Problem

현재 사이드바는 기능 메뉴(예산/물건/AI분석/명도가이드/시뮬)만 노출되어 있다. 신규 사용자는 어디서 시작해 어디로 끝나는지 한눈에 보지 못하고, 기존 사용자는 자신이 워크플로 중 어느 위치에 있는지 매번 추적해야 한다.

또한 본 앱의 차별화 포지션 — *"낙찰 전 89개 체크리스트, 낙찰 후 명도 시뮬레이터로 직접 분석하는 워크북"* — 을 한 화면에서 일관되게 전달하는 진입점이 없다.

## Goal

신규/기존 사용자 모두에게 **단일 페이지에서 전체 워크플로와 자신의 현재 위치**를 보여주는 사용자매뉴얼 페이지를 제공한다. 페이지 자체가 컨셉("워크북")의 시연이 되도록 구조와 카피를 정렬한다.

### Non-goals

- 인터랙티브 튜토리얼/오버레이 툴팁(Shepherd.js 등)
- 동영상/GIF 데모 자산
- 게이미피케이션(배지·달성률 알림)
- 진입 트래킹 신규 도메인 모델 추가
- 다국어 지원 (현재 ko-only)

## Design Decisions (브레인스토밍 합의)

| # | 항목 | 결정 |
|---|------|------|
| Q1 | 주된 독자 | 신규 + 기존 둘 다 — 계층형 한 페이지 |
| Q2 | 단계 분할 | 2단 큰 골격 (낙찰 전 4 / 낙찰 후 2) |
| Q3 | Hero 카피 | "경매 초보의 워크북" 메인 + "89체크/시뮬" 부제 + 차별화 한 줄 서브 |
| Q4 | 사이드바 위치 | "시작하기" 그룹 신설, 최상단 |
| 접근 | 깊이 | 접근 2 — 정적 + "이어서 하기" 진행 상태 표시 (개인화 1단계) |

## Page Skeleton

### Sidebar 변경

```
[시작하기]      ← 신설 그룹 (최상단)
  📖 사용자매뉴얼
[물건검색]      ← 기존
  예산 설정 / 물건 목록 / AI분석
[가이드]        ← 기존
  명도 가이드 / 명도 시뮬레이터
```

### Route

```ruby
resource :manual, only: [:show]   # GET /manual → manuals#show, manual_path
```

### Page Sections (위 → 아래)

**1. Hero (1뷰포트 안)**
- 좌측 2/3:
  - 헤드라인: *"경매 초보의 워크북"*
  - 부제: *"낙찰 전 89개 체크리스트, 낙찰 후 명도 시뮬레이터"*
  - 작은 글씨: *"정보를 보여드리는 게 아니라, 직접 분석하는 능력을 길러드립니다."*
- 우측 1/3: **"이어서 하기" 카드**
  - 현재 단계 라벨 + 진행률(있으면) + 큰 CTA 버튼
  - 첫 방문 시 폴백: *"처음부터 시작하기"* → `start_onboarding_path`

**2. 흐름도 스트립** — Hero 바로 아래 1줄
- 6박스 가로 배열, 4번째와 5번째 사이 *"낙찰"* 마커로 시각적 구분
- 각 박스: 번호 + 라벨 + 상태 아이콘 (✓/▶/·)
- 현재 단계 박스는 강조 색상

```
① 예산 → ② 물건 → ③ AI분석 → ④ 89체크 ║ ⑤ 명도가이드 → ⑥ 시뮬레이터
                                       (낙찰)
```

**3. [낙찰 전] 섹션** — 헤더 + 4개 step 카드 (아코디언, 기본 접힘)
- 카드(접힘): 번호 + 제목 + 1줄 요약 + 상태 아이콘 + 펼침 버튼
- 카드(펼침): 핵심 액션 3개(불릿) + 스크린샷 1장 + CTA 버튼
- **현재 단계 카드만 기본 펼침**

**4. [낙찰 후] 섹션** — 동일 구조, 2개 step

**5. 푸터 안내** — 1단락
- *"각 화면에서 막히면 상단 도움말 아이콘을 눌러주세요"* (※ 도움말 아이콘 자체는 별도 작업, 이 페이지에선 카피만)

## Progress State Data Flow

### 책임 분리

- `Manuals::Progress` PORO → `Manuals::Progress.for(current_user)` 호출
- 결과 객체: `Manuals::ProgressResult(steps:, current_step:, continue_cta:)`
- View/Component는 결과 객체만 렌더 — AR 쿼리 누수 없음, 단위 테스트 용이
- **CTA 경로/라벨 매핑은 컴포넌트 책임** — `Progress`는 `step.key`(symbol)만 들고 라우트 헬퍼 의존 없음

### 스텝별 상태 산출 규칙 (모두 기존 테이블만 사용)

| # | 단계 | ✓ 완료 | ▶ 진행 중 | · 미시작 |
|---|------|---|---|---|
| 1 | 예산 정하기 | `BudgetSetting`이 있고 `completed_at not nil` | row 존재하나 `completed_at` nil | row 없음 |
| 2 | 물건 찾기 | `UserProperty.exists?(user_id: u)` | (없음 — 추가 즉시 ✓) | 0건 |
| 3 | AI 분석 | `UserProperty.exists?(user_id: u, analyzed_at: not nil)` | user_property 있으나 모든 `analyzed_at` nil | step 2 미시작 |
| 4 | 89체크 | 사용자별 distinct `inspection_results.inspection_item_id` 수 ≥ 89 | 1 ≤ count < 89 | 0건 |
| 5 | 명도 가이드 | (트래킹 안 함 — 라벨만, 상태 아이콘 없음) | — | — |
| 6 | 시뮬레이터 | `EvictionSimulation.exists?(property_id IN user's, completed: true)` | row 있고 `completed=false` | 0건 |

> **89체크 ✓ 정의:** "전체 89개 다 채움". "필수 항목" 개념을 도입하지 않음(현재 도메인 단순화 유지).

### "현재 단계" 결정

- 1→6 순서로 **첫 번째 ✓ 아닌 단계**를 현재 단계로 선언
- 모두 ✓이면 → 현재 단계 = 6번, CTA = *"다른 물건도 분석해 보기"*
- 모두 ·이면 → 현재 단계 = 1번, CTA = *"예산 설정으로 시작하기"*
- 5번(상태 트래킹 안 함)은 결정 로직에서 항상 "non-done이 아닌 것처럼" 패스 — current_step이 5번이 되는 일은 없음

### "이어서 하기" CTA 매핑

| 현재 단계 | 라벨 | 경로 |
|---|---|---|
| 1 (▶) | "예산 설정 이어서 하기" | `start_onboarding_path` |
| 1 (·) | "예산 설정 시작" | `start_onboarding_path` |
| 2 (·) | "물건 추가하기" | `properties_path` |
| 3 (▶) | "분석 이어서 하기" | `properties_path` (또는 가장 최근 user_property) |
| 3 (·) | "AI 분석할 물건 고르기" | `properties_path` |
| 4 (▶) | "이어서 채우기 (32/89)" | 가장 최근 `user_property` (=`updated_at` MAX) → inspection deep link |
| 4 (·) | "체크리스트 시작" | `properties_path` |
| 6 (▶) | "시뮬레이션 이어서 하기" | `eviction_guide_simulator_path` |
| 6 (·) | "시뮬레이터 돌려보기" | `eviction_guide_simulator_path` |

### "가장 최근 active property"

`user_property.updated_at` 최댓값 — 가장 마지막에 어떤 변경이라도 발생한 항목 = 사용자가 가장 최근 다룬 물건이라는 합리적 추론.

### 쿼리 비용

- 6개 `EXISTS` + 1개 `COUNT(DISTINCT)` 쿼리 = 페이지 로드당 ~7쿼리
- 모두 `user_id` / `property_id` 인덱스 사용
- PORO 인스턴스 내 `||=` 메모이제이션. Rails fragment cache는 도입 안 함(개인화 캐시 적중률 낮음).

### Edge Cases

- **Budget 마법사 도중 이탈:** step 1 ▶ + CTA "이어서 하기" (재개)
- **물건 있지만 AI 분석 미완:** step 3 ▶, step 4 카드 CTA는 비활성(회색) + 툴팁 *"AI 분석을 먼저 마쳐주세요"*
- **신규 사용자 (모든 row 0):** Hero "이어서 하기" 카드가 "처음부터 시작하기"로 폴백, step 1만 펼침

## Component / File Structure

```
app/
├── controllers/
│   └── manuals_controller.rb               # show 액션만, requires authentication
├── models/
│   └── manuals/
│       ├── progress.rb                     # PORO: Manuals::Progress.for(user)
│       ├── progress_result.rb              # Data.define(:steps, :current_step, :continue_cta)
│       └── step.rb                         # Data.define(:number, :key, :status, :detail)
├── components/
│   └── manual/
│       ├── component.rb / .html.erb        # 페이지 조립 (로직 0줄)
│       ├── hero/
│       │   └── component.rb / .html.erb    # 헤드라인 + "이어서 하기" 카드
│       ├── flow_strip/
│       │   └── component.rb / .html.erb    # 6박스 가로 스트립 + 낙찰 마커
│       ├── phase_section/
│       │   └── component.rb / .html.erb    # 낙찰 전/후 섹션
│       └── step_card/
│           └── component.rb / .html.erb    # 아코디언 카드, CTA 매핑 담당
├── components/sidebar/
│   └── component.rb                        # MENU_GROUPS 수정 — "시작하기" 그룹 신설
└── views/manuals/
    └── show.html.erb                       # render Manual::Component.new(progress: ...)
```

### Stimulus / 인터랙션

- 아코디언 펼침/접힘은 **HTML 네이티브 `<details><summary>`** 사용 — JS 0줄, 접근성 자동
- 서버에서 현재 단계 카드만 `<details open>`으로 렌더
- URL 해시 동기화나 "전체 펼치기" 같은 부가기능은 도입 안 함 (워크북 컨셉에 무거운 JS 어울리지 않음)

### 스크린샷 자산

- `app/assets/images/manual/01-budget.png` ... `06-simulator.png`
- 각 스텝 펼침 상태에서 1장
- 구현 작업 마지막 단계에서 placeholder → 실제 캡처로 교체

### 책임 경계

- `Manuals::Progress`: AR 쿼리만, 라우트 헬퍼 미참조
- `Manual::StepCard::Component`: `step.key` → CTA 경로/라벨 매핑
- `Manual::Component`: sub-component 조립, 로직 없음

## Copy / i18n

`config/locales/manuals.ko.yml` 신규 추가. 본 앱은 ko-only이므로 영문 키 + 한글 값으로 구성.

### 카피 전문

```yaml
ko:
  manuals:
    show:
      hero:
        headline: "경매 초보의 워크북"
        subhead: "낙찰 전 89개 체크리스트, 낙찰 후 명도 시뮬레이터"
        tagline: "정보를 보여드리는 게 아니라, 직접 분석하는 능력을 길러드립니다."
      continue_card:
        title: "이어서 하기"
        empty_title: "처음부터 시작하기"
        empty_body: "예산 설정부터 6단계로 안내해 드립니다."
      flow_strip:
        auction_marker: "낙찰"
      phase_pre:
        heading: "낙찰 전"
        subheading: "89개 체크리스트로 직접 분석합니다"
      phase_post:
        heading: "낙찰 후"
        subheading: "명도 시뮬레이터로 다음 한 수를 정합니다"
      footer:
        help_text: "각 화면에서 막히면 상단 도움말 아이콘을 눌러주세요."
    steps:
      budget:
        label: "예산 정하기"
        summary: "내가 살 수 있는 가격대를 먼저 못 박습니다."
        actions:
          - "보유 현금과 대출 한도 입력"
          - "취득세·수리비·이사비 등 부대비용 자동 계산"
          - "지역과 평형대 설정"
      properties:
        label: "물건 찾기"
        summary: "법원 경매 물건을 검색해서 내 목록에 담습니다."
        actions:
          - "법원 경매 사이트 검색 결과 가져오기"
          - "관심 물건 내 목록에 추가"
          - "예산 안 맞는 물건 자동 필터"
      ai_analysis:
        label: "AI 분석"
        summary: "권리관계와 위험요소를 AI가 1차로 정리합니다."
        actions:
          - "등기부·매각물건명세서 자동 분석"
          - "인수금액·말소기준권리 추출"
          - "이상 징후 하이라이트"
      checklist:
        label: "89개 체크리스트"
        summary: "AI 결과를 받아 직접 검증·보완합니다. 워크북의 핵심."
        actions:
          - "권리·물건·임차인·시세 등 89개 항목 점검"
          - "근거 문서 첨부와 메모"
          - "안전등급(녹/황/적) 자동 판정"
      eviction_guide:
        label: "명도 가이드"
        summary: "낙찰 후 점유자별 시나리오와 절차를 한 번에 봅니다."
        actions:
          - "점유자 유형별 흐름도"
          - "단계별 소요 기간·비용 가이드"
          - "필요 서류 체크"
      simulator:
        label: "명도 시뮬레이터"
        summary: "내 물건의 명도 난이도를 질문 답변으로 시뮬레이션합니다."
        actions:
          - "점유자 유형 선택"
          - "분기형 질문에 답하면 경로 제시"
          - "예상 기간·난이도 산출"
    cta:
      budget: { default: "예산 설정 시작", in_progress: "예산 설정 이어서 하기" }
      properties: { default: "물건 추가하기" }
      ai_analysis: { default: "AI 분석할 물건 고르기", in_progress: "분석 이어서 하기" }
      checklist: { default: "체크리스트 시작", in_progress: "이어서 채우기 (%{done}/%{total})" }
      eviction_guide: { default: "명도 가이드 펴보기" }
      simulator: { default: "시뮬레이터 돌려보기", in_progress: "시뮬레이션 이어서 하기" }
    status:
      done: "✓ 완료"
      in_progress: "▶ 진행 중"
      pending: "· 미시작"
```

### 카피 톤 가이드

1. **명령형보다 평서형** — "예산 정하기" (O), "예산을 정해 보세요!" (X)
2. **Action 동사 통일** — 모두 명사형 종결 (예: "추가", "필터", "분석")
3. **숫자는 강조 자산** — "89개", "32/89"는 `<strong>` 처리
4. **외부 사이트 명시 금지** — 차별화 카피는 추상화 ("지지옥션" 등 고유명사 미사용)
5. **단계 카드 summary는 1문장** — 줄바꿈 없이 끝

### 확정 vs 추후 수정

- **확정:** 헤드라인, 부제, tagline, step label/summary, status/cta 라벨
- **추후 수정 가능:** step actions 3불릿 — 구현 끝물에 운영 화면과 검수 후 미세 조정 (스펙의 초안 카피로 우선 시작)

## Test Strategy

CLAUDE.md의 Red-Green-Refactor 원칙 준수. **단위 → 컴포넌트 → 시스템** 3계층.

### 1. `Manuals::Progress` 단위 테스트 (~18개)

`test/models/manuals/progress_test.rb` — 6스텝 × {empty, in_progress, done} 조합 + current_step 결정 + 진행률 carry. 가장 빠르고 가장 핵심.

### 2. ViewComponent 테스트 (~12개)

`test/components/manual/` — 결과 객체 stub 주입, DB 의존 없음.
- `manual/component_test.rb` — 조립
- `manual/hero/component_test.rb` — 카피·CTA·폴백
- `manual/flow_strip/component_test.rb` — 박스 6개·낙찰 마커·상태 아이콘
- `manual/step_card/component_test.rb` — 펼침 기본·CTA 라벨·prerequisite 툴팁

### 3. 시스템 테스트 (3개)

`test/system/manuals_test.rb` — 해피패스 + critical interaction + 사이드바 진입.

### 4. 컨트롤러 테스트 (2개)

`test/controllers/manuals_controller_test.rb` — 인증 게이트 + 200 + assigns.

### 테스트 안 하는 것

- i18n 파일 값 검증 (카피 변경 시 매번 깨짐, 무가치)
- 스크린샷 이미지 존재 여부 (dev 시 즉시 발견)

### TDD 진행 순서

1. `Manuals::Progress` 단위 테스트 (도메인 레이어 먼저)
2. ViewComponent (컴포넌트 stub 조립)
3. ManualsController (라우트 연결)
4. System test (사이드바 → 페이지 → 인터랙션 1줄)
5. 사이드바 그룹 신설 회귀 테스트

## Out of Scope (Future)

- 인터랙티브 오버레이 툴팁 (Shepherd.js 등)
- 동영상/GIF 데모
- "워크북 진도 달성" 게이미피케이션
- 다국어 (i18n 다중 로케일)
- 진입 트래킹 신규 도메인 모델
- "도움말 아이콘" 화면별 어태치 (각 화면 작업)

## Risks

- **스크린샷 유지보수 부담:** UI 변경 시 6장 모두 갱신 필요 → 각 step CTA로 실제 화면을 보러가게 유도, 스크린샷은 보조 자료로만
- **현재 단계 결정의 직관과 어긋날 가능성:** 사용자가 step 1을 건너뛰고 직접 step 2를 진행하는 시나리오 → "첫 번째 ✓ 아닌 단계" 룰을 그대로 따름. 사용자 데이터 보고 필요 시 룰 조정
- **89체크 ✓ 정의 단순화:** "전체 89개 다 채움" 조건은 까다로움 → 운영 데이터로 평균 완성률 확인 후, 필요하면 "필수 N개" 개념을 별도 작업으로 도입
