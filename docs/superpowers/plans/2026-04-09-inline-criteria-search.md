# Inline Criteria Search Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a "조건검색" button to the properties index page that searches court auctions by the user's saved BudgetSetting criteria and displays results inline, with click-to-register functionality.

**Architecture:** Reuse existing `SearchResultsController#create` + `CourtAuctionSearchService` for the search backend. Add a new partial for inline results rendering. Use a Stimulus controller (`criteria-search`) to manage loading states and item click-to-register via Turbo Streams. The "조건검색" button POSTs to `SearchResultsController#create` which responds with a Turbo Stream that appends the results box.

**Tech Stack:** Rails 8.1, Hotwire (Turbo Streams + Stimulus), Tailwind CSS, Minitest

**Spec:** `docs/superpowers/specs/2026-04-09-inline-criteria-search-design.md`

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `app/views/search_results/_inline_results.html.erb` | Partial: results box with items |
| Create | `app/views/search_results/_inline_result_item.html.erb` | Partial: single result item (for Turbo Stream replacement) |
| Create | `app/javascript/controllers/criteria_search_controller.js` | Stimulus: loading state management |
| Modify | `app/controllers/search_results_controller.rb` | Add Turbo Stream response to `create`, add `inline_import` action |
| Modify | `app/views/properties/index.html.erb` | Add "조건검색" button + results container |
| Modify | `config/routes.rb` | Add `inline_import` member route |
| Create | `test/controllers/search_results_controller_inline_test.rb` | Tests for inline search + import |

---

### Task 1: Stimulus Controller for Loading State

**Files:**
- Create: `app/javascript/controllers/criteria_search_controller.js`

- [ ] **Step 1: Create the Stimulus controller**

```js
// app/javascript/controllers/criteria_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "buttonText", "buttonSpinner", "caseInput", "addButton"]

  submit() {
    this.disable()
  }

  disable() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    if (this.hasButtonTextTarget) this.buttonTextTarget.classList.add("hidden")
    if (this.hasButtonSpinnerTarget) this.buttonSpinnerTarget.classList.remove("hidden")
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = true
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = true
  }

  enable() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }
    if (this.hasButtonTextTarget) this.buttonTextTarget.classList.remove("hidden")
    if (this.hasButtonSpinnerTarget) this.buttonSpinnerTarget.classList.add("hidden")
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = false
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = false
  }
}
```

- [ ] **Step 2: Verify the controller is auto-registered**

Run: `ls app/javascript/controllers/criteria_search_controller.js`
Expected: file exists (Stimulus auto-discovers controllers via importmap/esbuild conventions in this project)

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/criteria_search_controller.js
git commit -m "feat: add criteria_search Stimulus controller for loading state"
```

---

### Task 2: Inline Result Item Partial

**Files:**
- Create: `app/views/search_results/_inline_result_item.html.erb`

- [ ] **Step 1: Create the result item partial**

This partial renders a single search result item. It accepts `search_result` and `already_added` local variables. Each item has a `dom_id` for Turbo Stream replacement after import.

```erb
<%# app/views/search_results/_inline_result_item.html.erb %>
<% added = local_assigns.fetch(:already_added, false) %>
<div id="<%= dom_id(search_result, :inline) %>"
     class="<%= added ? 'bg-slate-900 dark:bg-slate-900 border border-green-800 rounded-xl p-3 opacity-55' : 'bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl p-3 cursor-pointer hover:border-violet-500 dark:hover:border-violet-500 transition-colors' %>">
  <% if added %>
    <div class="flex items-center justify-between">
      <span class="text-sm font-semibold text-green-500">
        <%= search_result.case_number %>
        <span class="font-normal text-xs">✓ 추가됨</span>
      </span>
      <span class="text-xs text-slate-400">감정가 <strong class="text-slate-200 dark:text-slate-200"><%= format_price_won(search_result.appraisal_price) %></strong></span>
    </div>
    <div class="mt-1.5">
      <span class="text-xs text-slate-500">최저매각가 <span class="text-slate-400"><%= format_price_won(search_result.min_bid_price) %></span></span>
    </div>
    <div class="text-xs text-slate-500 mt-1 truncate">📍 <%= search_result.address %></div>
  <% else %>
    <%= form_with url: inline_import_search_result_path(search_result), method: :post, data: { turbo_stream: true } do %>
      <button type="submit" class="w-full text-left">
        <div class="flex items-center justify-between">
          <span class="text-sm font-semibold text-violet-400"><%= search_result.case_number %></span>
          <span class="text-xs text-slate-400">감정가 <strong class="text-slate-200 dark:text-slate-200"><%= format_price_won(search_result.appraisal_price) %></strong></span>
        </div>
        <div class="mt-1.5">
          <span class="text-xs text-slate-500">최저매각가 <span class="text-slate-400"><%= format_price_won(search_result.min_bid_price) %></span></span>
        </div>
        <div class="text-xs text-slate-500 mt-1 truncate">📍 <%= search_result.address %></div>
      </button>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 2: Commit**

```bash
git add app/views/search_results/_inline_result_item.html.erb
git commit -m "feat: add inline result item partial with added/clickable states"
```

---

### Task 3: Inline Results Box Partial

**Files:**
- Create: `app/views/search_results/_inline_results.html.erb`

- [ ] **Step 1: Create the results box partial**

This partial renders the full results container with header, items list, and empty state. It accepts `search_results` and `user_property_case_numbers` local variables.

```erb
<%# app/views/search_results/_inline_results.html.erb %>
<div id="criteria-search-results" class="bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-3.5 mt-3">
  <div class="flex items-center justify-between mb-3">
    <span class="text-sm font-semibold text-slate-900 dark:text-slate-100">
      조건검색 결과 <span class="text-violet-500"><%= search_results.size %>건</span>
    </span>
    <button type="button"
            data-action="click->criteria-search#closeResults"
            class="inline-flex items-center gap-1 border border-slate-300 dark:border-slate-600 text-slate-500 dark:text-slate-400 rounded-md px-2.5 py-1 text-xs hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors">
      ✕ 닫기
    </button>
  </div>

  <% if search_results.any? %>
    <div class="space-y-2">
      <% search_results.each do |sr| %>
        <%= render "search_results/inline_result_item",
                   search_result: sr,
                   already_added: user_property_case_numbers.include?(sr.case_number) %>
      <% end %>
    </div>
  <% else %>
    <p class="text-sm text-slate-500 dark:text-slate-400 text-center py-4">검색 결과가 없습니다.</p>
  <% end %>
</div>
```

- [ ] **Step 2: Add `closeResults` action to the Stimulus controller**

Add this method to `app/javascript/controllers/criteria_search_controller.js`:

```js
// app/javascript/controllers/criteria_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "buttonText", "buttonSpinner", "caseInput", "addButton", "resultsContainer"]

  submit() {
    this.disable()
  }

  closeResults() {
    if (this.hasResultsContainerTarget) {
      this.resultsContainerTarget.innerHTML = ""
    }
  }

  disable() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    if (this.hasButtonTextTarget) this.buttonTextTarget.classList.add("hidden")
    if (this.hasButtonSpinnerTarget) this.buttonSpinnerTarget.classList.remove("hidden")
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = true
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = true
  }

  enable() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }
    if (this.hasButtonTextTarget) this.buttonTextTarget.classList.remove("hidden")
    if (this.hasButtonSpinnerTarget) this.buttonSpinnerTarget.classList.add("hidden")
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = false
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = false
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add app/views/search_results/_inline_results.html.erb app/javascript/controllers/criteria_search_controller.js
git commit -m "feat: add inline results box partial with close functionality"
```

---

### Task 4: Update Properties Index View

**Files:**
- Modify: `app/views/properties/index.html.erb`

- [ ] **Step 1: Add the "조건검색" button and results container to the properties index**

Replace the case number input form section (lines 23-32 of `app/views/properties/index.html.erb`) with a version that includes the criteria search button and results container. The whole section is wrapped in a `data-controller="criteria-search"` div.

Replace this block:

```erb
  <%# Case number input form %>
  <%= form_with url: properties_path, method: :post, class: "max-w-md" do |f| %>
    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">사건번호로 물건 추가</label>
    <div class="flex items-center gap-2">
      <%= f.text_field :case_number,
          placeholder: "예: 2026타경1234",
          class: "flex-1 h-8 rounded-md border px-3 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100" %>
      <%= render ButtonComponent.new(type: "submit", icon: "plus", size: :sm) { "추가" } %>
    </div>
    <p class="text-sm text-slate-500 dark:text-slate-400 mt-1.5">법원 경매 사건번호를 입력하세요</p>
  <% end %>
```

With:

```erb
  <%# Case number input + criteria search %>
  <div data-controller="criteria-search" class="max-w-md">
    <%= form_with url: properties_path, method: :post do |f| %>
      <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">사건번호로 물건 추가</label>
      <div class="flex items-center gap-2">
        <%= f.text_field :case_number,
            placeholder: "예: 2026타경1234",
            data: { criteria_search_target: "caseInput" },
            class: "flex-1 h-8 rounded-md border px-3 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100" %>
        <%= render ButtonComponent.new(type: "submit", icon: "plus", size: :sm, data: { criteria_search_target: "addButton" }) { "추가" } %>
      </div>
    <% end %>
    <div class="flex items-center justify-between mt-1.5">
      <p class="text-sm text-slate-500 dark:text-slate-400">법원 경매 사건번호를 입력하세요</p>
      <%= form_with url: search_results_path, method: :post, data: { turbo_stream: true, action: "submit->criteria-search#submit turbo:submit-end->criteria-search#enable" } do %>
        <button type="submit"
                data-criteria-search-target="submitButton"
                class="inline-flex items-center justify-center gap-1.5 min-w-[100px] px-5 h-8 rounded-md bg-violet-600 hover:bg-violet-700 dark:bg-violet-600 dark:hover:bg-violet-500 text-white text-sm font-medium transition-colors focus-visible:ring-2 focus-visible:ring-violet-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-slate-900">
          <span data-criteria-search-target="buttonText">조건검색</span>
          <span data-criteria-search-target="buttonSpinner" class="hidden">
            <svg class="w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
              <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
              <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
            </svg>
            검색중...
          </span>
        </button>
      <% end %>
    </div>

    <%# Criteria search results appear here via Turbo Stream %>
    <div data-criteria-search-target="resultsContainer"></div>
  </div>
```

- [ ] **Step 2: Verify the page renders without errors**

Run: `bin/rails test test/controllers/properties_controller_test.rb`
Expected: all existing tests pass

- [ ] **Step 3: Commit**

```bash
git add app/views/properties/index.html.erb
git commit -m "feat: add criteria search button and results container to properties index"
```

---

### Task 5: Update SearchResultsController for Turbo Stream Responses

**Files:**
- Modify: `app/controllers/search_results_controller.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write the failing test for inline create (Turbo Stream response)**

Create `test/controllers/search_results_controller_inline_test.rb`:

```ruby
# test/controllers/search_results_controller_inline_test.rb
require "test_helper"

class SearchResultsControllerInlineTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @user = User.find_by(email: "guest@auction.local")
  end

  test "POST create with turbo_stream format returns turbo stream" do
    mock_response = { items: [], total: 0 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create with turbo_stream shows results in stream" do
    mock_items = [
      {
        "srnSaNo" => "2026타경99999",
        "jiwonNm" => "제주지방법원",
        "printSt" => "제주특별자치도 제주시 연동 123",
        "gamevalAmt" => "200000000",
        "minmaePrice" => "140000000",
        "dspslUsgNm" => "아파트",
        "mulJinYn" => "Y",
        "yuchalCnt" => "0",
        "maeGiil" => "2026-05-01",
        "mulBigo" => ""
      }
    ]
    mock_response = { items: mock_items, total: 1 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_match "2026타경99999", response.body
    assert_match "criteria-search-results", response.body
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create with turbo_stream shows error on failure" do
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| raise DataProvider::TimeoutError, "timeout" }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_match "시간이 초과", response.body
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST create with turbo_stream marks already-added properties" do
    # Create a property the user already has
    property = Property.find_by(case_number: "2026타경10001") || properties(:safe_apartment)
    @user.user_properties.find_or_create_by!(property: property)

    mock_items = [
      {
        "srnSaNo" => "2026타경10001",
        "jiwonNm" => "제주지방법원",
        "printSt" => "서울특별시 강남구",
        "gamevalAmt" => "300000000",
        "minmaePrice" => "210000000",
        "dspslUsgNm" => "아파트",
        "mulJinYn" => "Y",
        "yuchalCnt" => "1",
        "maeGiil" => "2026-05-01",
        "mulBigo" => ""
      }
    ]
    mock_response = { items: mock_items, total: 1 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_match "추가됨", response.body
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb`
Expected: FAIL — controller doesn't respond to turbo_stream format yet

- [ ] **Step 3: Add turbo_stream response to `SearchResultsController#create`**

Replace the `create` method in `app/controllers/search_results_controller.rb`:

```ruby
class SearchResultsController < ApplicationController
  def index
    @search_results = current_user.search_results.order(created_at: :desc)
  end

  def create
    result = CourtAuctionSearchService.call(user: current_user)

    respond_to do |format|
      format.html do
        if result.error
          redirect_to search_results_path, alert: error_message_for(result.error)
        else
          redirect_to search_results_path, notice: "#{result.count}건의 검색 결과를 가져왔습니다."
        end
      end
      format.turbo_stream do
        if result.error
          render turbo_stream: turbo_stream.update("criteria-search-results",
            partial: "search_results/inline_error",
            locals: { message: error_message_for(result.error) })
        else
          @search_results = current_user.search_results.order(created_at: :desc)
          @user_property_case_numbers = current_user.properties.pluck(:case_number)
          render turbo_stream: turbo_stream.update("criteria-search-results",
            partial: "search_results/inline_results",
            locals: { search_results: @search_results, user_property_case_numbers: @user_property_case_numbers })
        end
      end
    end
  end

  def import
    search_result = current_user.search_results.find(params[:id])
    case_number = search_result.case_number

    property = Property.find_by(case_number: case_number)
    if property
      current_user.user_properties.find_or_create_by!(property: property)
      redirect_to properties_path, notice: "물건이 내 목록에 추가되었습니다."
      return
    end

    result = PropertyDataSyncService.call(case_number: case_number, user: current_user)
    if result.property
      current_user.user_properties.create!(property: result.property)
      redirect_to properties_path, notice: "물건이 추가되었습니다."
    else
      error = result.errors[:court]
      redirect_to search_results_path, alert: error_message_for(error)
    end
  end

  def inline_import
    search_result = current_user.search_results.find(params[:id])
    case_number = search_result.case_number

    property = Property.find_by(case_number: case_number)
    if property
      current_user.user_properties.find_or_create_by!(property: property)
      render turbo_stream: turbo_stream.replace(
        dom_id(search_result, :inline),
        partial: "search_results/inline_result_item",
        locals: { search_result: search_result, already_added: true })
      return
    end

    result = PropertyDataSyncService.call(case_number: case_number, user: current_user)
    if result.property
      current_user.user_properties.create!(property: result.property)
      render turbo_stream: turbo_stream.replace(
        dom_id(search_result, :inline),
        partial: "search_results/inline_result_item",
        locals: { search_result: search_result, already_added: true })
    else
      error = result.errors[:court]
      render turbo_stream: turbo_stream.replace(
        dom_id(search_result, :inline),
        partial: "search_results/inline_result_item_error",
        locals: { search_result: search_result, message: error_message_for(error) })
    end
  end

  private

  def error_message_for(error)
    case error
    when DataProvider::TimeoutError
      "데이터 수집 시간이 초과되었습니다. 다시 시도해주세요."
    when DataProvider::ServiceUnavailableError, DataProvider::ConnectionError
      "법원경매 사이트에 접속할 수 없습니다. 잠시 후 다시 시도해주세요."
    when DataProvider::ConfigurationError
      "브라우저 실행에 실패했습니다. 시스템 설정을 확인해주세요."
    when DataProvider::DataNotFoundError, nil
      "해당 물건을 찾을 수 없습니다."
    else
      "데이터 수집 중 오류가 발생했습니다. 다시 시도해주세요."
    end
  end
end
```

- [ ] **Step 4: Create the inline error partial**

Create `app/views/search_results/_inline_error.html.erb`:

```erb
<%# app/views/search_results/_inline_error.html.erb %>
<div id="criteria-search-results" class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl p-3.5 mt-3">
  <div class="flex items-center justify-between">
    <span class="text-sm text-red-700 dark:text-red-300"><%= message %></span>
    <button type="button"
            data-action="click->criteria-search#closeResults"
            class="inline-flex items-center gap-1 border border-red-300 dark:border-red-700 text-red-500 dark:text-red-400 rounded-md px-2.5 py-1 text-xs hover:bg-red-100 dark:hover:bg-red-800 transition-colors">
      ✕ 닫기
    </button>
  </div>
</div>
```

- [ ] **Step 5: Create the inline result item error partial**

Create `app/views/search_results/_inline_result_item_error.html.erb`:

```erb
<%# app/views/search_results/_inline_result_item_error.html.erb %>
<div id="<%= dom_id(search_result, :inline) %>"
     class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-xl p-3">
  <div class="flex items-center justify-between">
    <span class="text-sm font-semibold text-red-600 dark:text-red-400"><%= search_result.case_number %></span>
    <span class="text-xs text-red-500 dark:text-red-400"><%= message %></span>
  </div>
</div>
```

- [ ] **Step 6: Add `inline_import` route**

In `config/routes.rb`, update the `search_results` resource:

```ruby
  resources :search_results, only: [ :index, :create ] do
    member do
      post :import
      post :inline_import
    end
  end
```

- [ ] **Step 7: Update the results container to use turbo stream target**

In `app/views/properties/index.html.erb`, update the results container div to include a `turbo-frame` id so `turbo_stream.update` can target it:

The `resultsContainer` target div should be:

```erb
    <%# Criteria search results appear here via Turbo Stream %>
    <div data-criteria-search-target="resultsContainer" id="criteria-search-results"></div>
```

- [ ] **Step 8: Run the tests**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb`
Expected: all 4 tests pass

- [ ] **Step 9: Run all existing tests to check for regressions**

Run: `bin/rails test test/controllers/search_results_controller_test.rb test/controllers/properties_controller_test.rb`
Expected: all tests pass (existing HTML responses unaffected)

- [ ] **Step 10: Commit**

```bash
git add app/controllers/search_results_controller.rb config/routes.rb app/views/search_results/_inline_error.html.erb app/views/search_results/_inline_result_item_error.html.erb app/views/properties/index.html.erb test/controllers/search_results_controller_inline_test.rb
git commit -m "feat: add turbo stream response for inline criteria search and import"
```

---

### Task 6: Test Inline Import Action

**Files:**
- Modify: `test/controllers/search_results_controller_inline_test.rb`

- [ ] **Step 1: Write failing tests for `inline_import`**

Add to `test/controllers/search_results_controller_inline_test.rb`:

```ruby
  test "POST inline_import adds property and returns turbo stream" do
    property = properties(:safe_apartment)
    # Remove existing user_property if any
    UserProperty.where(user: @user, property: property).destroy_all

    sr = @user.search_results.create!(
      case_number: property.case_number,
      address: "서울특별시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )

    assert_difference "UserProperty.count", 1 do
      post inline_import_search_result_url(sr), as: :turbo_stream
    end
    assert_response :success
    assert_includes response.content_type, "text/vnd.turbo-stream.html"
    assert_match "추가됨", response.body
  end

  test "POST inline_import for already-added property shows added state" do
    property = properties(:safe_apartment)
    @user.user_properties.find_or_create_by!(property: property)

    sr = @user.search_results.create!(
      case_number: property.case_number,
      address: "서울특별시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )

    assert_no_difference "UserProperty.count" do
      post inline_import_search_result_url(sr), as: :turbo_stream
    end
    assert_response :success
    assert_match "추가됨", response.body
  end
```

- [ ] **Step 2: Run the tests**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb`
Expected: all 6 tests pass (4 from Task 5 + 2 new)

- [ ] **Step 3: Commit**

```bash
git add test/controllers/search_results_controller_inline_test.rb
git commit -m "test: add inline import turbo stream tests"
```

---

### Task 7: Re-enable Button After Form Submission Completes

**Files:**
- Modify: `app/javascript/controllers/criteria_search_controller.js`
- Modify: `app/views/properties/index.html.erb`

- [ ] **Step 1: Use `turbo:submit-end` event to re-enable the button**

`turbo:submit-end` fires when any Turbo form submission completes, regardless of success or failure (network error, 500, timeout, etc.). This is safer than `turbo:before-stream-render` which only fires on successful Turbo Stream responses. We listen on the controller element (not `document`) so it only reacts to forms within this controller's scope.

Update the form in `app/views/properties/index.html.erb` to add `turbo:submit-end` action:

```erb
      <%= form_with url: search_results_path, method: :post, data: { turbo_stream: true, action: "submit->criteria-search#submit turbo:submit-end->criteria-search#enable" } do %>
```

- [ ] **Step 2: Remove `connect`/`disconnect` lifecycle hooks from Stimulus controller**

The final `criteria_search_controller.js` should be:

```js
// app/javascript/controllers/criteria_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submitButton", "buttonText", "buttonSpinner", "caseInput", "addButton", "resultsContainer"]

  submit() {
    this.disable()
  }

  closeResults() {
    if (this.hasResultsContainerTarget) {
      this.resultsContainerTarget.innerHTML = ""
    }
  }

  disable() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    if (this.hasButtonTextTarget) this.buttonTextTarget.classList.add("hidden")
    if (this.hasButtonSpinnerTarget) this.buttonSpinnerTarget.classList.remove("hidden")
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = true
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = true
  }

  enable() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }
    if (this.hasButtonTextTarget) this.buttonTextTarget.classList.remove("hidden")
    if (this.hasButtonSpinnerTarget) this.buttonSpinnerTarget.classList.add("hidden")
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = false
    if (this.hasAddButtonTarget) this.addButtonTarget.disabled = false
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/criteria_search_controller.js app/views/properties/index.html.erb
git commit -m "feat: use turbo:submit-end to re-enable criteria search button"
```

---

### Task 8: Full Integration Verification

- [ ] **Step 1: Run the full test suite**

Run: `bin/rails test`
Expected: all tests pass

- [ ] **Step 2: Run linting**

Run: `bin/rubocop`
Expected: no new offenses

- [ ] **Step 3: Run security check**

Run: `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`
Expected: no warnings or errors

- [ ] **Step 4: Fix any issues found in steps 1-3**

If any tests fail, lint errors, or security warnings — fix them before proceeding.

- [ ] **Step 5: Final commit (if fixes were needed)**

```bash
git add -A
git commit -m "fix: address lint/test/security issues from integration check"
```
