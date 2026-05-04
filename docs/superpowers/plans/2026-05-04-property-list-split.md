# 물건 목록 / 내 물건 메뉴 분리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 단일 `properties#index` 페이지를 두 페이지로 분리한다. `/search` (= "물건 목록", `SearchResultsController#index`)는 외부 매물 검색 + 카드 클릭 추가만 담당하고, `/properties` (= "내 물건", `PropertiesController#index`)는 사건번호 추가 + 필터 + 내 물건 카드만 표시한다. 예산 박스는 글로벌 헤더로 이전한다.

**Architecture:** 기존 SearchResultsController에 `index` 액션을 추가하고 PropertiesController의 검색 페이지네이션 로직 전체를 마이그레이션한다. 카드 클릭 시 `inline_import`는 Turbo Stream `replace`로 카드를 "이미 추가됨" 상태로 교체만 하며, 페이지 분리 후 존재하지 않는 `property-cards-grid` append는 제거한다. 헤더 ViewComponent에 예산 indicator partial을 삽입해 모든 페이지에서 공통 표시한다.

**Tech Stack:** Rails 8, Turbo (Hotwire), Stimulus, ViewComponent, Tailwind CSS, Minitest + Capybara

**Spec:** `docs/superpowers/specs/2026-05-04-property-list-split-tech-design.md`

---

## File Structure

| Path | Action | Responsibility |
|------|--------|----------------|
| `config/routes.rb` | Modify | `get "/search"` alias 추가 |
| `app/components/sidebar/component.rb` | Modify | "내 물건" 메뉴 추가, "물건 목록" path → `:search_path`, "AI분석" → "AI 분석" |
| `test/components/sidebar/component_test.rb` | Modify | 라벨/path 변경 반영 + "내 물건" 메뉴 검증 |
| `app/views/shared/_budget_indicator.html.erb` | Create | 글로벌 헤더용 예산 표시 partial |
| `app/components/header/component.html.erb` | Modify | budget_indicator partial 삽입 |
| `app/components/header/component.rb` | Modify | `current_user`를 partial 로컬로 노출 (이미 존재) |
| `test/components/header/component_test.rb` | Modify | budget_indicator 노출 검증 |
| `app/controllers/search_results_controller.rb` | Modify | `index` 추가, `create`/`clear` redirect 변경, `inline_import` append 제거 |
| `app/views/search_results/index.html.erb` | Create | "물건 목록" 페이지 본문 |
| `app/views/search_results/_inline_result_item.html.erb` | Modify | `already_added` 분기 (배지 + 클릭 비활성) |
| `app/views/search_results/_inline_results.html.erb` | Modify | `already_added_set` 로컬을 item에 전달 |
| `test/controllers/search_results_controller_test.rb` | Modify | `index` 액션 + Turbo Stream 응답 변경 검증 |
| `app/controllers/properties_controller.rb` | Modify | `index` 단순화 — 검색 페이지네이션 변수 제거 |
| `app/views/properties/index.html.erb` | Modify | "내 물건" 본문만, 예산 박스/검색 영역 제거 |
| `app/views/properties/_case_number_form.html.erb` | Create | 사건번호 추가 폼 partial 추출 |
| `test/controllers/properties_controller_test.rb` | Modify | 단순화된 `index` 검증 (regression) |
| `test/system/property_search_test.rb` | Create | "물건 목록" 페이지 시스템 테스트 |
| `test/system/my_properties_test.rb` | Create | "내 물건" 페이지 시스템 테스트 |

---

## Task 1: 사이드바 메뉴 — "내 물건" 추가, "AI분석" → "AI 분석", "물건 목록" path 변경

**Files:**
- Modify: `app/components/sidebar/component.rb:7-20`
- Test: `test/components/sidebar/component_test.rb`

- [ ] **Step 1: 사이드바 컴포넌트 테스트 업데이트 (Red)**

`test/components/sidebar/component_test.rb` 의 기존 단언 3곳을 업데이트하고 "내 물건" 검증을 추가한다.

```ruby
# 기존 (~line 40-46) 교체
test "renders enabled menu item labels" do
  render_inline(Sidebar::Component.new)

  assert_text "예산 설정"
  assert_text "물건 목록"
  assert_text "내 물건"
  assert_text "AI 분석"
end

# 기존 (~line 62-68) 교체
test "renders enabled items as links" do
  render_inline(Sidebar::Component.new)

  assert_selector "a[href='/onboarding']", text: "예산 설정"
  assert_selector "a[href='/search']", text: "물건 목록"
  assert_selector "a[href='/properties']", text: "내 물건"
  assert_selector "a[href='/analyses/new']", text: "AI 분석"
end

# 기존 (~line 86-90) 교체
test "marks properties path as active" do
  render_inline(Sidebar::Component.new(current_path: "/properties"))

  assert_selector "a[href='/properties'][class*='bg-blue-50']", text: "내 물건"
end

# 추가
test "marks search path as active for /search" do
  render_inline(Sidebar::Component.new(current_path: "/search"))

  assert_selector "a[href='/search'][class*='bg-blue-50']", text: "물건 목록"
end
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
bin/rails test test/components/sidebar/component_test.rb
```
Expected: 실패 (route 미정의 또는 메뉴 미존재)

- [ ] **Step 3: 라우트 추가 (Green 준비)**

`config/routes.rb` 의 search_results 블록 직후(83라인 다음)에 alias 추가.

```ruby
resources :search_results, only: [ :index, :create ] do
  collection do
    delete :clear
  end
  member do
    post :import
    post :inline_import
  end
end

get "/search", to: "search_results#index", as: :search   # NEW — "물건 목록" alias
```

- [ ] **Step 4: 사이드바 MENU_GROUPS 변경**

`app/components/sidebar/component.rb` 의 "물건검색" 그룹 (라인 11-15) 교체.

```ruby
"물건검색" => [
  MenuItem.new(label: "예산 설정", icon: "calculator", path: :start_onboarding_path, enabled: true),
  MenuItem.new(label: "물건 목록", icon: "magnifying-glass", path: :search_path, enabled: true),
  MenuItem.new(label: "내 물건", icon: "folder", path: :properties_path, enabled: true),
  MenuItem.new(label: "AI 분석", icon: "document-plus", path: :new_analysis_path, enabled: true)
],
```

- [ ] **Step 5: 테스트 실행 — 통과 확인**

```bash
bin/rails test test/components/sidebar/component_test.rb
```
Expected: 통과

- [ ] **Step 6: 커밋**

```bash
git add app/components/sidebar/component.rb test/components/sidebar/component_test.rb config/routes.rb
git commit -m "feat(sidebar): split menu into 물건 목록 / 내 물건, fix AI 분석 spacing"
```

---

## Task 2: 글로벌 헤더 예산 indicator — partial 생성 + 헤더 삽입

**Files:**
- Create: `app/views/shared/_budget_indicator.html.erb`
- Modify: `app/components/header/component.html.erb:13`
- Modify: `app/components/header/component.rb` (current_user는 이미 로딩됨)
- Test: `test/components/header/component_test.rb`

- [ ] **Step 1: Header 컴포넌트 테스트 추가 (Red)**

`test/components/header/component_test.rb` 끝(클래스 닫기 전)에 다음 테스트를 추가.

```ruby
test "renders budget indicator with max bid when budget set" do
  user = users(:one)
  user.create_budget_setting!(max_bid_amount: 50_000) unless user.budget_setting
  user.budget_setting.update!(max_bid_amount: 50_000)

  render_inline(Header::Component.new(current_user: user))

  assert_selector "a[href='/settings/budget']", text: /최대입찰가/
  assert_text "5억"
end

test "renders budget unset link when no budget" do
  user = users(:one)
  user.budget_setting&.destroy

  render_inline(Header::Component.new(current_user: user))

  assert_selector "a[href='/settings/budget']", text: "예산 미설정"
end
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
bin/rails test test/components/header/component_test.rb
```
Expected: 실패 ("예산 미설정" / "최대입찰가" 텍스트 없음)

- [ ] **Step 3: budget_indicator partial 생성**

기존 `properties/index.html.erb:5-21` 의 두 분기를 partial로 그대로 추출.

`app/views/shared/_budget_indicator.html.erb` (NEW):
```erb
<%# Locals: budget — current_user.budget_setting (or nil) %>
<% if budget&.max_bid_amount.present? %>
  <%= link_to settings_budget_path,
      class: "inline-flex items-center gap-1.5 rounded-md bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 px-3 h-8 hover:bg-blue-100 dark:hover:bg-blue-800/30 transition-colors duration-150" do %>
    <span class="text-sm text-slate-500 dark:text-slate-400">최대입찰가</span>
    <span class="text-sm font-bold tabular-nums text-blue-700 dark:text-blue-300"><%= format_price_in_eok(budget.max_bid_amount) %></span>
    <svg class="w-3.5 h-3.5 text-slate-400 dark:text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
  <% end %>
<% else %>
  <%= link_to settings_budget_path,
      class: "inline-flex items-center gap-1.5 rounded-md bg-slate-50 dark:bg-slate-800 border border-dashed border-slate-300 dark:border-slate-600 px-3 h-8 hover:bg-slate-100 dark:hover:bg-slate-700 transition-colors duration-150" do %>
    <span class="text-sm text-slate-400 dark:text-slate-500">예산 미설정</span>
    <svg class="w-3.5 h-3.5 text-slate-400 dark:text-slate-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"/></svg>
  <% end %>
<% end %>
```

- [ ] **Step 4: Header 컴포넌트에 partial 삽입**

`app/components/header/component.html.erb` 의 13라인 (`<div class="flex items-center gap-1">`) 직후, 다크모드 토글 앞에 추가.

```erb
<div class="flex items-center gap-1">
  <% if signed_in? %>
    <%= render "shared/budget_indicator", budget: @current_user.budget_setting %>
  <% end %>
  <div data-controller="dark-mode">
    <!-- ... 기존 다크모드 토글 ... -->
```

- [ ] **Step 5: 테스트 실행 — 통과 확인**

```bash
bin/rails test test/components/header/component_test.rb
```
Expected: 통과

- [ ] **Step 6: 커밋**

```bash
git add app/views/shared/_budget_indicator.html.erb app/components/header/component.html.erb test/components/header/component_test.rb
git commit -m "feat(header): show budget indicator globally"
```

---

## Task 3: SearchResultsController#index 액션 + 페이지네이션 마이그레이션

**Files:**
- Modify: `app/controllers/search_results_controller.rb:4-6`
- Test: `test/controllers/search_results_controller_test.rb`

- [ ] **Step 1: 컨트롤러 테스트 작성 (Red)**

`test/controllers/search_results_controller_test.rb` 에 다음 테스트 추가.

```ruby
test "index assigns paginated search results and existing case numbers" do
  user = users(:one)
  sign_in_as(user)
  10.times do |i|
    user.search_results.create!(case_number: "2024타경#{1000 + i}", court_code: "B000210", court_name: "서울지법", address: "주소 #{i}", appraisal_price: 100_000_000, min_bid_price: 80_000_000)
  end
  user.update!(last_search_api_total_count: 150)

  get search_path

  assert_response :success
  assert_equal 10, assigns(:search_results).size
  assert_equal 1, assigns(:search_page)
  assert_equal 1, assigns(:total_pages)
  assert_equal 150, assigns(:api_total_count)
  assert assigns(:over_api_limit)
  assert_kind_of Set, assigns(:existing_case_numbers)
end

test "index supports pagination via search_page param" do
  user = users(:one)
  sign_in_as(user)
  25.times do |i|
    user.search_results.create!(case_number: "2024타경#{2000 + i}", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 100_000_000, min_bid_price: 80_000_000)
  end

  get search_path, params: { search_page: 2 }

  assert_equal 2, assigns(:search_page)
  assert_equal 5, assigns(:search_results).size
end
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
bin/rails test test/controllers/search_results_controller_test.rb -n /index/
```
Expected: 실패 (변수 미할당)

- [ ] **Step 3: SearchResultsController#index 구현**

`app/controllers/search_results_controller.rb` 의 라인 4-6 교체.

```ruby
def index
  @setting = current_user.budget_setting
  @region  = @setting&.effective_region
  @existing_case_numbers = current_user.properties.pluck(:case_number).to_set

  search_scope = current_user.search_results.order(created_at: :desc)
  total_displayable = search_scope.count
  @total_pages = (total_displayable.to_f / 20).ceil
  @search_page = params[:search_page].to_i.clamp(1, [ @total_pages, 1 ].max)
  @search_results = search_scope.offset((@search_page - 1) * 20).limit(20)
  @api_total_count = current_user.last_search_api_total_count
  @over_api_limit  = @api_total_count.to_i > 100
end
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
bin/rails test test/controllers/search_results_controller_test.rb -n /index/
```
Expected: 통과

- [ ] **Step 5: 커밋**

```bash
git add app/controllers/search_results_controller.rb test/controllers/search_results_controller_test.rb
git commit -m "feat(search_results): add #index with paginated search results"
```

---

## Task 4: search_results/index.html.erb view 생성 (검색 영역만)

**Files:**
- Create: `app/views/search_results/index.html.erb`

- [ ] **Step 1: System 테스트 작성 (Red)**

`test/system/property_search_test.rb` (NEW):

```ruby
require "application_system_test_case"

class PropertySearchTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "물건 목록 page renders region select and 조건검색 button" do
    visit search_path

    assert_selector "h1", text: "물건 목록", visible: false
    assert_selector "label", text: "관심 지역"
    assert_selector "button", text: "조건검색"
  end

  test "물건 목록 page does NOT show 사건번호 form or my-property cards" do
    visit search_path

    assert_no_selector "label", text: "사건번호로 물건 추가"
    assert_no_selector "#property-cards-grid"
  end
end
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
bin/rails test:system TEST=test/system/property_search_test.rb
```
Expected: 실패 (`Template missing`)

- [ ] **Step 3: search_results/index.html.erb 작성**

`app/views/search_results/index.html.erb` (NEW):
```erb
<% content_for(:page_title, "물건 목록") %>

<%# app/views/search_results/index.html.erb %>
<div class="space-y-6">
  <%# 관심 지역 + 조건검색 %>
  <div data-controller="criteria-search" class="max-w-xl min-w-80">
    <div class="mb-4">
      <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">관심 지역</label>
      <div class="flex items-center gap-2">
        <select name="budget_setting[region]"
                class="flex-1 h-10 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
                data-controller="region-select"
                data-region-select-url-value="<%= update_region_settings_budget_path %>"
                data-action="change->region-select#save">
          <% BudgetSetting::REGIONS.each do |region| %>
            <option value="<%= region %>" <%= "selected" if region == @region %>><%= region %></option>
          <% end %>
        </select>
        <%= form_with url: search_results_path, method: :post, class: "contents", data: { action: "submit->criteria-search#submit turbo:submit-end->criteria-search#enable" } do %>
          <button type="submit"
                  data-criteria-search-target="submitButton"
                  class="inline-flex items-center justify-center gap-1.5 w-24 h-10 rounded-md bg-violet-600 hover:bg-violet-700 dark:bg-violet-600 dark:hover:bg-violet-500 text-white text-sm font-medium transition-colors focus-visible:ring-2 focus-visible:ring-violet-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-slate-900">
            <span data-criteria-search-target="buttonText">조건검색</span>
            <svg data-criteria-search-target="buttonSpinner" class="hidden w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
          </button>
        <% end %>
      </div>
    </div>
  </div>

  <%# 조건검색 결과 %>
  <div id="criteria-search-results">
    <% if @search_results&.any? %>
      <%= render "search_results/inline_results",
                 search_results: @search_results,
                 search_page: @search_page,
                 total_pages: @total_pages,
                 api_total_count: @api_total_count,
                 over_api_limit: @over_api_limit,
                 existing_case_numbers: @existing_case_numbers %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
bin/rails test:system TEST=test/system/property_search_test.rb
```
Expected: 통과

- [ ] **Step 5: 커밋**

```bash
git add app/views/search_results/index.html.erb test/system/property_search_test.rb
git commit -m "feat(search_results): add 물건 목록 page view"
```

---

## Task 5: SearchResultsController#create — redirect 변경 (`/properties` → `/search`)

**Files:**
- Modify: `app/controllers/search_results_controller.rb:8-21`
- Test: `test/controllers/search_results_controller_test.rb`

- [ ] **Step 1: create redirect 테스트 추가 (Red)**

`test/controllers/search_results_controller_test.rb` 의 기존 create 테스트가 있다면 업데이트, 없다면 추가.

```ruby
test "create redirects to /search with notice on success" do
  user = users(:one)
  sign_in_as(user)
  user.create_budget_setting!(max_bid_amount: 50_000, region: "서울특별시")

  CourtAuctionSearchService.stub :call, OpenStruct.new(error: nil, count: 5) do
    post search_results_path
  end

  assert_redirected_to search_path
end

test "create redirects to /search with alert on error" do
  user = users(:one)
  sign_in_as(user)
  user.create_budget_setting!(max_bid_amount: 50_000, region: "서울특별시")

  CourtAuctionSearchService.stub :call, OpenStruct.new(error: :timeout, count: 0) do
    post search_results_path
  end

  assert_redirected_to search_path
end
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
bin/rails test test/controllers/search_results_controller_test.rb -n /create redirects/
```
Expected: 실패 (현재 `/properties`로 redirect)

- [ ] **Step 3: 컨트롤러 수정**

`app/controllers/search_results_controller.rb` 의 `create` 액션(라인 8-21) 교체.

```ruby
def create
  bs = current_user.budget_setting
  result = CourtAuctionSearchService.call(
    user: current_user,
    address: bs&.effective_region || BudgetSetting::DEFAULT_REGION,
    max_bid_price: bs&.max_bid_amount.to_i * 10_000
  )

  if result.error
    redirect_to search_path, alert: error_message_for(result.error)
  else
    redirect_to search_path, notice: "#{result.count}건의 검색 결과를 가져왔습니다."
  end
end
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
bin/rails test test/controllers/search_results_controller_test.rb -n /create redirects/
```
Expected: 통과

- [ ] **Step 5: 커밋**

```bash
git add app/controllers/search_results_controller.rb test/controllers/search_results_controller_test.rb
git commit -m "feat(search_results): redirect create to /search"
```

---

## Task 6: SearchResultsController#clear — redirect 변경

**Files:**
- Modify: `app/controllers/search_results_controller.rb:75-84`
- Test: `test/controllers/search_results_controller_test.rb`

- [ ] **Step 1: clear redirect 테스트 추가 (Red)**

`test/controllers/search_results_controller_test.rb` 에 추가.

```ruby
test "clear (HTML) redirects to /search" do
  user = users(:one)
  sign_in_as(user)
  user.search_results.create!(case_number: "2024타경1", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 1, min_bid_price: 1)

  delete clear_search_results_path

  assert_redirected_to search_path
  assert_equal 0, user.search_results.count
end
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
bin/rails test test/controllers/search_results_controller_test.rb -n /clear/
```
Expected: 실패 (현재 `/properties`로 redirect)

- [ ] **Step 3: clear 액션 수정**

`app/controllers/search_results_controller.rb` 의 `clear` 액션(라인 75-84) 교체.

```ruby
def clear
  current_user.search_results.destroy_all

  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.update("criteria-search-results", "")
    end
    format.html { redirect_to search_path }
  end
end
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
bin/rails test test/controllers/search_results_controller_test.rb -n /clear/
```
Expected: 통과

- [ ] **Step 5: 커밋**

```bash
git add app/controllers/search_results_controller.rb test/controllers/search_results_controller_test.rb
git commit -m "feat(search_results): redirect clear to /search"
```

---

## Task 7: _inline_result_item 에 already_added 분기 추가 (배지 + 클릭 비활성)

**Files:**
- Modify: `app/views/search_results/_inline_result_item.html.erb`
- Modify: `app/views/search_results/_inline_results.html.erb`

- [ ] **Step 1: System 테스트 추가 (Red)**

`test/system/property_search_test.rb` 에 다음 테스트 추가.

```ruby
test "검색 결과 카드 — 이미 내 물건에 추가된 항목은 '이미 추가됨' 배지로 표시되고 클릭 비활성화" do
  property = Property.create!(case_number: "2024타경9999", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 100_000_000, min_bid_price: 80_000_000)
  @user.user_properties.create!(property: property)
  @user.search_results.create!(case_number: "2024타경9999", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 100_000_000, min_bid_price: 80_000_000)
  @user.search_results.create!(case_number: "2024타경0000", court_code: "B000210", court_name: "서울지법", address: "주소2", appraisal_price: 100_000_000, min_bid_price: 80_000_000)

  visit search_path

  within "div", text: "2024타경9999" do
    assert_text "이미 추가됨"
    assert_no_selector "button[type='submit']"
  end
  within "div", text: "2024타경0000" do
    assert_no_text "이미 추가됨"
    assert_selector "button[type='submit']"
  end
end
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
bin/rails test:system TEST=test/system/property_search_test.rb -n /이미 추가됨/
```
Expected: 실패

- [ ] **Step 3: _inline_results 에서 existing_case_numbers 전달**

`app/views/search_results/_inline_results.html.erb` 머리 주석 + item 렌더 부분 교체.

```erb
<%# app/views/search_results/_inline_results.html.erb
    Locals:
      search_results        — ActiveRecord::Relation of paginated SearchResult rows (up to 20)
      search_page           — Integer (1-based current page)
      total_pages           — Integer
      api_total_count       — Integer or nil (users.last_search_api_total_count)
      over_api_limit        — Boolean
      existing_case_numbers — Set<String> case numbers already in user_properties
%>
<turbo-frame id="search-results-frame" data-turbo-action="advance">
  <div id="criteria-search-results-inner"
       class="bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-3.5 mt-3">
    <div class="flex items-center gap-2 mb-3">
      <span class="text-sm font-semibold text-slate-900 dark:text-slate-100">
        조건검색 결과 <span id="criteria-search-count" class="text-violet-500"><%= search_results.size %>건</span>
      </span>
      <% if over_api_limit && search_results.any? %>
        <span class="text-sm text-amber-500">전체 <%= api_total_count %>건 중 상위 100건만 조회됩니다</span>
      <% end %>
    </div>

    <% if search_results.any? %>
      <div class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        <% search_results.each do |sr| %>
          <%= render "search_results/inline_result_item",
                     search_result: sr,
                     already_added: existing_case_numbers.include?(sr.case_number) %>
        <% end %>
      </div>

      <%= render "search_results/pagination",
                 current_page: search_page,
                 total_pages: total_pages %>
    <% else %>
      <p class="text-sm text-slate-500 dark:text-slate-400 text-center py-4">검색 결과가 없습니다.</p>
    <% end %>
  </div>
</turbo-frame>
```

- [ ] **Step 4: _inline_result_item 에 already_added 분기 추가**

`app/views/search_results/_inline_result_item.html.erb` 전체 교체.

```erb
<%# app/views/search_results/_inline_result_item.html.erb
    Locals:
      search_result — SearchResult instance
      already_added — Boolean (default false). When true, render disabled card with badge
%>
<% already_added = local_assigns.fetch(:already_added, false) %>
<div id="<%= dom_id(search_result, :inline) %>"
     class="bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl p-3 <%= already_added ? "opacity-60" : "cursor-pointer hover:border-violet-500 dark:hover:border-violet-500 transition-colors" %>"
     <%= already_added ? 'aria-disabled="true"' : "" %>>
  <% if already_added %>
    <div class="w-full text-left">
      <div class="flex items-center justify-between">
        <span class="text-sm font-semibold text-violet-400">
          <%= search_result.case_number %>
          <% if search_result.property_count > 1 %>
            <span class="inline-flex items-center rounded bg-amber-900/30 px-1.5 py-0.5 text-sm font-medium text-amber-400">다물건 <%= search_result.property_count %>건</span>
          <% end %>
        </span>
        <span class="inline-flex items-center rounded bg-emerald-900/30 px-1.5 py-0.5 text-xs font-medium text-emerald-400">이미 추가됨</span>
      </div>
      <div class="mt-1.5 space-y-0.5">
        <div class="text-sm text-slate-500 dark:text-slate-400">감정가 <span class="text-slate-300 dark:text-slate-300 font-medium"><%= format_price_won(search_result.appraisal_price) %></span></div>
        <div class="text-sm text-slate-500 dark:text-slate-400">최저매각가 <span class="text-slate-300 dark:text-slate-300 font-medium"><%= format_price_won(search_result.min_bid_price) %></span></div>
      </div>
      <% if search_result.court_name.present? %>
        <div class="text-sm text-slate-500 dark:text-slate-400 mt-1 truncate">🏛️ <%= search_result.court_name %></div>
      <% end %>
      <div class="text-sm text-slate-500 dark:text-slate-400 mt-1 truncate">📍 <%= search_result.address %></div>
    </div>
  <% else %>
    <%= form_with url: inline_import_search_result_path(search_result), method: :post, data: { turbo_stream: true } do %>
      <button type="submit" class="w-full text-left cursor-pointer focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-blue-400/50 dark:focus-visible:ring-offset-slate-900 rounded-lg">
        <div class="flex items-center justify-between">
          <span class="text-sm font-semibold text-violet-400">
            <%= search_result.case_number %>
            <% if search_result.property_count > 1 %>
              <span class="inline-flex items-center rounded bg-amber-900/30 px-1.5 py-0.5 text-sm font-medium text-amber-400">다물건 <%= search_result.property_count %>건</span>
            <% end %>
          </span>
        </div>
        <div class="mt-1.5 space-y-0.5">
          <div class="text-sm text-slate-500 dark:text-slate-400">감정가 <span class="text-slate-300 dark:text-slate-300 font-medium"><%= format_price_won(search_result.appraisal_price) %></span></div>
          <div class="text-sm text-slate-500 dark:text-slate-400">최저매각가 <span class="text-slate-300 dark:text-slate-300 font-medium"><%= format_price_won(search_result.min_bid_price) %></span></div>
        </div>
        <% if search_result.court_name.present? %>
          <div class="text-sm text-slate-500 dark:text-slate-400 mt-1 truncate">🏛️ <%= search_result.court_name %></div>
        <% end %>
        <div class="text-sm text-slate-500 dark:text-slate-400 mt-1 truncate">📍 <%= search_result.address %></div>
      </button>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 5: 테스트 실행 — 통과 확인**

```bash
bin/rails test:system TEST=test/system/property_search_test.rb -n /이미 추가됨/
```
Expected: 통과

- [ ] **Step 6: 커밋**

```bash
git add app/views/search_results/_inline_result_item.html.erb app/views/search_results/_inline_results.html.erb test/system/property_search_test.rb
git commit -m "feat(search_results): show '이미 추가됨' badge for cards already saved"
```

---

## Task 8: inline_import — Turbo Stream 응답 변경 (append 제거, replace로 배지 표시)

**Files:**
- Modify: `app/controllers/search_results_controller.rb:34-73`
- Test: `test/controllers/search_results_controller_test.rb`

- [ ] **Step 1: 컨트롤러 테스트 작성 (Red)**

`test/controllers/search_results_controller_test.rb` 에 추가.

```ruby
test "inline_import returns Turbo Stream that replaces card with already_added badge" do
  user = users(:one)
  sign_in_as(user)
  sr = user.search_results.create!(case_number: "2024타경7777", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 100_000_000, min_bid_price: 80_000_000)

  post inline_import_search_result_path(sr), as: :turbo_stream

  assert_response :success
  assert_match /turbo-stream action="replace"/, response.body
  assert_match dom_id(sr, :inline), response.body
  assert_match "이미 추가됨", response.body

  # 분리 후 property-cards-grid는 search 페이지에 없음 → append 스트림 미포함
  assert_no_match /property-cards-grid/, response.body
end

test "inline_import is idempotent — second call does not create duplicate user_property" do
  user = users(:one)
  sign_in_as(user)
  sr = user.search_results.create!(case_number: "2024타경8888", court_code: "B000210", court_name: "서울지법", address: "주소", appraisal_price: 100_000_000, min_bid_price: 80_000_000)

  post inline_import_search_result_path(sr), as: :turbo_stream
  count_after_first = user.user_properties.count

  post inline_import_search_result_path(sr), as: :turbo_stream
  assert_equal count_after_first, user.user_properties.count
end
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
bin/rails test test/controllers/search_results_controller_test.rb -n /inline_import/
```
Expected: 실패 (현재 응답이 fade_out + property-cards-grid append 포함)

- [ ] **Step 3: inline_import 액션 수정**

`app/controllers/search_results_controller.rb` 의 `inline_import` 액션(라인 34-73) 교체.

```ruby
def inline_import
  search_result = current_user.search_results.find(params[:id])
  import_result = perform_import(search_result)

  if import_result[:success]
    render turbo_stream: turbo_stream.replace(
      dom_id(search_result, :inline),
      partial: "search_results/inline_result_item",
      locals: { search_result: search_result, already_added: true }
    )
  else
    render turbo_stream: turbo_stream.replace(
      dom_id(search_result, :inline),
      partial: "search_results/inline_result_item_error",
      locals: { search_result: search_result, message: error_message_for(import_result[:error]) }
    )
  end
end
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
bin/rails test test/controllers/search_results_controller_test.rb -n /inline_import/
```
Expected: 통과

- [ ] **Step 5: 커밋**

```bash
git add app/controllers/search_results_controller.rb test/controllers/search_results_controller_test.rb
git commit -m "feat(search_results): inline_import replaces card with already-added badge only"
```

---

## Task 9: PropertiesController#index 단순화 — 검색 페이지네이션 변수 제거

**Files:**
- Modify: `app/controllers/properties_controller.rb:3-33`
- Test: `test/controllers/properties_controller_test.rb`

- [ ] **Step 1: 컨트롤러 테스트 업데이트 (Red)**

`test/controllers/properties_controller_test.rb` 에 단순화 검증 테스트 추가.

```ruby
test "index does NOT assign search-related instance vars (moved to SearchResultsController#index)" do
  user = users(:one)
  sign_in_as(user)

  get properties_path

  assert_response :success
  assert_nil assigns(:search_results)
  assert_nil assigns(:search_page)
  assert_nil assigns(:total_pages)
  assert_nil assigns(:api_total_count)
  assert_nil assigns(:over_api_limit)
end

test "index still assigns user_properties and budget vars" do
  user = users(:one)
  sign_in_as(user)
  user.create_budget_setting!(max_bid_amount: 50_000)

  get properties_path

  assert_not_nil assigns(:user_properties)
  assert_not_nil assigns(:max_bid_amount)
end
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
bin/rails test test/controllers/properties_controller_test.rb -n /index does NOT assign/
```
Expected: 실패 (현재 `@search_results` 등이 할당됨)

- [ ] **Step 3: PropertiesController#index 단순화**

`app/controllers/properties_controller.rb` 의 `index` 액션(라인 3-33) 전체를 다음으로 교체. 원본 라인 4-19 필터/예산 로직은 그대로 보존하고, 라인 21-32의 검색 페이지네이션 블록만 삭제한다.

```ruby
def index
  @user_properties = current_user.user_properties
    .includes(property: :inspection_results)
    .order(created_at: :desc)
  @user_properties = @user_properties.where(safety_rating: params[:safety_rating]) if params[:safety_rating].present?
  if params[:search].present?
    search_term = "%#{params[:search]}%"
    @user_properties = @user_properties.joins(:property).where(
      "properties.case_number LIKE :q OR properties.address LIKE :q OR properties.building_name LIKE :q",
      q: search_term
    )
  end
  @max_bid_amount = current_user.budget_setting&.max_bid_amount
  @setting = current_user.budget_setting
  if params[:within_budget] == "1" && @max_bid_amount.present?
    @user_properties = @user_properties.joins(:property).where("properties.appraisal_price <= ?", @max_bid_amount * 10000)
  end
end
```

- [ ] **Step 4: 테스트 실행 — 통과 확인**

```bash
bin/rails test test/controllers/properties_controller_test.rb -n /index/
```
Expected: 통과

- [ ] **Step 5: 커밋**

```bash
git add app/controllers/properties_controller.rb test/controllers/properties_controller_test.rb
git commit -m "refactor(properties): drop search pagination from #index (moved to SearchResultsController)"
```

---

## Task 10: properties/index.html.erb 단순화 + _case_number_form partial 추출

**Files:**
- Create: `app/views/properties/_case_number_form.html.erb`
- Modify: `app/views/properties/index.html.erb`
- Test: `test/system/my_properties_test.rb`

- [ ] **Step 1: System 테스트 작성 (Red)**

`test/system/my_properties_test.rb` (NEW):

```ruby
require "application_system_test_case"

class MyPropertiesTest < ApplicationSystemTestCase
  setup do
    @user = users(:one)
    sign_in_as(@user)
  end

  test "내 물건 page renders 사건번호 form and property cards grid" do
    visit properties_path

    assert_selector "label", text: "사건번호로 물건 추가"
    assert_selector "#property-cards-grid"
  end

  test "내 물건 page does NOT show region select / 조건검색 / criteria-search-results" do
    visit properties_path

    assert_no_selector "label", text: "관심 지역"
    assert_no_selector "button", text: "조건검색"
    assert_no_selector "#criteria-search-results"
  end

  test "내 물건 page does NOT show inline budget box (moved to header)" do
    @user.create_budget_setting!(max_bid_amount: 50_000)

    visit properties_path

    # Header partial shows it; in-page box should be gone
    within "main" do
      assert_no_selector "a[href='/settings/budget']", text: /최대입찰가/
    end
  end
end
```

- [ ] **Step 2: 테스트 실행 — 실패 확인**

```bash
bin/rails test:system TEST=test/system/my_properties_test.rb
```
Expected: "내 물건 page does NOT show ..." 실패 (검색 영역과 페이지 내 예산 박스 잔존)

- [ ] **Step 3: _case_number_form partial 생성**

`app/views/properties/_case_number_form.html.erb` (NEW):
```erb
<%# app/views/properties/_case_number_form.html.erb
    Locals: setting — current_user.budget_setting (or nil)
%>
<div data-controller="criteria-search" class="max-w-xl min-w-80">
  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">사건번호로 물건 추가</label>
  <%= form_with url: properties_path, method: :post, class: "space-y-2", data: { action: "submit->criteria-search#submitCaseNumber" } do |f| %>
    <%= select_tag :court_code,
        grouped_options_for_select(CourtAuction::CaseSearchClient.court_options_for(setting&.effective_region)),
        required: true,
        include_blank: false,
        class: "w-full h-10 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500" %>

    <div class="flex items-center gap-2">
      <%= text_field_tag :case_number, nil,
          placeholder: "예: 2026타경1234",
          required: true,
          data: { criteria_search_target: "caseInput", action: "input->criteria-search#clearCaseError" },
          class: "flex-1 min-w-0 h-10 rounded-md border px-3 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100" %>
      <button type="submit" data-criteria-search-target="addButton"
              class="inline-flex items-center justify-center gap-1.5 w-24 h-10 text-sm font-medium rounded-md bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-400 text-white transition-colors">
        <span data-criteria-search-target="addButtonText" class="flex items-center gap-1">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.5v15m7.5-7.5h-15"/></svg>
          추가
        </span>
        <svg data-criteria-search-target="addButtonSpinner" class="hidden w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
      </button>
    </div>
  <% end %>
  <p class="hidden text-sm text-red-500 dark:text-red-400 mt-1" data-criteria-search-target="caseError">사건번호를 입력해주세요</p>
  <p class="text-sm text-slate-500 dark:text-slate-400 mt-1.5">법원과 사건번호를 입력해주세요</p>
</div>
```

- [ ] **Step 4: properties/index.html.erb 단순화**

`app/views/properties/index.html.erb` 전체 교체.

```erb
<% content_for(:page_title, "내 물건") %>

<%# app/views/properties/index.html.erb %>
<div class="space-y-6">
  <%= render "case_number_form", setting: @setting %>

  <% filters_applied = params[:safety_rating].present? || params[:search].present? || params[:within_budget].present? %>

  <% if @user_properties.any? || filters_applied %>
    <%# Filter + Search bar %>
    <div data-controller="property-filter" class="max-w-xl min-w-80">
      <%= form_with url: properties_path, method: :get, data: { property_filter_target: "form" }, class: "space-y-2" do %>
        <div class="flex items-center gap-2">
          <%= select_tag :safety_rating,
              options_for_select([["전체", ""], ["안전", "safe"], ["주의", "caution"], ["경고", "danger"]], params[:safety_rating]),
              class: "h-10 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-200 text-sm px-3 focus:ring-2 focus:ring-blue-500/20 focus:outline-none",
              data: { property_filter_target: "ratingSelect", action: "change->property-filter#filter" } %>
          <div class="relative flex-1 min-w-0">
            <div class="pointer-events-none absolute inset-y-0 left-0 flex items-center pl-3">
              <svg class="w-4 h-4 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/>
              </svg>
            </div>
            <%= text_field_tag :search, params[:search],
                placeholder: "주소, 사건번호, 법원명 검색",
                class: "w-full h-10 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-200 text-sm pl-9 pr-3 focus:ring-2 focus:ring-blue-500/20 focus:outline-none" %>
          </div>
          <button type="submit" data-property-filter-target="searchButton"
                  class="inline-flex items-center justify-center gap-1.5 w-24 h-10 text-sm font-medium rounded-md bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-400 text-white transition-colors focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-slate-900">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"/></svg>
            검색
          </button>
          <div class="hidden items-center gap-1.5 text-sm text-slate-500 dark:text-slate-400" data-property-filter-target="loading">
            <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            <span>검색 중...</span>
          </div>
        </div>
        <label class="inline-flex items-center gap-1.5 cursor-pointer select-none">
          <span class="text-sm text-slate-500 dark:text-slate-400">예산 범위 적용</span>
          <input type="hidden" name="within_budget" value="0">
          <%= check_box_tag :within_budget, "1", params[:within_budget] == "1",
              class: "sr-only peer",
              data: { property_filter_target: "budgetToggle", action: "change->property-filter#filter" } %>
          <span class="relative w-9 h-5 rounded-full bg-slate-200 dark:bg-slate-600 peer-checked:bg-blue-600 dark:peer-checked:bg-blue-500 peer-focus-visible:ring-2 peer-focus-visible:ring-blue-500/50 transition-colors duration-150 after:content-[''] after:absolute after:top-0.5 after:left-0.5 after:w-4 after:h-4 after:rounded-full after:bg-white after:shadow-sm after:transition-transform after:duration-150 peer-checked:after:translate-x-4"></span>
        </label>
      <% end %>
    </div>
  <% end %>

  <%# Property cards grid %>
  <div id="property-cards-grid" class="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
    <% @user_properties.each do |user_property| %>
      <div id="<%= dom_id(user_property.property, :card) %>">
        <%= render PropertyCardComponent.new(
          property: user_property.property,
          safety_rating: user_property.safety_rating,
          max_bid_amount: @max_bid_amount,
          analyzed: user_property.property.analyzed?
        ) %>
      </div>
    <% end %>
  </div>

  <% if @user_properties.empty? && filters_applied %>
    <%= render EmptyStateComponent.new(
      icon: "funnel",
      title: "검색 결과가 없습니다",
      description: "다른 검색어나 필터를 사용해보세요."
    ) %>
  <% elsif @user_properties.empty? %>
    <div id="user-properties-empty-state">
      <%= render EmptyStateComponent.new(
        icon: "magnifying-glass",
        title: "아직 추가한 물건이 없습니다",
        description: "사건번호를 입력하거나 물건 목록에서 검색하여 추가하세요."
      ) %>
    </div>
  <% end %>
</div>
```

변경점: 페이지 내 예산 박스(원본 5-21라인) 제거, 관심 지역/조건검색 블록(원본 23-49) 제거, criteria-search-results(원본 81-91) 제거, 사건번호 폼은 partial로 추출.

- [ ] **Step 5: 테스트 실행 — 통과 확인**

```bash
bin/rails test:system TEST=test/system/my_properties_test.rb
```
Expected: 통과

- [ ] **Step 6: 커밋**

```bash
git add app/views/properties/_case_number_form.html.erb app/views/properties/index.html.erb test/system/my_properties_test.rb
git commit -m "feat(properties): simplify 내 물건 page (drop search/budget moved elsewhere)"
```

---

## Task 11: 통합 system test — 카드 클릭 → 같은 페이지 머무름 + 배지 교체

**Files:**
- Modify: `test/system/property_search_test.rb`

- [ ] **Step 1: System 테스트 추가 (Red)**

`test/system/property_search_test.rb` 끝에 추가.

```ruby
test "검색 결과 카드 클릭 시 즉시 추가되고 같은 페이지에서 '이미 추가됨' 배지로 교체된다" do
  @user.search_results.create!(case_number: "2024타경5555", court_code: "B000210", court_name: "서울지법", address: "강남구 역삼동 1번지", appraisal_price: 100_000_000, min_bid_price: 80_000_000)

  visit search_path

  within "##{ActionView::RecordIdentifier.dom_id(@user.search_results.first, :inline)}" do
    assert_no_text "이미 추가됨"
    find("button[type='submit']").click
  end

  # 같은 페이지에 머무름 (URL 그대로)
  assert_current_path search_path

  # 카드가 "이미 추가됨" 상태로 교체됨
  within "##{ActionView::RecordIdentifier.dom_id(@user.search_results.first, :inline)}" do
    assert_text "이미 추가됨"
    assert_no_selector "button[type='submit']"
  end

  # user_property 실제 생성 확인
  assert @user.user_properties.joins(:property).where(properties: { case_number: "2024타경5555" }).exists?
end
```

- [ ] **Step 2: 테스트 실행 — 통과 확인**

(이미 Task 7, 8에서 구현 완료된 동작 검증)

```bash
bin/rails test:system TEST=test/system/property_search_test.rb -n /클릭 시 즉시 추가/
```
Expected: 통과

- [ ] **Step 3: 전체 테스트 스위트 실행**

```bash
bin/rails test
bin/rails test:system
```
Expected: 모두 통과 (regression 없음)

- [ ] **Step 4: 커밋**

```bash
git add test/system/property_search_test.rb
git commit -m "test: end-to-end inline_import flow on /search page"
```

---

## Task 12: 그래프 업데이트 + brakeman + rubocop

CLAUDE.md graphify 규칙: 코드 변경 후 그래프를 갱신한다.

- [ ] **Step 1: graphify 갱신**

```bash
graphify update .
```

- [ ] **Step 2: 정적 분석 / 린트**

```bash
bin/brakeman --no-pager
bin/rubocop -A
```
Expected: 경고 0건 (또는 자동 수정 후 클린)

- [ ] **Step 3: 자동 수정이 발생했다면 커밋**

```bash
git status
git add -A
git commit -m "chore: rubocop autofix after property list split"
```

---

## Verification Checklist (수동 — Task 12 직후 dev 서버에서)

- [ ] `bin/dev` 실행
- [ ] 사이드바에 "예산 설정 / 물건 목록 / 내 물건 / AI 분석" 순서로 노출되는지 확인
- [ ] 헤더 우측 상단(다크모드 토글 좌측)에 예산 박스가 보이는지
- [ ] `/search` 접속 → 관심 지역 + 조건검색만, 사건번호 폼 / 카드 그리드 없음 확인
- [ ] 조건검색 실행 → 결과 카드 클릭 → 즉시 "이미 추가됨" 배지로 교체, 페이지 머무름 확인
- [ ] 같은 카드 두 번째 클릭 시 form 자체가 없으니 클릭 불가 확인
- [ ] `/properties` 접속 → 사건번호 폼 + 필터 + 카드 그리드, 검색 영역 / 페이지 내 예산 박스 없음 확인
- [ ] `/properties` 에서 사건번호 입력 → 카드 그리드에 신규 카드 등장 확인

---

## Self-Review Notes

- **Spec coverage**: 라우트(Task 1, 3) / 사이드바(Task 1) / 컨트롤러 분리(Task 3, 5, 6, 9) / 뷰 분리(Task 4, 10) / 배지 분기(Task 7, 8) / 글로벌 헤더(Task 2) / 테스트(Task 4, 7, 10, 11) — spec의 모든 요구 커버됨
- **Type/method 일관성**: `dom_id(search_result, :inline)` 일관 사용. `existing_case_numbers`는 Set으로 일관. `already_added` 로컬명 일관
- **No placeholders**: 모든 코드 단계에 실제 코드 포함됨. partial path / 라우트 / 헬퍼명 모두 실제 코드 기반 검증됨
- **TDD 순서**: 각 Task가 Red → Green → Commit 흐름. 작은 커밋 단위 유지

## References

- Spec: `docs/superpowers/specs/2026-05-04-property-list-split-tech-design.md`
- 기존 코드:
  - `app/controllers/properties_controller.rb` (단순화 대상)
  - `app/controllers/search_results_controller.rb` (확장 대상)
  - `app/views/properties/index.html.erb` (분할 대상)
  - `app/components/sidebar/component.rb` (메뉴 추가)
  - `app/components/header/component.html.erb` (예산 indicator 삽입)
