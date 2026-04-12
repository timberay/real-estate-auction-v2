# Property Deletion (Remove from My List) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a delete button to property cards that removes the property from the user's list and deletes all user-scoped analysis data.

**Architecture:** `button_to` with `data-turbo-confirm` on each property card triggers `PropertiesController#destroy`, which deletes user-scoped records in a transaction and responds with a Turbo Stream to remove the card from the DOM.

**Tech Stack:** Rails 8.1, Turbo Streams, ViewComponent, Minitest

**Spec:** `docs/superpowers/specs/2026-04-12-property-deletion-design.md`

---

### Task 1: Route and Controller — destroy action

**Files:**
- Modify: `config/routes.rb:46` — add `:destroy`
- Modify: `app/controllers/properties_controller.rb` — add `destroy` action

- [ ] **Step 1: Write failing test — successful deletion removes user-scoped data**

Add to `test/controllers/properties_controller_test.rb`:

```ruby
test "DELETE destroy removes user_property and user-scoped analysis data" do
  property = properties(:safe_apartment)
  user = User.find_by(email: "guest@auction.local")

  # Create user-scoped analysis data
  item = inspection_items(:building_structure)
  InspectionResult.create!(property: property, user: user, inspection_item: item, answer: "yes", source_type: :auto)
  RightsAnalysisReport.create!(property: property, user: user, analyzed_at: Time.current, report_data: "{}")
  LlmAnalysisLog.create!(property: property, user: user, system_prompt: "test", user_prompt: "test", status: :completed)

  assert_difference "UserProperty.count", -1 do
    delete property_url(property)
  end

  assert_not InspectionResult.exists?(property: property, user: user)
  assert_not RightsAnalysisReport.exists?(property: property, user: user)
  assert_not LlmAnalysisLog.exists?(property: property, user: user)
  assert Property.exists?(property.id), "Property record itself must be preserved"
  assert_redirected_to properties_path
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/controllers/properties_controller_test.rb -n "test_DELETE_destroy_removes_user_property_and_user-scoped_analysis_data"`

Expected: FAIL — route not found or action missing.

- [ ] **Step 3: Add `:destroy` to routes**

In `config/routes.rb`, change:

```ruby
resources :properties, only: [ :index, :show, :create ] do
```

to:

```ruby
resources :properties, only: [ :index, :show, :create, :destroy ] do
```

- [ ] **Step 4: Implement `destroy` action**

Add to `app/controllers/properties_controller.rb`:

```ruby
def destroy
  property = Property.find(params[:id])
  user_property = current_user.user_properties.find_by!(property: property)

  ActiveRecord::Base.transaction do
    InspectionResult.where(user: current_user, property: property).delete_all
    RightsAnalysisReport.where(user: current_user, property: property).delete_all
    LlmAnalysisLog.where(user: current_user, property: property).delete_all
    user_property.destroy!
  end

  respond_to do |format|
    format.turbo_stream { render turbo_stream: turbo_stream.remove(helpers.dom_id(property, :card)) }
    format.html { redirect_to properties_path, notice: "물건을 내 목록에서 삭제했습니다." }
  end
end
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bin/rails test test/controllers/properties_controller_test.rb -n "test_DELETE_destroy_removes_user_property_and_user-scoped_analysis_data"`

Expected: PASS

- [ ] **Step 6: Write failing test — Turbo Stream response**

Add to `test/controllers/properties_controller_test.rb`:

```ruby
test "DELETE destroy responds with turbo_stream to remove card" do
  property = properties(:safe_apartment)

  delete property_url(property), as: :turbo_stream

  assert_response :success
  assert_includes response.body, "turbo-stream"
  assert_includes response.body, "remove"
  assert_includes response.body, "card_property_#{property.id}"
end
```

- [ ] **Step 7: Run test to verify it passes**

Run: `bin/rails test test/controllers/properties_controller_test.rb -n "test_DELETE_destroy_responds_with_turbo_stream_to_remove_card"`

Expected: PASS (implementation already handles this format)

- [ ] **Step 8: Write failing test — cannot delete another user's property**

Add to `test/controllers/properties_controller_test.rb`:

```ruby
test "DELETE destroy returns 404 for property not in user list" do
  property = properties(:basement_villa)  # not in guest's list

  assert_raises(ActiveRecord::RecordNotFound) do
    delete property_url(property)
  end
end
```

- [ ] **Step 9: Run test to verify it passes**

Run: `bin/rails test test/controllers/properties_controller_test.rb -n "test_DELETE_destroy_returns_404_for_property_not_in_user_list"`

Expected: PASS (`find_by!` raises RecordNotFound)

- [ ] **Step 10: Commit**

```bash
git add config/routes.rb app/controllers/properties_controller.rb test/controllers/properties_controller_test.rb
git commit -m "feat: add destroy action to remove property from user list"
```

---

### Task 2: PropertyCardComponent — delete button UI

**Files:**
- Modify: `app/components/property_card_component.html.erb` — add delete button
- Modify: `app/views/properties/index.html.erb` — add DOM id to each card wrapper

- [ ] **Step 1: Add DOM id wrapper in index view**

In `app/views/properties/index.html.erb`, change the card rendering block from:

```erb
      <% @user_properties.each do |user_property| %>
        <%= render PropertyCardComponent.new(
          property: user_property.property,
          safety_rating: user_property.safety_rating,
          max_bid_amount: @max_bid_amount,
          analyzed: user_property.property.analyzed?
        ) %>
      <% end %>
```

to:

```erb
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
```

- [ ] **Step 2: Add delete button to PropertyCardComponent**

At the bottom of `app/components/property_card_component.html.erb`, just before the closing `<% end %>` of the CardComponent render block, add:

```erb
  <div class="mt-3 pt-3 border-t border-slate-200 dark:border-slate-700">
    <%= button_to property_path(@property),
        method: :delete,
        data: {
          turbo_confirm: "이 물건을 내 목록에서 삭제합니다.\n\n저장된 분석 결과, 권리분석 보고서 등 모든 관련 데이터가 함께 삭제되며 복구할 수 없습니다.\n\n삭제하시겠습니까?"
        },
        class: "inline-flex items-center gap-1 text-sm text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 transition-colors duration-150" do %>
      <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/>
      </svg>
      삭제
    <% end %>
  </div>
```

- [ ] **Step 3: Verify in browser**

Run: `bin/dev`

1. Open properties index page
2. Confirm each card shows a "삭제" button at the bottom
3. Click the button — confirm dialog appears with the warning message
4. Click "확인" — card is removed from the DOM without page reload
5. Refresh — the property is no longer in the list

- [ ] **Step 4: Commit**

```bash
git add app/components/property_card_component.html.erb app/views/properties/index.html.erb
git commit -m "feat: add delete button to property card with turbo confirm"
```
