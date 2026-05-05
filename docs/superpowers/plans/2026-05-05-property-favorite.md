# Property Favorite (즐겨찾기) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a star-shaped favorite toggle next to the "삭제" button on each "내 물건" card. Favorited items are sorted to the top on the next page load.

**Architecture:**
- Add `favorite` boolean to `user_properties` (sortable per-user state)
- New `FavoriteToggleComponent` rendered inside `PropertyCardComponent`
- `PATCH /properties/:id/toggle_favorite` returns Turbo Stream replacing only the toggle DOM node
- `UserProperty.ordered_for_list` scope handles `favorite DESC, created_at DESC`

**Tech Stack:** Rails 8, ViewComponent, Turbo, Tailwind, SQLite, Minitest

**Spec:** `docs/superpowers/specs/2026-05-05-property-favorite-design.md`

---

## File Structure

**Create:**
- `db/migrate/<timestamp>_add_favorite_to_user_properties.rb` — column + index
- `app/components/favorite_toggle_component.rb` — toggle button view
- `app/components/favorite_toggle_component.html.erb`
- `test/components/favorite_toggle_component_test.rb`

**Modify:**
- `app/models/user_property.rb` — add `ordered_for_list` scope
- `test/models/user_property_test.rb` — add scope test
- `config/routes.rb` — add `member { patch :toggle_favorite }` to `resources :properties`
- `app/controllers/properties_controller.rb` — add `toggle_favorite`, change `index` ordering
- `test/controllers/properties_controller_test.rb` — add `toggle_favorite` tests + ordering test
- `app/components/property_card_component.rb` — accept `user_property:` kwarg
- `app/components/property_card_component.html.erb` — layout refactor + render `FavoriteToggleComponent`
- `app/views/properties/index.html.erb` — pass `user_property:` to component
- `test/fixtures/user_properties.yml` — add a favorited fixture for ordering test

---

## Task 1: Migration + UserProperty.ordered_for_list scope

**Files:**
- Create: `db/migrate/<timestamp>_add_favorite_to_user_properties.rb`
- Modify: `app/models/user_property.rb`
- Modify: `test/models/user_property_test.rb`
- Modify: `test/fixtures/user_properties.yml`

- [ ] **Step 1: Generate migration**

```bash
bin/rails generate migration AddFavoriteToUserProperties favorite:boolean
```

- [ ] **Step 2: Edit the generated migration**

Replace its body with:

```ruby
class AddFavoriteToUserProperties < ActiveRecord::Migration[8.0]
  def change
    add_column :user_properties, :favorite, :boolean, default: false, null: false
    add_index :user_properties, [:user_id, :favorite, :created_at],
              name: "index_user_properties_on_user_favorite_created"
  end
end
```

(SQLite does not honor per-column `order:` on indexes — column order alone is sufficient for our query.)

- [ ] **Step 3: Run migration**

```bash
bin/rails db:migrate
```

Expected: migration runs, no error. Schema file updates.

- [ ] **Step 4: Add favorited fixture**

Edit `test/fixtures/user_properties.yml`. Append this fixture *after* `guest_unanalyzed_officetel`:

```yaml
guest_favorited_villa:
  user: guest
  property: risky_villa
  favorite: true
```

Then update the existing `guest_risky_villa` fixture to point to a different property OR delete it (it conflicts with the new fixture's `property: risky_villa` since `[user_id, property_id]` is unique).

Decision: delete `guest_risky_villa` and use `guest_favorited_villa` in its place. Search test files for `user_properties(:guest_risky_villa)` first:

```bash
grep -rn "guest_risky_villa" test/
```

If hits exist, replace each `user_properties(:guest_risky_villa)` with `user_properties(:guest_favorited_villa)`. Then delete the old fixture entry.

- [ ] **Step 5: Write failing model test**

Append to `test/models/user_property_test.rb` (before the closing `end`):

```ruby
test "favorite defaults to false" do
  up = UserProperty.new(user: users(:budget_user), property: properties(:unanalyzed_officetel))
  assert_equal false, up.favorite
end

test "ordered_for_list sorts favorites first, then by created_at desc" do
  user = users(:guest)
  results = user.user_properties.ordered_for_list.to_a

  favorited = results.select(&:favorite)
  non_favorited = results.reject(&:favorite)

  assert_equal results[0...favorited.size], favorited,
    "favorited items should appear first"
  assert_equal non_favorited.sort_by { |up| -up.created_at.to_i }, non_favorited,
    "non-favorited items should be ordered by created_at desc"
end
```

- [ ] **Step 6: Run test — expect failure**

```bash
bin/rails test test/models/user_property_test.rb -n /ordered_for_list/
```

Expected: FAIL with `NoMethodError: undefined method 'ordered_for_list'`

- [ ] **Step 7: Add scope to UserProperty**

Edit `app/models/user_property.rb`. Inside the class body, add:

```ruby
scope :ordered_for_list, -> { order(favorite: :desc, created_at: :desc) }
```

- [ ] **Step 8: Run test — expect pass**

```bash
bin/rails test test/models/user_property_test.rb
```

Expected: all tests pass.

- [ ] **Step 9: Commit**

```bash
git add db/migrate/ db/schema.rb app/models/user_property.rb \
        test/models/user_property_test.rb test/fixtures/user_properties.yml
git commit -m "feat(user_property): add favorite column + ordered_for_list scope"
```

---

## Task 2: Route + toggle_favorite controller action + index ordering

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/properties_controller.rb`
- Modify: `test/controllers/properties_controller_test.rb`

- [ ] **Step 1: Write failing request test**

Append to `test/controllers/properties_controller_test.rb` (before closing `end`):

```ruby
test "PATCH toggle_favorite flips favorite flag and returns turbo_stream" do
  property = user_properties(:guest_safe_apartment).property
  assert_equal false, user_properties(:guest_safe_apartment).favorite

  patch toggle_favorite_property_url(property),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

  assert_response :success
  assert_equal "text/vnd.turbo-stream.html", response.media_type
  assert_equal true, user_properties(:guest_safe_apartment).reload.favorite
end

test "PATCH toggle_favorite is idempotent on second call (toggles back)" do
  property = user_properties(:guest_safe_apartment).property

  patch toggle_favorite_property_url(property),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
  patch toggle_favorite_property_url(property),
        headers: { "Accept" => "text/vnd.turbo-stream.html" }

  assert_equal false, user_properties(:guest_safe_apartment).reload.favorite
end

test "PATCH toggle_favorite redirects on HTML format (Turbo fallback)" do
  property = user_properties(:guest_safe_apartment).property

  patch toggle_favorite_property_url(property)

  assert_redirected_to properties_path
end

test "PATCH toggle_favorite raises 404 for property not in user's list" do
  other_user = users(:budget_user)
  other_property = Property.create!(
    case_number: "9999타경99999", court_name: "테스트법원", address: "테스트"
  )

  assert_raises(ActiveRecord::RecordNotFound) do
    patch toggle_favorite_property_url(other_property)
  end
end

test "GET index returns favorited user_properties before non-favorited" do
  # guest_favorited_villa.favorite == true, others false
  get properties_url

  assert_response :success
  body = response.body
  favorited_pos = body.index(user_properties(:guest_favorited_villa).property.case_number)
  non_favorited_pos = body.index(user_properties(:guest_safe_apartment).property.case_number)
  assert favorited_pos < non_favorited_pos,
    "favorited card should appear before non-favorited in HTML"
end
```

- [ ] **Step 2: Run test — expect failure**

```bash
bin/rails test test/controllers/properties_controller_test.rb -n /toggle_favorite|favorited user_properties before/
```

Expected: FAIL with `NoMethodError: undefined method 'toggle_favorite_property_url'`

- [ ] **Step 3: Add route**

Edit `config/routes.rb`. Find the line:

```ruby
resources :properties, only: [ :index, :show, :create, :destroy ] do
```

Inside its block (above `resources :documents`), add:

```ruby
member do
  patch :toggle_favorite
end
```

- [ ] **Step 4: Add toggle_favorite action**

Edit `app/controllers/properties_controller.rb`. Add this action *after* `destroy` (before `private`):

```ruby
def toggle_favorite
  user_property = current_user.user_properties.find_by!(property_id: params[:id])
  user_property.update!(favorite: !user_property.favorite)

  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: turbo_stream.replace(
        helpers.dom_id(user_property, :favorite_toggle),
        FavoriteToggleComponent.new(user_property: user_property)
      )
    end
    format.html { redirect_to properties_path }
  end
end
```

- [ ] **Step 5: Change index ordering**

In the same file, find the `index` action's query (around line 4):

```ruby
@user_properties = current_user.user_properties.includes(property: :inspection_results).order(created_at: :desc)
```

Replace `.order(created_at: :desc)` with `.ordered_for_list`:

```ruby
@user_properties = current_user.user_properties.includes(property: :inspection_results).ordered_for_list
```

- [ ] **Step 6: Run controller test — expect partial pass**

```bash
bin/rails test test/controllers/properties_controller_test.rb -n /toggle_favorite/
```

Expected: tests pass for routing/redirect/404/idempotency. The turbo_stream test will FAIL because `FavoriteToggleComponent` doesn't exist yet — that's intentional, fixed in Task 3.

If only the turbo_stream test fails with `NameError: uninitialized constant FavoriteToggleComponent`, proceed.

- [ ] **Step 7: Commit (partial — completes after Task 3)**

```bash
git add config/routes.rb app/controllers/properties_controller.rb \
        test/controllers/properties_controller_test.rb
git commit -m "feat(properties): add toggle_favorite action + favorite-first ordering"
```

(The failing turbo_stream test will pass once Task 3 lands. Document this in the commit message if you prefer:)

```
The Turbo Stream branch references FavoriteToggleComponent which is
introduced in the next commit; the test currently fails on that line.
```

---

## Task 3: FavoriteToggleComponent

**Files:**
- Create: `app/components/favorite_toggle_component.rb`
- Create: `app/components/favorite_toggle_component.html.erb`
- Create: `test/components/favorite_toggle_component_test.rb`

- [ ] **Step 1: Write failing component test**

Create `test/components/favorite_toggle_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class FavoriteToggleComponentTest < ViewComponent::TestCase
  test "renders outline star + 즐겨찾기 추가 label when not favorited" do
    up = user_properties(:guest_safe_apartment) # favorite: false
    render_inline(FavoriteToggleComponent.new(user_property: up))

    assert_selector "button[aria-label='즐겨찾기 추가']"
    assert_selector "button[aria-pressed='false']"
    # Outline star: stroke without solid fill
    assert_selector "svg[data-favorite-state='off']"
  end

  test "renders solid star + 즐겨찾기 해제 label when favorited" do
    up = user_properties(:guest_favorited_villa) # favorite: true
    render_inline(FavoriteToggleComponent.new(user_property: up))

    assert_selector "button[aria-label='즐겨찾기 해제']"
    assert_selector "button[aria-pressed='true']"
    assert_selector "svg[data-favorite-state='on']"
  end

  test "wraps in dom_id for turbo replacement" do
    up = user_properties(:guest_safe_apartment)
    render_inline(FavoriteToggleComponent.new(user_property: up))

    assert_selector "##{ActionView::RecordIdentifier.dom_id(up, :favorite_toggle)}"
  end

  test "submits PATCH to toggle_favorite_property_path" do
    up = user_properties(:guest_safe_apartment)
    render_inline(FavoriteToggleComponent.new(user_property: up))

    assert_selector "form[action='#{Rails.application.routes.url_helpers.toggle_favorite_property_path(up.property)}']"
    assert_selector "input[name='_method'][value='patch']", visible: :all
  end
end
```

- [ ] **Step 2: Run test — expect failure**

```bash
bin/rails test test/components/favorite_toggle_component_test.rb
```

Expected: FAIL with `NameError: uninitialized constant FavoriteToggleComponent`

- [ ] **Step 3: Create component class**

Create `app/components/favorite_toggle_component.rb`:

```ruby
# frozen_string_literal: true

class FavoriteToggleComponent < ViewComponent::Base
  def initialize(user_property:)
    @user_property = user_property
  end

  private

  def favorited?
    @user_property.favorite
  end

  def aria_label
    favorited? ? "즐겨찾기 해제" : "즐겨찾기 추가"
  end

  def wrapper_id
    helpers.dom_id(@user_property, :favorite_toggle)
  end
end
```

- [ ] **Step 4: Create component template**

Create `app/components/favorite_toggle_component.html.erb`:

```erb
<div id="<%= wrapper_id %>" class="inline-flex">
  <%= button_to toggle_favorite_property_path(@user_property.property),
        method: :patch,
        aria: { label: aria_label, pressed: favorited? },
        class: "inline-flex items-center justify-center p-2 rounded-md transition-colors duration-150 #{favorited? ? "text-amber-400 hover:text-amber-500" : "text-slate-400 hover:text-amber-400"}" do %>
    <% if favorited? %>
      <svg data-favorite-state="on" class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24" aria-hidden="true">
        <path d="M12 2l2.9 6.9 7.1.6-5.4 4.7 1.7 7-6.3-3.8-6.3 3.8 1.7-7L2 9.5l7.1-.6L12 2z"/>
      </svg>
    <% else %>
      <svg data-favorite-state="off" class="w-5 h-5" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" d="M12 2l2.9 6.9 7.1.6-5.4 4.7 1.7 7-6.3-3.8-6.3 3.8 1.7-7L2 9.5l7.1-.6L12 2z"/>
      </svg>
    <% end %>
  <% end %>
</div>
```

- [ ] **Step 5: Run test — expect pass**

```bash
bin/rails test test/components/favorite_toggle_component_test.rb
```

Expected: all 4 tests pass.

- [ ] **Step 6: Re-run controller test from Task 2 — expect pass**

```bash
bin/rails test test/controllers/properties_controller_test.rb -n /toggle_favorite/
```

Expected: all toggle_favorite tests now pass (Turbo Stream branch can resolve `FavoriteToggleComponent`).

- [ ] **Step 7: Commit**

```bash
git add app/components/favorite_toggle_component.rb \
        app/components/favorite_toggle_component.html.erb \
        test/components/favorite_toggle_component_test.rb
git commit -m "feat(components): add FavoriteToggleComponent with star icon"
```

---

## Task 4a: PropertyCardComponent layout refactor (Tidy First — structural only)

**Files:**
- Modify: `app/components/property_card_component.html.erb`

This is a **structural** change only. No behavior change. Commit separately per Tidy First.

- [ ] **Step 1: Refactor the bottom section to flex layout**

Edit `app/components/property_card_component.html.erb`. Find the bottom section starting around line 60:

```erb
<div class="mt-3 pt-3 border-t border-slate-200 dark:border-slate-700">
  <%= button_to property_path(@property),
```

Wrap the existing `button_to ... end` in a flex container so the layout is ready for a sibling element on the right:

```erb
<div class="mt-3 pt-3 border-t border-slate-200 dark:border-slate-700 flex items-center justify-between">
  <%= button_to property_path(@property),
      method: :delete,
      aria: { label: "#{@property.case_number} 삭제" },
      data: {
        turbo_confirm: "이 물건을 내 목록에서 삭제합니다.\n\n저장된 분석 결과, 권리분석 보고서 등 모든 관련 데이터가 함께 삭제되며 복구할 수 없습니다.\n\n삭제하시겠습니까?"
      },
      class: "inline-flex items-center gap-1 py-2 text-sm text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300 transition-colors duration-150" do %>
    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4vM4 7h16"/>
    </svg>
    삭제
  <% end %>
</div>
```

(Only change: added `flex items-center justify-between` to the wrapper div. Inner content unchanged.)

- [ ] **Step 2: Run all PropertyCardComponent tests — expect all pass**

```bash
bin/rails test test/components/property_card_component_test.rb
```

Expected: all existing tests still pass (no behavior changed).

- [ ] **Step 3: Commit (structural)**

```bash
git add app/components/property_card_component.html.erb
git commit -m "refactor(property_card): use flex layout in footer section"
```

---

## Task 4b: Wire FavoriteToggleComponent into PropertyCardComponent

**Files:**
- Modify: `app/components/property_card_component.rb`
- Modify: `app/components/property_card_component.html.erb`
- Modify: `app/views/properties/index.html.erb`
- Modify: `test/components/property_card_component_test.rb`

- [ ] **Step 1: Write failing component test**

Append to `test/components/property_card_component_test.rb` (before closing `end`):

```ruby
test "renders FavoriteToggleComponent when user_property is given" do
  up = user_properties(:guest_safe_apartment)
  render_inline(PropertyCardComponent.new(property: up.property, user_property: up))
  assert_selector "##{ActionView::RecordIdentifier.dom_id(up, :favorite_toggle)}"
end

test "does not render FavoriteToggleComponent when user_property is nil" do
  property = properties(:safe_apartment)
  render_inline(PropertyCardComponent.new(property: property))
  assert_no_selector "[id$='_favorite_toggle']"
end
```

- [ ] **Step 2: Run test — expect failure**

```bash
bin/rails test test/components/property_card_component_test.rb -n /FavoriteToggleComponent/
```

Expected: FAIL with `ArgumentError: unknown keyword: :user_property`

- [ ] **Step 3: Add user_property kwarg**

Edit `app/components/property_card_component.rb`. Change the `initialize` signature:

```ruby
def initialize(property:, safety_rating: nil, max_bid_amount: nil, analyzed: false, user_property: nil)
  @property = property
  @safety_rating = safety_rating
  @max_bid_amount = max_bid_amount
  @analyzed = analyzed
  @user_property = user_property
end
```

- [ ] **Step 4: Render the toggle in the template**

Edit `app/components/property_card_component.html.erb`. In the flex container from Task 4a, add the favorite toggle render *after* the `button_to ... end` for delete:

```erb
<div class="mt-3 pt-3 border-t border-slate-200 dark:border-slate-700 flex items-center justify-between">
  <%= button_to property_path(@property), ... do %>
    ...
    삭제
  <% end %>

  <% if @user_property %>
    <%= render FavoriteToggleComponent.new(user_property: @user_property) %>
  <% end %>
</div>
```

- [ ] **Step 5: Update properties/index.html.erb to pass user_property**

Edit `app/views/properties/index.html.erb`. Find the render call (around line 57):

```erb
<%= render PropertyCardComponent.new(
  property: user_property.property,
  safety_rating: user_property.safety_rating,
  max_bid_amount: @max_bid_amount,
  analyzed: user_property.property.analyzed?
) %>
```

Add the `user_property:` kwarg:

```erb
<%= render PropertyCardComponent.new(
  property: user_property.property,
  safety_rating: user_property.safety_rating,
  max_bid_amount: @max_bid_amount,
  analyzed: user_property.property.analyzed?,
  user_property: user_property
) %>
```

- [ ] **Step 6: Run all component tests — expect pass**

```bash
bin/rails test test/components/property_card_component_test.rb test/components/favorite_toggle_component_test.rb
```

Expected: all pass.

- [ ] **Step 7: Run full controller test — expect pass**

```bash
bin/rails test test/controllers/properties_controller_test.rb
```

Expected: all pass, including the "favorited user_properties before non-favorited" test.

- [ ] **Step 8: Run full test suite to catch regressions**

```bash
bin/rails test
```

Expected: all green.

- [ ] **Step 9: Commit (behavioral)**

```bash
git add app/components/property_card_component.rb \
        app/components/property_card_component.html.erb \
        app/views/properties/index.html.erb \
        test/components/property_card_component_test.rb
git commit -m "feat(property_card): wire FavoriteToggleComponent into card footer"
```

---

## Task 5: Manual smoke test (browser verification)

UI changes — verify in a real browser before declaring done.

- [ ] **Step 1: Start dev server**

```bash
bin/dev
```

- [ ] **Step 2: Navigate to /properties (logged in or guest)**

Verify:
- Each card shows an outline star next to the "삭제" button
- Clicking the star changes it to a filled amber star (no full page reload — Turbo Stream)
- Clicking again toggles back to outline
- Refresh the page — favorited cards appear at the top of the grid
- Cards within "favorited" group preserve their relative add-order (newest first)
- Cards within "non-favorited" group preserve their relative add-order

- [ ] **Step 3: Verify in dark mode (the screenshot was dark theme)**

Toggle theme. Star contrast should remain visible (`text-slate-400` for off, `text-amber-400` for on).

- [ ] **Step 4: If all pass, no commit needed.** If any UI issue surfaces, fix and amend Task 4b's commit (or add a new commit).

---

## Self-Review Checklist (run after writing the plan, fix inline)

- ✅ Spec coverage:
  - Migration → Task 1
  - Scope → Task 1
  - Route → Task 2
  - Controller action with HTML fallback → Task 2
  - index ordering swap → Task 2
  - FavoriteToggleComponent → Task 3
  - PropertyCardComponent integration → Task 4b
  - Tidy First refactor split → Task 4a
  - All 4 test types from spec (model/request/component/index ordering) → Tasks 1, 2, 3
- ✅ No placeholders
- ✅ Type/method consistency: `ordered_for_list`, `toggle_favorite_property_path`, `dom_id(up, :favorite_toggle)` consistent across tasks
- ⚠️ Known partial-fail point: Task 2 commits with one failing test (Turbo Stream branch references not-yet-existing `FavoriteToggleComponent`). This is intentional and resolved in Task 3. Documented in the commit message.

---

## Out of Scope (carried from spec — do NOT implement)

- Immediate card re-ordering on toggle click
- Bulk favorite/unfavorite
- Favorite filter tab
- Favorite icon in search-results card (different component)
