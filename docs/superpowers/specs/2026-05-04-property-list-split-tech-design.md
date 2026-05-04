# 물건 목록 / 내 물건 메뉴 분리 — Technical Design

**Date:** 2026-05-04
**Status:** Approved (brainstorming)
**Phase:** 3 (Technical Design)

## Summary

좌측 사이드바의 "물건 목록" 단일 메뉴를 두 개로 분리한다.

- **물건 목록** (`/search`) — 관심 지역 + 조건검색만 담당. 검색 결과 카드 클릭 시 즉시 "내 물건"에 추가된다.
- **내 물건** (`/properties`) — 사건번호로 직접 추가, 필터, 내 물건 카드 그리드.

분리 목적은 **검색(외부 매물 탐색)** 과 **소유(내 즐겨찾기 매물)** 의 책임을 페이지 단위로 명확히 가르는 것이다.

## Goals

- "물건 목록" 페이지는 외부 매물(SearchResult) 탐색 전용으로 단순화한다.
- "내 물건"은 사용자가 의도적으로 추가한 매물(UserProperty)만 표시한다.
- 검색 결과 카드 클릭 한 번으로 즉시 "내 물건"에 추가되며, 같은 화면에 머문다.
- 이미 "내 물건"에 추가된 매물은 검색 결과에서 "이미 추가됨" 배지로 표시되고 클릭이 비활성화된다.
- 예산 박스는 페이지가 아닌 글로벌 헤더로 옮겨 모든 페이지에서 보인다.

## Non-Goals

- UserProperty / SearchResult / Property 데이터 모델 변경은 없다.
- 조건검색 로직(GovernmentCourtAuctionAdapter, CourtAuctionSearchService) 변경은 없다.
- AI 분석, 명도 가이드, 명도 시뮬레이터 페이지에 영향 없다.
- i18n 도입은 본 작업 범위 밖이다 (현재처럼 한국어 하드코딩 유지).

## Architecture

### Routing

`config/routes.rb`:

```ruby
resources :search_results do
  collection do
    get :index           # NEW — "물건 목록" 페이지 (검색 화면)
    post :clear
    post :inline_import
  end
end

get "/search", to: "search_results#index", as: :search   # URL alias for readability
```

`/properties` 는 그대로 "내 물건" 화면을 가리킨다. 사이드바에서는 `search_path` / `properties_path`를 각각 사용한다.

### Sidebar Menu

`app/components/sidebar/component.rb` MENU_GROUPS의 "물건검색" 그룹을 다음 순서로 정렬한다:

```
예산 설정 → 물건 목록 → 내 물건 → AI 분석
```

- "물건 목록" path: `:search_path`
- "내 물건" path: `:properties_path` (NEW menu item)
- "AI분석" 라벨을 **"AI 분석"** (띄어쓰기 추가)으로 변경한다.

### Controller Responsibilities

#### `SearchResultsController#index` (NEW)

"물건 목록" 페이지 — 외부 매물 탐색.

```ruby
def index
  @region = current_user.budget_setting&.region
  @search_results = SearchResult.where(user: current_user).order(created_at: :desc)
  @existing_case_numbers = current_user.user_properties
                                       .joins(:property)
                                       .pluck("properties.case_number")
                                       .to_set
end
```

- 관심 지역 select + 조건검색 버튼 + `criteria-search-results-inner` 영역 렌더
- `@existing_case_numbers`는 검색 결과 카드의 "이미 추가됨" 배지 판단용

#### `SearchResultsController#create` 변경

조건검색 실행 후 redirect 경로:

- 변경 전: `redirect_to properties_path`
- 변경 후: `redirect_to search_path`

#### `SearchResultsController#inline_import` 변경

검색 결과 카드 클릭 시 호출. Turbo Stream 응답으로 페이지에 머문다.

```ruby
def inline_import
  perform_import(params[:search_result_id])
  respond_to do |format|
    format.turbo_stream {
      render turbo_stream: turbo_stream.replace(
        dom_id_for_result(@search_result),
        partial: "search_results/inline_result_item",
        locals: { result: @search_result, already_added: true }
      )
    }
    format.html { redirect_to search_path, notice: "내 물건에 추가되었습니다" }
  end
end
```

`find_or_create_by!` 덕분에 idempotent. UI 단의 비활성화로 일반적으로 두 번째 클릭은 발생하지 않지만, 발생해도 안전하다.

#### `PropertiesController#index` (단순화)

```ruby
def index
  @user_properties = current_user.user_properties.includes(:property)
  apply_filters!  # 안전도 / 텍스트 검색 / 예산 범위
end
```

- 관심 지역 / 조건검색 / `@search_results` / `criteria-search-results` 관련 코드 모두 제거
- `create` (사건번호 추가), `destroy`는 그대로 유지

### View Layout

기존 `app/views/properties/index.html.erb`를 두 파일로 분할:

```
app/views/search_results/index.html.erb              # NEW — "물건 목록"
app/views/properties/index.html.erb                  # 단순화 — "내 물건"
app/views/properties/_case_number_form.html.erb      # NEW — 사건번호 추가 폼 추출
app/views/search_results/_inline_results.html.erb    # 기존 유지
app/views/search_results/_inline_result_item.html.erb # 수정 — "이미 추가됨" 배지 분기
```

#### `search_results/index.html.erb` (물건 목록)

```erb
<% content_for :page_title, "물건 목록" %>

<%# 관심 지역 select + 조건검색 버튼 (region_select_controller, criteria_search_controller) %>
<%# <div id="criteria-search-results"> + render "inline_results" %>
```

#### `properties/index.html.erb` (내 물건)

```erb
<% content_for :page_title, "내 물건" %>

<%= render "case_number_form" %>
<%# 안전도 / 텍스트 / 예산범위 필터 (property_filter_controller) %>
<%# #property-cards-grid + PropertyCardComponent 리스트 %>
```

페이지 내 예산 박스(기존 5-21줄)는 글로벌 헤더로 이전 (다음 절 참고).

#### `_inline_result_item.html.erb` (배지 분기)

`already_added` flag (또는 `existing_case_numbers.include?(result.case_number)`) 분기:

- `already_added == true`: `<button>` 대신 `<div>` 렌더, "이미 추가됨" 배지, `aria-disabled="true"`, 클릭 핸들러 없음
- `already_added == false`: 기존 form_with + 클릭 트리거 그대로

### Stimulus Controller

검색 결과 카드 클릭 → form 제출 (Turbo). 별도 Stimulus 컨트롤러가 추가로 필요하지 않다면 form_with + Turbo만으로 충분하다. 만약 카드 전체를 클릭 영역으로 만들기 위한 핸들러가 필요하면 기존 `criteria_search_controller.js`에 메서드 추가 또는 `inline_import_controller.js`를 신설한다.

### Global Header — Budget Indicator

새 partial: `app/views/shared/_budget_indicator.html.erb`

```erb
<% if (max_bid = current_user.budget_setting&.max_bid) %>
  <%= link_to settings_budget_path, class: "..." do %>
    최대입찰가 <strong><%= format_korean_currency(max_bid) %></strong>
  <% end %>
<% else %>
  <%= link_to "예산 미설정", settings_budget_path, class: "...muted..." %>
<% end %>
```

렌더 위치: 글로벌 헤더(layout)의 우측 영역에서 다크모드 토글 + 프로필 아바타 **왼쪽**. 정확한 layout 파일 경로(`app/views/layouts/application.html.erb` 또는 별도 header partial)는 작업 시 확인.

기존 `properties/index.html.erb` 5-21줄의 페이지 내 예산 박스는 제거.

## Data Flow

### "물건 목록"에서 카드 클릭 → "내 물건" 추가

```
사용자 클릭
  → Turbo form 제출 (search_results#inline_import, search_result_id)
  → perform_import: SearchResult → Property 변환 또는 기존 Property 찾기
  → current_user.user_properties.find_or_create_by!(property: property)
  → Turbo Stream 응답: 해당 카드를 already_added=true 상태로 replace
  → 페이지 머무름, 카드에 "이미 추가됨" 배지 + 클릭 비활성
```

### "내 물건"에서 사건번호 추가

기존 `PropertiesController#create` 동작 그대로:

```
사용자 입력 (법원 + 사건번호)
  → POST /properties
  → CaseSearchService → Property find_or_create
  → current_user.user_properties.find_or_create_by!(property: property)
  → redirect_to properties_path (같은 페이지, 새 카드 그리드 상단에 등장)
```

## Error Handling

기존 동작을 유지한다:

- 조건검색 실패 (외부 API 오류): 기존 SearchResultsController#create의 rescue 그대로
- 사건번호 미입력 / 형식 오류: 기존 criteria_search_controller.js의 `submitCaseNumber()` 검증 그대로
- inline_import 실패 (이미 존재하지 않는 SearchResult 등): 기존 rescue + flash 메시지 흐름 유지

## Testing Strategy

CLAUDE.md의 TDD 원칙(Red-Green-Refactor)에 따라 다음 순서:

### System Tests

1. `test/system/property_search_test.rb` (NEW)
   - 사이드바 "물건 목록" 클릭 → `/search` 도착, 페이지 타이틀 "물건 목록"
   - 관심 지역 변경 → "조건검색" → `criteria-search-results-inner` 갱신
   - 검색 결과 카드 클릭 → 같은 페이지에서 카드가 "이미 추가됨" 배지로 교체
   - 두 번째 클릭 시 비활성 (event 발생 안 함)

2. `test/system/my_properties_test.rb` (rename 또는 NEW from existing properties_test)
   - 사이드바 "내 물건" 클릭 → `/properties` 도착, 페이지 타이틀 "내 물건"
   - 사건번호 추가 폼 → 카드 그리드에 신규 카드 등장
   - 안전도 / 텍스트 / 예산범위 필터 동작
   - 삭제 버튼 동작

3. `test/system/budget_indicator_test.rb` (NEW)
   - 모든 페이지(properties, search, settings 등)에서 헤더에 예산 표시
   - 미설정 시 "예산 미설정" 노출, 클릭 시 settings_budget으로 이동

### Controller Tests

- `SearchResultsControllerTest#index`: 로그인 사용자, `@existing_case_numbers` 세팅, 빈 결과 상태
- `SearchResultsControllerTest#inline_import`: Turbo Stream 응답 검증, idempotent (두 번 호출해도 user_properties.count 변동 없음)
- `PropertiesControllerTest#index`: 검색/지역 관련 인스턴스 변수 제거 확인 (regression)
- `PropertiesControllerTest#create`: 기존 동작 유지

### TDD Order

1. 사이드바 메뉴 추가 테스트 → MENU_GROUPS 수정 (+ "AI 분석" 띄어쓰기)
2. `search_results#index` 라우팅 + 렌더 테스트 → 액션 추가 + 뷰 분리
3. "이미 추가됨" 배지 테스트 → `_inline_result_item` 분기 + `@existing_case_numbers` 추가
4. inline_import Turbo Stream 응답 테스트 → 컨트롤러 수정
5. 글로벌 헤더 budget indicator 테스트 → partial + layout 삽입
6. PropertiesController 정리 → 검색 관련 코드 제거 후 regression 확인

각 단계는 별도 commit (Tidy First — 구조 변경과 동작 변경 분리).

## Open Questions

- 글로벌 헤더 partial의 정확한 위치 — 작업 시 layout 파일 확인 후 결정
- 검색 결과 카드의 "이미 추가됨" 배지 디자인 (배지 색상/문구) — 기존 디자인 토큰 따름
- 카드 클릭 영역이 카드 전체인지 특정 버튼인지 — 현재 카드 자체를 form submit으로 감싸는 방식 가정 (기존 inline_import_form 동작 확인 필요)

## References

- 기존 `app/views/properties/index.html.erb` (분할 대상)
- 기존 `app/controllers/search_results_controller.rb#inline_import`
- 기존 `app/components/sidebar/component.rb` MENU_GROUPS
- CLAUDE.md — TDD, Tidy First, 한국어/영어 분리 원칙
