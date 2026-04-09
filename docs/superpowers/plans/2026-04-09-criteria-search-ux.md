# Criteria Search UX Improvements — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Improve criteria search results UX with multi-column grid, fade animations, better loading state, server-side filtering, and 20-result limit.

**Architecture:** Extend existing Turbo Stream + Stimulus architecture. Server-side changes filter out already-added properties and cap results at 20. Client-side changes replace blur overlay with pointer-events blocking, add fade-out/in Stimulus controllers for smooth item transitions between search results and property list.

**Tech Stack:** Rails 8.1, Turbo Streams, Stimulus (pure JS), TailwindCSS, ViewComponent

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `Gemfile` | Modify | Remove `pagy` gem |
| `config/initializers/pagy.rb` | Delete | No longer needed |
| `config/routes.rb` | Modify | Remove `inline_page` route |
| `app/controllers/application_controller.rb` | Modify | Remove `include Pagy::Backend` |
| `app/helpers/application_helper.rb` | Modify | Remove `include Pagy::Frontend` |
| `app/controllers/properties_controller.rb` | Modify | Remove Pagy usage, simplify search result loading |
| `app/controllers/search_results_controller.rb` | Modify | Exclude existing properties, limit 20, rewrite `inline_import` response, remove `inline_page` |
| `app/views/properties/index.html.erb` | Modify | Move results container outside max-w-md, add grid ID |
| `app/views/search_results/_inline_results.html.erb` | Modify | Remove close button, pagination; add grid layout, over-limit message |
| `app/views/search_results/_inline_result_item.html.erb` | Modify | Remove already-added state branch |
| `app/views/search_results/_inline_results_page.html.erb` | Delete | Pagination removed |
| `app/views/search_results/_inline_result_fade_out.html.erb` | Create | Fade-out wrapper for removed search items |
| `app/views/search_results/_inline_imported_card.html.erb` | Create | Fade-in wrapper for appended property cards |
| `app/javascript/controllers/criteria_search_controller.js` | Modify | Replace overlay with pointer-events-none/cursor-wait |
| `app/javascript/controllers/fade_remove_controller.js` | Create | Stimulus controller: fade-out + DOM removal |
| `app/javascript/controllers/fade_in_controller.js` | Create | Stimulus controller: fade-in on connect |
| `test/controllers/search_results_controller_inline_test.rb` | Modify | Update all tests for new behavior |

---

## Task 1: Remove Pagy gem and all Pagy references (structural cleanup)

This is a pure structural change — removes unused pagination infrastructure before adding new behavior.

**Files:**
- Modify: `Gemfile:50` (remove pagy line)
- Delete: `config/initializers/pagy.rb`
- Modify: `app/controllers/application_controller.rb:2` (remove `include Pagy::Backend`)
- Modify: `app/helpers/application_helper.rb:2` (remove `include Pagy::Frontend`)
- Modify: `config/routes.rb:51` (remove `get :inline_page`)
- Modify: `app/controllers/search_results_controller.rb:35-42` (remove `inline_page` action)
- Modify: `app/controllers/search_results_controller.rb:24-25` (remove Pagy from `create`)
- Modify: `app/controllers/properties_controller.rb:21-25` (remove Pagy from `index`)
- Delete: `app/views/search_results/_inline_results_page.html.erb`
- Modify: `app/views/search_results/_inline_results.html.erb` (remove pagination nav)
- Modify: `test/controllers/search_results_controller_inline_test.rb` (remove pagination test, update create test)

- [ ] **Step 1: Update test — remove pagination test, update create test to not expect pagy**

In `test/controllers/search_results_controller_inline_test.rb`, remove the `inline_page` test (lines 180-197) and update the "marks already-added properties" test since it will change later. Also remove the `inline_page` test entirely.

Replace the test at lines 180-197:
```ruby
  test "GET inline_page returns paginated search results" do
    12.times do |i|
      @user.search_results.create!(
        case_number: "2026타경#{70000 + i}",
        address: "서울특별시 #{i}",
        appraisal_price: 100_000_000 + i,
        min_bid_price: 70_000_000 + i
      )
    end

    get inline_page_search_results_url(search_page: 1)
    assert_response :success
    assert_match "inline-search-results-page", response.body

    get inline_page_search_results_url(search_page: 2)
    assert_response :success
    assert_match "inline-search-results-page", response.body
  end
```

With nothing (delete the test entirely).

- [ ] **Step 2: Run tests to confirm the pagination test is removed**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb`
Expected: Tests pass (except possibly the `inline_page` route is still present — that's fine, we're removing it next).

- [ ] **Step 3: Remove Pagy gem from Gemfile**

In `Gemfile`, remove line 50:
```ruby
gem "pagy", "~> 9.0"
```

- [ ] **Step 4: Run bundle install**

Run: `bundle install`
Expected: Bundle completes successfully without pagy.

- [ ] **Step 5: Delete pagy initializer**

Delete file: `config/initializers/pagy.rb`

- [ ] **Step 6: Remove Pagy includes from ApplicationController and ApplicationHelper**

In `app/controllers/application_controller.rb`, remove line 2:
```ruby
  include Pagy::Backend
```

In `app/helpers/application_helper.rb`, remove line 2:
```ruby
  include Pagy::Frontend
```

- [ ] **Step 7: Remove inline_page route**

In `config/routes.rb`, remove line 51 from the search_results collection block:
```ruby
      get :inline_page
```

So the collection block becomes:
```ruby
    collection do
      delete :clear
    end
```

- [ ] **Step 8: Remove inline_page action from SearchResultsController**

In `app/controllers/search_results_controller.rb`, remove the entire `inline_page` method (lines 35-42):
```ruby
  def inline_page
    search_results = current_user.search_results.order(created_at: :desc)
    @pagy, @search_results = pagy(search_results, limit: 10, page_param: :search_page)
    @user_property_case_numbers = current_user.properties.pluck(:case_number)

    render partial: "search_results/inline_results_page",
           locals: { search_results: @search_results, user_property_case_numbers: @user_property_case_numbers, pagy: @pagy }
  end
```

- [ ] **Step 9: Remove Pagy from SearchResultsController#create**

In `app/controllers/search_results_controller.rb`, replace lines 24-25:
```ruby
          search_results = current_user.search_results.order(created_at: :desc)
          @pagy, @search_results = pagy(search_results, limit: 10, page_param: :search_page)
```

With:
```ruby
          search_results = current_user.search_results.order(created_at: :desc)
```

And update the render call (line 27-29) to remove `pagy:` local:
```ruby
          render turbo_stream: turbo_stream.update("criteria-search-results",
            partial: "search_results/inline_results",
            locals: { search_results: search_results, user_property_case_numbers: @user_property_case_numbers })
```

- [ ] **Step 10: Remove Pagy from PropertiesController#index**

In `app/controllers/properties_controller.rb`, replace lines 21-25:
```ruby
    search_results = current_user.search_results.order(created_at: :desc)
    if search_results.exists?
      @pagy_search, @search_results = pagy(search_results, limit: 10, page_param: :search_page)
      @user_property_case_numbers = current_user.properties.pluck(:case_number)
    end
```

With:
```ruby
    @search_results = current_user.search_results.order(created_at: :desc)
    @user_property_case_numbers = current_user.properties.pluck(:case_number) if @search_results.exists?
```

- [ ] **Step 11: Delete pagination partial**

Delete file: `app/views/search_results/_inline_results_page.html.erb`

- [ ] **Step 12: Remove pagination from _inline_results.html.erb**

In `app/views/search_results/_inline_results.html.erb`, replace the entire file content with:
```erb
<%# app/views/search_results/_inline_results.html.erb %>
<div id="criteria-search-results" class="bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-3.5 mt-3">
  <div class="flex items-center justify-between mb-3">
    <span class="text-sm font-semibold text-slate-900 dark:text-slate-100">
      조건검색 결과 <span class="text-violet-500"><%= search_results.size %>건</span>
    </span>
    <%= button_to clear_search_results_path, method: :delete,
        class: "inline-flex items-center gap-1 border border-slate-300 dark:border-slate-600 text-slate-500 dark:text-slate-400 rounded-md px-2.5 py-1 text-xs hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors",
        data: { turbo_stream: true } do %>
      ✕ 닫기
    <% end %>
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

Note: This removes the `pagy` local variable usage, turbo_frame_tag wrapper, and pagination nav. The close button and `already_added` logic are still present — they will be removed in later tasks.

- [ ] **Step 13: Update index.html.erb to remove pagy local**

In `app/views/properties/index.html.erb`, replace lines 72-79:
```erb
    <%# Criteria search results — persisted from DB on load, updated via Turbo Stream %>
    <div id="criteria-search-results">
      <% if @search_results&.any? %>
        <%= render "search_results/inline_results",
                   search_results: @search_results,
                   user_property_case_numbers: @user_property_case_numbers,
                   pagy: @pagy_search %>
      <% end %>
    </div>
```

With:
```erb
    <%# Criteria search results — persisted from DB on load, updated via Turbo Stream %>
    <div id="criteria-search-results">
      <% if @search_results&.any? %>
        <%= render "search_results/inline_results",
                   search_results: @search_results,
                   user_property_case_numbers: @user_property_case_numbers %>
      <% end %>
    </div>
```

- [ ] **Step 14: Run all tests**

Run: `bin/rails test`
Expected: All tests pass. The removed pagination test is gone, and all other tests work without Pagy.

- [ ] **Step 15: Commit**

```bash
git add -A
git commit -m "refactor: remove Pagy gem and pagination from criteria search

Pagination is being replaced with a flat list (max 20 results).
Remove Pagy gem, initializer, inline_page action/route/partial,
and all Pagy includes from controllers and helpers.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Server-side — exclude existing properties and limit to 20

**Files:**
- Modify: `app/controllers/search_results_controller.rb` (create action)
- Modify: `app/controllers/properties_controller.rb` (index action)
- Modify: `app/views/search_results/_inline_results.html.erb` (over-limit message)
- Modify: `test/controllers/search_results_controller_inline_test.rb`

- [ ] **Step 1: Write failing test — existing properties excluded from search results**

In `test/controllers/search_results_controller_inline_test.rb`, replace the test "POST create with turbo_stream marks already-added properties" (lines 69-99) with:

```ruby
  test "POST create with turbo_stream excludes already-added properties" do
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
      },
      {
        "srnSaNo" => "2026타경10002",
        "jiwonNm" => "제주지방법원",
        "printSt" => "서울특별시 서초구",
        "gamevalAmt" => "400000000",
        "minmaePrice" => "280000000",
        "dspslUsgNm" => "아파트",
        "mulJinYn" => "Y",
        "yuchalCnt" => "0",
        "maeGiil" => "2026-06-01",
        "mulBigo" => ""
      }
    ]
    mock_response = { items: mock_items, total: 2 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_no_match "2026타경10001", response.body
    assert_match "2026타경10002", response.body
    assert_match "1건", response.body
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb -n "test_POST_create_with_turbo_stream_excludes_already-added_properties"`
Expected: FAIL — response still includes "2026타경10001" and shows "2건".

- [ ] **Step 3: Implement server-side exclusion in SearchResultsController#create**

In `app/controllers/search_results_controller.rb`, replace the turbo_stream success block. Change:
```ruby
          search_results = current_user.search_results.order(created_at: :desc)
          @user_property_case_numbers = current_user.properties.pluck(:case_number)
          render turbo_stream: turbo_stream.update("criteria-search-results",
            partial: "search_results/inline_results",
            locals: { search_results: search_results, user_property_case_numbers: @user_property_case_numbers })
```

To:
```ruby
          existing_case_numbers = current_user.properties.pluck(:case_number)
          search_results = current_user.search_results
            .where.not(case_number: existing_case_numbers)
            .order(created_at: :desc)
          total_count = search_results.count
          over_limit = total_count > 20
          search_results = search_results.limit(20)
          render turbo_stream: turbo_stream.update("criteria-search-results",
            partial: "search_results/inline_results",
            locals: { search_results: search_results, over_limit: over_limit })
```

- [ ] **Step 4: Update _inline_results.html.erb — remove user_property_case_numbers, add over_limit**

Replace the entire `_inline_results.html.erb` with:
```erb
<%# app/views/search_results/_inline_results.html.erb %>
<% over_limit = local_assigns.fetch(:over_limit, false) %>
<div id="criteria-search-results" class="bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-3.5 mt-3">
  <div class="flex items-center justify-between mb-3">
    <span class="text-sm font-semibold text-slate-900 dark:text-slate-100">
      조건검색 결과 <span class="text-violet-500"><%= search_results.size %>건</span>
      <% if over_limit %>
        <span class="text-xs font-normal text-amber-500 ml-1">최대 20건까지 조회됩니다</span>
      <% end %>
    </span>
    <%= button_to clear_search_results_path, method: :delete,
        class: "inline-flex items-center gap-1 border border-slate-300 dark:border-slate-600 text-slate-500 dark:text-slate-400 rounded-md px-2.5 py-1 text-xs hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors",
        data: { turbo_stream: true } do %>
      ✕ 닫기
    <% end %>
  </div>

  <% if search_results.any? %>
    <div class="space-y-2">
      <% search_results.each do |sr| %>
        <%= render "search_results/inline_result_item",
                   search_result: sr,
                   already_added: false %>
      <% end %>
    </div>
  <% else %>
    <p class="text-sm text-slate-500 dark:text-slate-400 text-center py-4">검색 결과가 없습니다.</p>
  <% end %>
</div>
```

Note: `already_added` is now always `false` since existing properties are excluded server-side. The close button is still here — removed in Task 3.

- [ ] **Step 5: Update PropertiesController#index to match**

In `app/controllers/properties_controller.rb`, replace:
```ruby
    @search_results = current_user.search_results.order(created_at: :desc)
    @user_property_case_numbers = current_user.properties.pluck(:case_number) if @search_results.exists?
```

With:
```ruby
    existing_case_numbers = current_user.properties.pluck(:case_number)
    @search_results = current_user.search_results
      .where.not(case_number: existing_case_numbers)
      .order(created_at: :desc)
      .limit(20)
```

And in `app/views/properties/index.html.erb`, update the render call to remove `user_property_case_numbers`:
```erb
    <div id="criteria-search-results">
      <% if @search_results&.any? %>
        <%= render "search_results/inline_results",
                   search_results: @search_results %>
      <% end %>
    </div>
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb -n "test_POST_create_with_turbo_stream_excludes_already-added_properties"`
Expected: PASS

- [ ] **Step 7: Write failing test — max 20 results with over-limit message**

Add this test to `test/controllers/search_results_controller_inline_test.rb`:

```ruby
  test "POST create with turbo_stream limits to 20 results and shows over-limit message" do
    mock_items = 25.times.map do |i|
      {
        "srnSaNo" => "2026타경#{60000 + i}",
        "jiwonNm" => "서울중앙지방법원",
        "printSt" => "서울특별시 #{i}구",
        "gamevalAmt" => "#{200_000_000 + i}",
        "minmaePrice" => "#{140_000_000 + i}",
        "dspslUsgNm" => "아파트",
        "mulJinYn" => "Y",
        "yuchalCnt" => "0",
        "maeGiil" => "2026-05-01",
        "mulBigo" => ""
      }
    end
    mock_response = { items: mock_items, total: 25 }
    adapter = Object.new
    adapter.define_singleton_method(:search_by_criteria) { |**_| mock_response }

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| adapter }

    post search_results_url, as: :turbo_stream
    assert_response :success
    assert_match "20건", response.body
    assert_match "최대 20건까지 조회됩니다", response.body
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end
```

- [ ] **Step 8: Run test to verify it passes**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb -n "test_POST_create_with_turbo_stream_limits_to_20_results_and_shows_over-limit_message"`
Expected: PASS (the implementation from Step 3 already handles this).

- [ ] **Step 9: Run all tests**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: exclude existing properties from search and limit to 20 results

Search results now filter out properties already in the user's list
(server-side WHERE NOT IN). Results are capped at 20 with an
over-limit message when more are available.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Layout — remove close button, multi-column grid, reposition results box

**Files:**
- Modify: `app/views/properties/index.html.erb`
- Modify: `app/views/search_results/_inline_results.html.erb`
- Modify: `app/views/search_results/_inline_result_item.html.erb`
- Modify: `test/controllers/search_results_controller_inline_test.rb`

- [ ] **Step 1: Update test — remove "추가됨" assertion, adjust index render test**

In `test/controllers/search_results_controller_inline_test.rb`:

The "POST create with turbo_stream shows results in stream" test (around line 25) asserts `assert_match "criteria-search-results", response.body` — this still holds.

Update the "properties index renders persisted search results on load" test to check for the grid class instead of turbo-frame:

Replace:
```ruby
  test "properties index renders persisted search results on load" do
    @user.search_results.create!(
      case_number: "2026타경55555",
      address: "부산광역시",
      appraisal_price: 150_000_000,
      min_bid_price: 105_000_000
    )

    get properties_url
    assert_response :success
    assert_match "2026타경55555", response.body
    assert_match "criteria-search-results", response.body
  end
```

With:
```ruby
  test "properties index renders persisted search results on load" do
    @user.search_results.create!(
      case_number: "2026타경55555",
      address: "부산광역시",
      appraisal_price: 150_000_000,
      min_bid_price: 105_000_000
    )

    get properties_url
    assert_response :success
    assert_match "2026타경55555", response.body
    assert_match "criteria-search-results", response.body
    assert_no_match "닫기", response.body
  end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb -n "test_properties_index_renders_persisted_search_results_on_load"`
Expected: FAIL — "닫기" is still present.

- [ ] **Step 3: Update _inline_results.html.erb — remove close button, add grid layout, add count ID**

Replace the entire `app/views/search_results/_inline_results.html.erb` with:
```erb
<%# app/views/search_results/_inline_results.html.erb %>
<% over_limit = local_assigns.fetch(:over_limit, false) %>
<div id="criteria-search-results" class="bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-xl p-3.5 mt-3">
  <div class="flex items-center gap-2 mb-3">
    <span class="text-sm font-semibold text-slate-900 dark:text-slate-100">
      조건검색 결과 <span id="criteria-search-count" class="text-violet-500"><%= search_results.size %>건</span>
    </span>
    <% if over_limit %>
      <span class="text-xs text-amber-500">최대 20건까지 조회됩니다</span>
    <% end %>
  </div>

  <% if search_results.any? %>
    <div class="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
      <% search_results.each do |sr| %>
        <%= render "search_results/inline_result_item", search_result: sr %>
      <% end %>
    </div>
  <% else %>
    <p class="text-sm text-slate-500 dark:text-slate-400 text-center py-4">검색 결과가 없습니다.</p>
  <% end %>
</div>
```

Key changes:
- Close button removed
- `id="criteria-search-count"` on count span (for Turbo Stream updates later)
- Grid layout: `grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4`
- `already_added` parameter removed from render call

- [ ] **Step 4: Simplify _inline_result_item.html.erb — remove already_added branch**

Replace the entire `app/views/search_results/_inline_result_item.html.erb` with:
```erb
<%# app/views/search_results/_inline_result_item.html.erb %>
<div id="<%= dom_id(search_result, :inline) %>"
     class="bg-slate-50 dark:bg-slate-900 border border-slate-200 dark:border-slate-700 rounded-xl p-3 cursor-pointer hover:border-violet-500 dark:hover:border-violet-500 transition-colors">
  <%= form_with url: inline_import_search_result_path(search_result), method: :post, data: { turbo_stream: true, turbo_frame: "_top" } do %>
    <button type="submit" class="w-full text-left">
      <div class="flex items-center justify-between">
        <span class="text-sm font-semibold text-violet-400">
          <%= search_result.case_number %>
          <% if search_result.property_count > 1 %>
            <span class="inline-flex items-center rounded bg-amber-900/30 px-1.5 py-0.5 text-xs font-medium text-amber-400">다물건 <%= search_result.property_count %>건</span>
          <% end %>
        </span>
        <span class="text-xs text-slate-400">감정가 <strong class="text-slate-200 dark:text-slate-200"><%= format_price_won(search_result.appraisal_price) %></strong></span>
      </div>
      <div class="mt-1.5">
        <span class="text-xs text-slate-500">최저매각가 <span class="text-slate-400"><%= format_price_won(search_result.min_bid_price) %></span></span>
      </div>
      <div class="text-xs text-slate-500 mt-1 truncate">📍 <%= search_result.address %></div>
    </button>
  <% end %>
</div>
```

- [ ] **Step 5: Move results container outside max-w-md in index.html.erb, add grid ID**

In `app/views/properties/index.html.erb`, the `criteria-search` div currently contains the results container. Move it outside.

Replace lines 22-80 (the entire criteria-search div and results container):
```erb
  <%# Case number input + criteria search %>
  <div data-controller="criteria-search" class="max-w-md">
    <div class="mb-4">
      <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">관심 지역</label>
      <div class="flex items-center gap-2">
        <select name="budget_setting[region]"
                class="flex-1 h-8 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500"
                data-controller="region-select"
                data-region-select-url-value="<%= update_region_settings_budget_path %>"
                data-action="change->region-select#save">
          <% BudgetSetting::REGIONS.each do |region| %>
            <option value="<%= region %>" <%= "selected" if region == @setting&.effective_region %>><%= region %></option>
          <% end %>
        </select>
        <span class="text-sm text-slate-500 dark:text-slate-400 transition-opacity duration-300 opacity-0" data-region-select-target="feedback"></span>
      </div>
    </div>
    <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">사건번호로 물건 추가</label>
    <div class="flex items-center gap-2">
      <%= form_with url: properties_path, method: :post, class: "contents", data: { action: "submit->criteria-search#submitCaseNumber" } do |f| %>
        <%= f.text_field :case_number,
            placeholder: "예: 2026타경1234",
            data: { criteria_search_target: "caseInput" },
            class: "flex-1 min-w-0 h-8 rounded-md border px-3 text-sm focus:ring-2 focus:ring-blue-500/20 focus:outline-none border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 text-slate-900 dark:text-slate-100" %>
        <button type="submit" data-criteria-search-target="addButton"
                class="inline-flex items-center justify-center h-8 px-3 text-sm font-medium rounded-md bg-blue-600 hover:bg-blue-700 dark:bg-blue-500 dark:hover:bg-blue-400 text-white transition-colors">
          <span data-criteria-search-target="addButtonText">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 4.5v15m7.5-7.5h-15"/></svg>
          </span>
          <svg data-criteria-search-target="addButtonSpinner" class="hidden w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        </button>
      <% end %>
      <%= form_with url: search_results_path, method: :post, class: "contents", data: { turbo_stream: true, action: "submit->criteria-search#submit turbo:submit-end->criteria-search#enable" } do %>
        <button type="submit"
                data-criteria-search-target="submitButton"
                class="inline-flex items-center justify-center gap-1.5 min-w-[100px] px-5 h-8 rounded-md bg-violet-600 hover:bg-violet-700 dark:bg-violet-600 dark:hover:bg-violet-500 text-white text-sm font-medium transition-colors focus-visible:ring-2 focus-visible:ring-violet-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-offset-slate-900">
          <span data-criteria-search-target="buttonText">조건검색</span>
          <svg data-criteria-search-target="buttonSpinner" class="hidden w-4 h-4 animate-spin" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        </button>
      <% end %>
    </div>
    <p class="text-sm text-slate-500 dark:text-slate-400 mt-1.5">법원 경매 사건번호를 입력하세요</p>
  </div>

  <%# Criteria search results — full-width, outside max-w-md %>
  <div id="criteria-search-results">
    <% if @search_results&.any? %>
      <%= render "search_results/inline_results",
                 search_results: @search_results %>
    <% end %>
  </div>
```

Note: The `</div>` for `criteria-search` now closes before the results container. The results container `#criteria-search-results` is now a sibling, not a child.

Also, add `id="property-cards-grid"` to the property cards grid div (line 120):
```erb
    <div id="property-cards-grid" class="grid gap-4 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4">
```

- [ ] **Step 6: Run test to verify it passes**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb -n "test_properties_index_renders_persisted_search_results_on_load"`
Expected: PASS — "닫기" is no longer in the response.

- [ ] **Step 7: Run all tests**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: multi-column grid layout, remove close button, reposition results box

Move criteria search results outside max-w-md container for full-width
display. Apply responsive grid (4/3/2/1 cols) matching property cards.
Remove close button and already-added state from result items.
Add id=property-cards-grid for Turbo Stream targeting.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Loading state — replace blur overlay with pointer-events-none

**Files:**
- Modify: `app/javascript/controllers/criteria_search_controller.js`

- [ ] **Step 1: Replace overlay methods with pointer-events approach**

Replace the entire `app/javascript/controllers/criteria_search_controller.js` with:

```javascript
// app/javascript/controllers/criteria_search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "submitButton", "buttonText", "buttonSpinner",
    "caseInput", "addButton", "addButtonText", "addButtonSpinner"
  ]

  connect() {
    this.handleSubmitStart = this.handleSubmitStart.bind(this)
    this.handleSubmitEnd = this.handleSubmitEnd.bind(this)
    this.element.addEventListener("turbo:submit-start", this.handleSubmitStart)
    this.element.addEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  disconnect() {
    this.element.removeEventListener("turbo:submit-start", this.handleSubmitStart)
    this.element.removeEventListener("turbo:submit-end", this.handleSubmitEnd)
  }

  handleSubmitStart() {
    this.element.classList.add("pointer-events-none", "cursor-wait")
  }

  handleSubmitEnd() {
    this.element.classList.remove("pointer-events-none", "cursor-wait")
    this.enable()
  }

  // Criteria search form submit
  submit() {
    this.disableAll()
    this.showSpinner("buttonText", "buttonSpinner")
  }

  // Case number form submit — use readOnly instead of disabled so value is submitted
  submitCaseNumber() {
    if (this.hasCaseInputTarget) this.caseInputTarget.readOnly = true
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = true
      this.addButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    this.showSpinner("addButtonText", "addButtonSpinner")
  }

  enable() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
      this.submitButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }
    this.hideSpinner("buttonText", "buttonSpinner")
    this.hideSpinner("addButtonText", "addButtonSpinner")
    if (this.hasCaseInputTarget) {
      this.caseInputTarget.disabled = false
      this.caseInputTarget.readOnly = false
    }
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = false
      this.addButtonTarget.classList.remove("opacity-50", "cursor-not-allowed")
    }
  }

  disableAll() {
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = true
      this.submitButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
    if (this.hasCaseInputTarget) this.caseInputTarget.disabled = true
    if (this.hasAddButtonTarget) {
      this.addButtonTarget.disabled = true
      this.addButtonTarget.classList.add("opacity-50", "cursor-not-allowed")
    }
  }

  showSpinner(textTarget, spinnerTarget) {
    const text = this[`has${this.capitalize(textTarget)}Target`] ? this[`${textTarget}Target`] : null
    const spinner = this[`has${this.capitalize(spinnerTarget)}Target`] ? this[`${spinnerTarget}Target`] : null
    if (text) text.classList.add("hidden")
    if (spinner) spinner.classList.remove("hidden")
  }

  hideSpinner(textTarget, spinnerTarget) {
    const text = this[`has${this.capitalize(textTarget)}Target`] ? this[`${textTarget}Target`] : null
    const spinner = this[`has${this.capitalize(spinnerTarget)}Target`] ? this[`${spinnerTarget}Target`] : null
    if (text) text.classList.remove("hidden")
    if (spinner) spinner.classList.add("hidden")
  }

  capitalize(str) {
    return str.charAt(0).toUpperCase() + str.slice(1)
  }
}
```

Changes:
- `handleSubmitStart`: replaced `showOverlay()` with `pointer-events-none` + `cursor-wait`
- `handleSubmitEnd`: replaced `hideOverlay()` with removing those classes
- Removed `showOverlay()` and `hideOverlay()` methods entirely

- [ ] **Step 2: Run all tests**

Run: `bin/rails test`
Expected: All tests pass (loading state is JS-only, no server test changes needed).

- [ ] **Step 3: Commit**

```bash
git add app/javascript/controllers/criteria_search_controller.js
git commit -m "feat: replace blur overlay with pointer-events-none loading state

Remove showOverlay/hideOverlay methods. During form submissions,
apply pointer-events-none and cursor-wait to the controller element
instead of rendering a semi-transparent backdrop-blur overlay.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Fade-out and fade-in Stimulus controllers

**Files:**
- Create: `app/javascript/controllers/fade_remove_controller.js`
- Create: `app/javascript/controllers/fade_in_controller.js`

- [ ] **Step 1: Create fade_remove_controller.js**

Create file `app/javascript/controllers/fade_remove_controller.js`:

```javascript
// app/javascript/controllers/fade_remove_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    requestAnimationFrame(() => {
      this.element.style.transition = "opacity 300ms ease-out, max-height 300ms ease-out"
      this.element.style.opacity = "0"
      this.element.style.maxHeight = "0"
      this.element.style.overflow = "hidden"
      this.element.addEventListener("transitionend", this.remove.bind(this), { once: true })
    })
  }

  remove() {
    this.element.remove()
  }
}
```

- [ ] **Step 2: Create fade_in_controller.js**

Create file `app/javascript/controllers/fade_in_controller.js`:

```javascript
// app/javascript/controllers/fade_in_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.style.opacity = "0"
    this.element.style.transition = "opacity 300ms ease-in"
    requestAnimationFrame(() => {
      this.element.style.opacity = "1"
    })
  }
}
```

- [ ] **Step 3: Run all tests to verify no regressions**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 4: Commit**

```bash
git add app/javascript/controllers/fade_remove_controller.js app/javascript/controllers/fade_in_controller.js
git commit -m "feat: add fade-remove and fade-in Stimulus controllers

fade-remove: on connect, transitions opacity to 0 and max-height to 0,
then removes element from DOM after transition completes.
fade-in: on connect, transitions opacity from 0 to 1.
Both use 300ms CSS transitions.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Inline import — Turbo Stream fade-out, append card, update count

**Files:**
- Create: `app/views/search_results/_inline_result_fade_out.html.erb`
- Create: `app/views/search_results/_inline_imported_card.html.erb`
- Modify: `app/controllers/search_results_controller.rb` (inline_import action)
- Modify: `test/controllers/search_results_controller_inline_test.rb`

- [ ] **Step 1: Write failing test — inline_import returns turbo stream with fade-out and card append**

In `test/controllers/search_results_controller_inline_test.rb`, replace the existing inline_import tests (the three tests starting from "POST inline_import adds property and redirects") with:

Replace:
```ruby
  test "POST inline_import adds property and redirects" do
    property = properties(:safe_apartment)
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
    assert_redirected_to properties_path
  end

  test "POST inline_import for already-added property redirects" do
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
    assert_redirected_to properties_path
  end

  test "POST inline_import falls back to search result data when detail fetch fails" do
    sr = @user.search_results.create!(
      case_number: "2026타경88888",
      address: "서울특별시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )

    error_adapter = Object.new
    error_adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
      raise DataProvider::DataNotFoundError, "not found"
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| error_adapter }

    assert_difference [ "Property.count", "UserProperty.count" ], 1 do
      post inline_import_search_result_url(sr), as: :turbo_stream
    end
    assert_redirected_to properties_path

    property = Property.find_by(case_number: "2026타경88888")
    assert_equal "서울특별시", property.address
    assert_equal 200_000_000, property.appraisal_price
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end
```

With:
```ruby
  test "POST inline_import returns turbo stream with fade-out and card append" do
    property = properties(:safe_apartment)
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
    assert_match "fade-remove", response.body
    assert_match "property-cards-grid", response.body
    assert_match "criteria-search-count", response.body
  end

  test "POST inline_import for already-added property returns turbo stream" do
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
    assert_match "fade-remove", response.body
  end

  test "POST inline_import falls back to search result data when detail fetch fails" do
    sr = @user.search_results.create!(
      case_number: "2026타경88888",
      address: "서울특별시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )

    error_adapter = Object.new
    error_adapter.define_singleton_method(:fetch_data_with_detail) do |case_number:|
      raise DataProvider::DataNotFoundError, "not found"
    end

    original_new = GovernmentCourtAuctionAdapter.method(:new)
    GovernmentCourtAuctionAdapter.define_singleton_method(:new) { |*_| error_adapter }

    assert_difference [ "Property.count", "UserProperty.count" ], 1 do
      post inline_import_search_result_url(sr), as: :turbo_stream
    end
    assert_response :success
    assert_match "fade-remove", response.body
    assert_match "property-cards-grid", response.body

    property = Property.find_by(case_number: "2026타경88888")
    assert_equal "서울특별시", property.address
    assert_equal 200_000_000, property.appraisal_price
  ensure
    GovernmentCourtAuctionAdapter.define_singleton_method(:new, original_new)
  end

  test "POST inline_import clears results box when last item is imported" do
    sr = @user.search_results.create!(
      case_number: "2026타경77777",
      address: "서울특별시",
      appraisal_price: 200_000_000,
      min_bid_price: 140_000_000
    )
    Property.find_or_create_by!(case_number: "2026타경77777") do |p|
      p.address = "서울특별시"
      p.appraisal_price = 200_000_000
      p.min_bid_price = 140_000_000
    end

    post inline_import_search_result_url(sr), as: :turbo_stream
    assert_response :success
    # When remaining count is 0, the entire results container should be cleared
    assert_match(/update.*criteria-search-results/, response.body)
  end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb -n "/inline_import/"`
Expected: FAIL — current `inline_import` returns redirect, not turbo stream.

- [ ] **Step 3: Create fade-out partial**

Create file `app/views/search_results/_inline_result_fade_out.html.erb`:
```erb
<%# app/views/search_results/_inline_result_fade_out.html.erb %>
<div id="<%= dom_id(search_result, :inline) %>"
     data-controller="fade-remove"
     class="bg-slate-50 dark:bg-slate-900 border border-green-600 rounded-xl p-3 overflow-hidden">
  <div class="flex items-center gap-2">
    <span class="text-sm font-semibold text-green-500">✓ <%= search_result.case_number %></span>
  </div>
</div>
```

- [ ] **Step 4: Create imported card partial**

Create file `app/views/search_results/_inline_imported_card.html.erb`:
```erb
<%# app/views/search_results/_inline_imported_card.html.erb %>
<div data-controller="fade-in">
  <%= render PropertyCardComponent.new(
    property: property,
    safety_rating: user_property.safety_rating,
    max_bid_amount: max_bid_amount
  ) %>
</div>
```

- [ ] **Step 5: Rewrite inline_import action in SearchResultsController**

In `app/controllers/search_results_controller.rb`, replace the entire `inline_import` method:

```ruby
  def inline_import
    search_result = current_user.search_results.find(params[:id])
    import_result = perform_import(search_result)

    if import_result[:success]
      property = import_result[:property]
      user_property = import_result[:user_property]
      existing_case_numbers = current_user.properties.pluck(:case_number)
      remaining_count = current_user.search_results
        .where.not(case_number: existing_case_numbers)
        .count

      streams = [
        turbo_stream.replace(
          dom_id(search_result, :inline),
          partial: "search_results/inline_result_fade_out",
          locals: { search_result: search_result }
        ),
        turbo_stream.append(
          "property-cards-grid",
          partial: "search_results/inline_imported_card",
          locals: { property: property, user_property: user_property, max_bid_amount: current_user.budget_setting&.max_bid_amount }
        )
      ]

      if remaining_count == 0
        streams << turbo_stream.update("criteria-search-results", "")
      else
        streams << turbo_stream.update("criteria-search-count", html: "#{remaining_count}건")
      end

      render turbo_stream: streams
    else
      render turbo_stream: turbo_stream.replace(
        dom_id(search_result, :inline),
        partial: "search_results/inline_result_item_error",
        locals: { search_result: search_result, message: error_message_for(import_result[:error]) })
    end
  end
```

- [ ] **Step 6: Update perform_import to return property and user_property**

In `app/controllers/search_results_controller.rb`, replace the `perform_import` private method:

```ruby
  def perform_import(search_result)
    case_number = search_result.case_number

    property = Property.find_by(case_number: case_number)
    if property
      user_property = current_user.user_properties.find_or_create_by!(property: property)
      return { success: true, property: property, user_property: user_property }
    end

    result = PropertyDataSyncService.call(case_number: case_number, user: current_user)
    if result.property
      result.property.update!(property_count: search_result.property_count) if search_result.property_count > 1
      user_property = current_user.user_properties.create!(property: result.property)
      { success: true, property: result.property, user_property: user_property }
    else
      Rails.logger.warn "[InlineImport] Detail fetch failed for #{case_number}, creating from search data"
      property = create_property_from_search_result(search_result)
      user_property = current_user.user_properties.create!(property: property)
      { success: true, property: property, user_property: user_property }
    end
  end
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb -n "/inline_import/"`
Expected: All 4 inline_import tests PASS.

- [ ] **Step 8: Run all tests**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: inline import returns Turbo Stream with fade-out and card append

Rewrite inline_import to return 3 Turbo Stream operations:
1. Replace search item with fade-out wrapper
2. Append PropertyCardComponent to property-cards-grid with fade-in
3. Update results count (or clear box when 0 remaining)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Remove clear action's close button dependency (cleanup)

The close button was removed from the UI in Task 3, but the `clear` action and route still exist. The `clear` action is still referenced by the close button's `button_to`. Since the button is gone, we can optionally keep the action for programmatic use or remove it. Since it's still useful (e.g., clearing stale results), keep the action but remove the route test that depends on the close button.

**Files:**
- Modify: `test/controllers/search_results_controller_inline_test.rb`

- [ ] **Step 1: Verify the clear test still passes**

Run: `bin/rails test test/controllers/search_results_controller_inline_test.rb -n "/clear/"`
Expected: PASS — the `clear` action still works via its route.

- [ ] **Step 2: Run the full test suite one final time**

Run: `bin/rails test`
Expected: All tests pass.

- [ ] **Step 3: Run rubocop**

Run: `bin/rubocop`
Expected: No new offenses. Fix any that appear.

- [ ] **Step 4: Run brakeman security check**

Run: `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`
Expected: No warnings.

- [ ] **Step 5: Final commit if any rubocop/brakeman fixes were needed**

Only commit if changes were made:
```bash
git add -A
git commit -m "fix: address rubocop/brakeman findings

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Summary

| Task | What | Type |
|------|------|------|
| 1 | Remove Pagy gem and all pagination | Structural (refactor) |
| 2 | Server-side exclusion + 20-result limit | Behavioral (feature) |
| 3 | Multi-column grid, remove close button, reposition | Behavioral (feature) |
| 4 | Loading state — pointer-events-none | Behavioral (feature) |
| 5 | Fade-out and fade-in Stimulus controllers | Structural (new files) |
| 6 | Inline import — Turbo Stream responses | Behavioral (feature) |
| 7 | Cleanup and verification | Structural (cleanup) |
