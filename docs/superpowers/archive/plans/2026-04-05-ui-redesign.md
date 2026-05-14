# UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the entire application UI with App Shell layout (Header + Sidebar + Footer), ViewComponents, Tailwind CSS, dark mode, and Heroicons — per DESIGN.md spec.

**Architecture:** Bottom-Up approach. Install infrastructure gems first, then build reusable ViewComponents, then assemble the App Shell layout with Stimulus controllers, and finally redesign all existing views to use the new components.

**Tech Stack:** Rails 8.1, Tailwind CSS (tailwindcss-rails), ViewComponent, Heroicons (heroicon gem), Stimulus JS, Turbo

**Spec:** `docs/superpowers/specs/2026-04-05-ui-redesign-design.md`

**Design Reference:** `~/.claude/skills/rails-ui/DESIGN.md` and `~/.claude/skills/rails-ui/design_tokens.json`

---

## File Map

### New Files — Infrastructure
- `config/tailwind.config.js` — Tailwind config with darkMode, fonts, tokens
- `app/assets/stylesheets/application.tailwind.css` — Tailwind entry point
- `Procfile.dev` — Puma + Tailwind CSS watcher

### New Files — ViewComponents (Ruby + ERB pairs)
- `app/components/button_component.rb` + `.html.erb`
- `app/components/card_component.rb` + `.html.erb`
- `app/components/badge_component.rb` + `.html.erb`
- `app/components/input_component.rb` + `.html.erb`
- `app/components/select_component.rb` + `.html.erb`
- `app/components/toast_component.rb` + `.html.erb`
- `app/components/empty_state_component.rb` + `.html.erb`
- `app/components/stat_card_component.rb` + `.html.erb`
- `app/components/wizard_step_component.rb` + `.html.erb`
- `app/components/summary_table_component.rb` + `.html.erb`
- `app/components/snapshot_card_component.rb` + `.html.erb`
- `app/components/compare_table_component.rb` + `.html.erb`
- `app/components/header/component.rb` + `.html.erb`
- `app/components/sidebar/component.rb` + `.html.erb`

### New Files — Tests
- `test/components/button_component_test.rb`
- `test/components/card_component_test.rb`
- `test/components/badge_component_test.rb`
- `test/components/input_component_test.rb`
- `test/components/select_component_test.rb`
- `test/components/toast_component_test.rb`
- `test/components/empty_state_component_test.rb`
- `test/components/stat_card_component_test.rb`
- `test/components/wizard_step_component_test.rb`
- `test/components/summary_table_component_test.rb`
- `test/components/snapshot_card_component_test.rb`
- `test/components/compare_table_component_test.rb`
- `test/components/header/component_test.rb`
- `test/components/sidebar/component_test.rb`

### New Files — Stimulus Controllers
- `app/javascript/controllers/sidebar_controller.js`
- `app/javascript/controllers/dark_mode_controller.js`
- `app/javascript/controllers/dropdown_controller.js`
- `app/javascript/controllers/toast_controller.js`

### Modified Files
- `Gemfile` — add gems
- `app/views/layouts/application.html.erb` — full App Shell rewrite
- `app/views/home/index.html.erb` — redesign with components
- `app/views/onboardings/step1.html.erb` — redesign with components
- `app/views/onboardings/step2.html.erb` — redesign with components
- `app/views/onboardings/step3.html.erb` — redesign with components
- `app/views/onboardings/complete.html.erb` — redesign with components
- `app/views/settings/budgets/show.html.erb` — redesign with components
- `app/views/settings/budget_snapshots/index.html.erb` — redesign with components
- `app/views/settings/budget_snapshots/show.html.erb` — redesign with components
- `app/views/settings/budget_snapshots/compare.html.erb` — redesign with components
- `bin/dev` — update to use Procfile.dev
- `app/assets/stylesheets/application.css` — add Tailwind import or adjust for pipeline

---

## Task 1: Install Gems and Configure Tailwind CSS

**Files:**
- Modify: `Gemfile`
- Create: `config/tailwind.config.js`
- Create: `app/assets/stylesheets/application.tailwind.css`
- Create: `Procfile.dev`
- Modify: `bin/dev`
- Modify: `app/views/layouts/application.html.erb` (add Tailwind stylesheet link)

- [ ] **Step 1: Add gems to Gemfile**

Add these lines to `Gemfile`:

```ruby
gem "tailwindcss-rails"
gem "view_component"
gem "heroicon"

group :development, :test do
  gem "lookbook"
end
```

- [ ] **Step 2: Run bundle install**

Run: `bundle install`
Expected: Gems install successfully

- [ ] **Step 3: Run Tailwind installer**

Run: `bin/rails tailwindcss:install`
Expected: Creates `config/tailwind.config.js`, `app/assets/stylesheets/application.tailwind.css`, updates `Procfile.dev` and `bin/dev`

- [ ] **Step 4: Configure tailwind.config.js**

Replace `config/tailwind.config.js` with:

```javascript
const defaultTheme = require("tailwindcss/defaultTheme")

module.exports = {
  darkMode: "class",
  content: [
    "./public/*.html",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/views/**/*.{erb,haml,html,slim}",
    "./app/components/**/*.{rb,erb,html}",
  ],
  theme: {
    extend: {
      fontFamily: {
        sans: ["Pretendard", ...defaultTheme.fontFamily.sans],
        mono: ["JetBrains Mono", "Fira Code", ...defaultTheme.fontFamily.mono],
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    require("@tailwindcss/typography"),
  ],
}
```

- [ ] **Step 5: Configure application.tailwind.css**

Replace `app/assets/stylesheets/application.tailwind.css` with:

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  @font-face {
    font-family: "Pretendard";
    src: url("https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css");
  }
}
```

- [ ] **Step 6: Add Tailwind stylesheet link to layout**

In `app/views/layouts/application.html.erb`, add this line after the existing `stylesheet_link_tag`:

```erb
<%= stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload" %>
```

- [ ] **Step 7: Verify Tailwind builds**

Run: `bin/rails tailwindcss:build`
Expected: Tailwind CSS compiles without errors

- [ ] **Step 8: Commit**

```bash
git add Gemfile Gemfile.lock config/tailwind.config.js app/assets/stylesheets/application.tailwind.css Procfile.dev bin/dev app/views/layouts/application.html.erb
git commit -m "chore: install tailwindcss-rails, view_component, heroicon gems and configure Tailwind"
```

---

## Task 2: ButtonComponent

**Files:**
- Create: `app/components/button_component.rb`
- Create: `app/components/button_component.html.erb`
- Create: `test/components/button_component_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/components/button_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class ButtonComponentTest < ViewComponent::TestCase
  def test_renders_primary_button_with_text
    render_inline(ButtonComponent.new) { "저장하기" }

    assert_selector "button.bg-blue-600", text: "저장하기"
    assert_selector "button.font-medium"
  end

  def test_renders_secondary_variant
    render_inline(ButtonComponent.new(variant: :secondary)) { "취소" }

    assert_selector "button.bg-slate-100", text: "취소"
  end

  def test_renders_danger_variant
    render_inline(ButtonComponent.new(variant: :danger)) { "삭제" }

    assert_selector "button.bg-red-600", text: "삭제"
  end

  def test_renders_outline_variant
    render_inline(ButtonComponent.new(variant: :outline)) { "이전" }

    assert_selector "button.border"
  end

  def test_renders_ghost_variant
    render_inline(ButtonComponent.new(variant: :ghost)) { "더보기" }

    assert_no_selector "button.bg-blue-600"
  end

  def test_renders_link_variant
    render_inline(ButtonComponent.new(variant: :link)) { "링크" }

    assert_selector "button.underline-offset-4", text: "링크"
  end

  def test_renders_small_size
    render_inline(ButtonComponent.new(size: :sm)) { "작은 버튼" }

    assert_selector "button.px-3.py-1\\.5.text-xs"
  end

  def test_renders_large_size
    render_inline(ButtonComponent.new(size: :lg)) { "큰 버튼" }

    assert_selector "button.px-6.py-3.text-base"
  end

  def test_renders_disabled_state
    render_inline(ButtonComponent.new(disabled: true)) { "비활성" }

    assert_selector "button.opacity-50.cursor-not-allowed"
  end

  def test_renders_with_icon
    render_inline(ButtonComponent.new(icon: "plus")) { "추가하기" }

    assert_selector "button svg"
    assert_text "추가하기"
  end

  def test_renders_as_link_tag
    render_inline(ButtonComponent.new(tag: :a, href: "/path")) { "이동" }

    assert_selector "a[href='/path']", text: "이동"
  end

  def test_includes_focus_visible_ring
    render_inline(ButtonComponent.new) { "버튼" }

    assert_selector "button[class*='focus-visible:ring-2']"
  end

  def test_includes_dark_mode_classes
    render_inline(ButtonComponent.new) { "버튼" }

    assert_selector "button[class*='dark:']"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/button_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant ButtonComponent`

- [ ] **Step 3: Write ButtonComponent implementation**

Create `app/components/button_component.rb`:

```ruby
# frozen_string_literal: true

class ButtonComponent < ViewComponent::Base
  VARIANTS = {
    primary:   "bg-blue-600 hover:bg-blue-700 text-white dark:bg-blue-500 dark:hover:bg-blue-400",
    secondary: "bg-slate-100 hover:bg-slate-200 text-slate-700 dark:bg-slate-700 dark:hover:bg-slate-600 dark:text-slate-200",
    outline:   "border border-slate-200 hover:bg-slate-50 text-slate-700 dark:border-slate-600 dark:hover:bg-slate-700 dark:text-slate-200",
    danger:    "bg-red-600 hover:bg-red-700 text-white dark:bg-red-500 dark:hover:bg-red-400",
    ghost:     "hover:bg-slate-100 text-slate-600 dark:hover:bg-slate-700 dark:text-slate-300",
    link:      "text-blue-600 hover:text-blue-700 underline-offset-4 hover:underline dark:text-blue-400 dark:hover:text-blue-300"
  }.freeze

  SIZES = {
    sm: "px-3 py-1.5 text-xs gap-1.5",
    md: "px-4 py-2 text-sm gap-2",
    lg: "px-6 py-3 text-base gap-2"
  }.freeze

  ICON_SIZES = { sm: "w-4 h-4", md: "w-5 h-5", lg: "w-5 h-5" }.freeze

  def initialize(variant: :primary, size: :md, disabled: false, icon: nil, tag: :button, href: nil, **html_options)
    @variant = variant
    @size = size
    @disabled = disabled
    @icon = icon
    @tag = tag
    @href = href
    @html_options = html_options
  end

  def call
    content_tag(@tag, **tag_attributes) do
      safe_join([icon_element, content].compact)
    end
  end

  private

  def tag_attributes
    attrs = {
      class: component_classes,
      **@html_options
    }
    attrs[:href] = @href if @tag == :a
    attrs[:disabled] = true if @disabled && @tag == :button
    attrs
  end

  def component_classes
    [
      "inline-flex items-center justify-center font-medium rounded-md",
      "transition-colors duration-150",
      "focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2",
      "dark:focus-visible:ring-blue-400/50 dark:focus-visible:ring-offset-slate-900",
      VARIANTS.fetch(@variant),
      SIZES.fetch(@size),
      (@disabled ? "opacity-50 cursor-not-allowed pointer-events-none" : nil)
    ].compact.join(" ")
  end

  def icon_element
    return nil unless @icon

    heroicon @icon, variant: :outline, options: { class: ICON_SIZES.fetch(@size) }
  end
end
```

Create `app/components/button_component.html.erb` — not needed since we use `call` method directly. Skip this file.

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/button_component_test.rb`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/components/button_component.rb test/components/button_component_test.rb
git commit -m "feat: add ButtonComponent with 6 variants, 3 sizes, icon support, dark mode"
```

---

## Task 3: BadgeComponent

**Files:**
- Create: `app/components/badge_component.rb`
- Create: `test/components/badge_component_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/components/badge_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class BadgeComponentTest < ViewComponent::TestCase
  def test_renders_default_badge
    render_inline(BadgeComponent.new) { "기본" }

    assert_selector "span.bg-slate-100.text-slate-700", text: "기본"
    assert_selector "span.rounded-full.text-xs.font-medium"
  end

  def test_renders_success_badge
    render_inline(BadgeComponent.new(variant: :success)) { "완료" }

    assert_selector "span.bg-green-50.text-green-700"
  end

  def test_renders_warning_badge
    render_inline(BadgeComponent.new(variant: :warning)) { "주의" }

    assert_selector "span.bg-yellow-50.text-yellow-700"
  end

  def test_renders_danger_badge
    render_inline(BadgeComponent.new(variant: :danger)) { "위험" }

    assert_selector "span.bg-red-50.text-red-700"
  end

  def test_renders_info_badge
    render_inline(BadgeComponent.new(variant: :info)) { "정보" }

    assert_selector "span.bg-blue-50.text-blue-700"
  end

  def test_includes_dark_mode_classes
    render_inline(BadgeComponent.new(variant: :success)) { "완료" }

    assert_selector "span[class*='dark:']"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/badge_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant BadgeComponent`

- [ ] **Step 3: Write BadgeComponent implementation**

Create `app/components/badge_component.rb`:

```ruby
# frozen_string_literal: true

class BadgeComponent < ViewComponent::Base
  VARIANTS = {
    default: "bg-slate-100 text-slate-700 dark:bg-slate-700 dark:text-slate-300",
    success: "bg-green-50 text-green-700 ring-1 ring-inset ring-green-600/20 dark:bg-green-900/30 dark:text-green-400 dark:ring-green-400/20",
    warning: "bg-yellow-50 text-yellow-700 ring-1 ring-inset ring-yellow-600/20 dark:bg-yellow-900/30 dark:text-yellow-400 dark:ring-yellow-400/20",
    danger:  "bg-red-50 text-red-700 ring-1 ring-inset ring-red-600/20 dark:bg-red-900/30 dark:text-red-400 dark:ring-red-400/20",
    info:    "bg-blue-50 text-blue-700 ring-1 ring-inset ring-blue-600/20 dark:bg-blue-900/30 dark:text-blue-400 dark:ring-blue-400/20",
    accent:  "bg-amber-50 text-amber-700 ring-1 ring-inset ring-amber-600/20 dark:bg-amber-900/30 dark:text-amber-400 dark:ring-amber-400/20"
  }.freeze

  def initialize(variant: :default, **html_options)
    @variant = variant
    @html_options = html_options
  end

  def call
    tag.span(content, class: component_classes, **@html_options)
  end

  private

  def component_classes
    ["inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium", VARIANTS.fetch(@variant)].join(" ")
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/badge_component_test.rb`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/components/badge_component.rb test/components/badge_component_test.rb
git commit -m "feat: add BadgeComponent with 6 variants and dark mode"
```

---

## Task 4: CardComponent

**Files:**
- Create: `app/components/card_component.rb`
- Create: `app/components/card_component.html.erb`
- Create: `test/components/card_component_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/components/card_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class CardComponentTest < ViewComponent::TestCase
  def test_renders_card_with_body_content
    render_inline(CardComponent.new) { "본문 내용" }

    assert_selector "div.rounded-lg.bg-white.border.border-slate-200.shadow-sm"
    assert_selector "div.px-6.py-4", text: "본문 내용"
  end

  def test_renders_card_with_title
    render_inline(CardComponent.new(title: "카드 제목")) { "내용" }

    assert_selector "div.border-b h3.text-lg.font-semibold", text: "카드 제목"
  end

  def test_renders_card_with_title_and_description
    render_inline(CardComponent.new(title: "제목", description: "설명 텍스트")) { "내용" }

    assert_selector "h3", text: "제목"
    assert_selector "p.text-sm.text-slate-600", text: "설명 텍스트"
  end

  def test_renders_footer_slot
    render_inline(CardComponent.new(title: "제목")) do |card|
      card.with_footer { "푸터 내용" }
      "본문"
    end

    assert_selector "div.border-t", text: "푸터 내용"
  end

  def test_includes_dark_mode_classes
    render_inline(CardComponent.new) { "내용" }

    assert_selector "div[class*='dark:bg-slate-800']"
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/card_component_test.rb`
Expected: FAIL — `NameError: uninitialized constant CardComponent`

- [ ] **Step 3: Write CardComponent implementation**

Create `app/components/card_component.rb`:

```ruby
# frozen_string_literal: true

class CardComponent < ViewComponent::Base
  renders_one :footer

  def initialize(title: nil, description: nil, **html_options)
    @title = title
    @description = description
    @html_options = html_options
  end
end
```

Create `app/components/card_component.html.erb`:

```erb
<div class="rounded-lg bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 shadow-sm" <%= tag.attributes(**@html_options) %>>
  <% if @title %>
    <div class="px-6 py-4 border-b border-slate-200 dark:border-slate-700">
      <h3 class="text-lg font-semibold text-slate-900 dark:text-slate-100"><%= @title %></h3>
      <% if @description %>
        <p class="text-sm text-slate-600 dark:text-slate-400 mt-1"><%= @description %></p>
      <% end %>
    </div>
  <% end %>

  <div class="px-6 py-4">
    <%= content %>
  </div>

  <% if footer? %>
    <div class="px-6 py-4 border-t border-slate-100 dark:border-slate-700 bg-slate-50/50 dark:bg-slate-800/50">
      <%= footer %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/components/card_component_test.rb`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/components/card_component.rb app/components/card_component.html.erb test/components/card_component_test.rb
git commit -m "feat: add CardComponent with title, description, footer slot, dark mode"
```

---

## Task 5: InputComponent and SelectComponent

**Files:**
- Create: `app/components/input_component.rb`
- Create: `app/components/input_component.html.erb`
- Create: `app/components/select_component.rb`
- Create: `app/components/select_component.html.erb`
- Create: `test/components/input_component_test.rb`
- Create: `test/components/select_component_test.rb`

- [ ] **Step 1: Write failing tests for InputComponent**

Create `test/components/input_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class InputComponentTest < ViewComponent::TestCase
  def test_renders_input_with_label
    render_inline(InputComponent.new(label: "유용자금", name: "available_cash"))

    assert_selector "label", text: "유용자금"
    assert_selector "input[name='available_cash']"
  end

  def test_renders_required_mark
    render_inline(InputComponent.new(label: "필수 입력", name: "field", required: true))

    assert_selector "label span.text-red-500", text: "*"
  end

  def test_renders_suffix
    render_inline(InputComponent.new(label: "금액", name: "amount", suffix: "만원"))

    assert_text "만원"
  end

  def test_renders_error_state
    render_inline(InputComponent.new(label: "필드", name: "field", error: "필수 항목입니다"))

    assert_selector "input[class*='border-red-500']"
    assert_selector "p.text-red-600", text: "필수 항목입니다"
  end

  def test_renders_help_text
    render_inline(InputComponent.new(label: "필드", name: "field", help_text: "도움말"))

    assert_selector "p.text-slate-500", text: "도움말"
  end

  def test_includes_dark_mode_classes
    render_inline(InputComponent.new(label: "필드", name: "field"))

    assert_selector "input[class*='dark:']"
  end

  def test_passes_inputmode
    render_inline(InputComponent.new(label: "숫자", name: "num", inputmode: "numeric"))

    assert_selector "input[inputmode='numeric']"
  end
end
```

- [ ] **Step 2: Write failing tests for SelectComponent**

Create `test/components/select_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class SelectComponentTest < ViewComponent::TestCase
  def test_renders_select_with_label
    render_inline(SelectComponent.new(label: "유형", name: "type")) do |select|
      select.with_option(value: "1", label: "아파트")
      select.with_option(value: "2", label: "빌라")
    end

    assert_selector "label", text: "유형"
    assert_selector "select[name='type']"
    assert_selector "option[value='1']", text: "아파트"
    assert_selector "option[value='2']", text: "빌라"
  end

  def test_renders_prompt
    render_inline(SelectComponent.new(label: "선택", name: "sel", prompt: "선택하세요")) do |select|
      select.with_option(value: "1", label: "항목")
    end

    assert_selector "option[value='']", text: "선택하세요"
  end

  def test_renders_error_state
    render_inline(SelectComponent.new(label: "선택", name: "sel", error: "필수입니다")) do |select|
      select.with_option(value: "1", label: "항목")
    end

    assert_selector "select[class*='border-red-500']"
    assert_selector "p.text-red-600", text: "필수입니다"
  end

  def test_includes_dark_mode_classes
    render_inline(SelectComponent.new(label: "선택", name: "sel")) do |select|
      select.with_option(value: "1", label: "항목")
    end

    assert_selector "select[class*='dark:']"
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/components/input_component_test.rb test/components/select_component_test.rb`
Expected: FAIL — uninitialized constants

- [ ] **Step 4: Write InputComponent implementation**

Create `app/components/input_component.rb`:

```ruby
# frozen_string_literal: true

class InputComponent < ViewComponent::Base
  def initialize(label:, name:, type: "text", value: nil, required: false, error: nil, help_text: nil, suffix: nil, inputmode: nil, placeholder: nil, **html_options)
    @label = label
    @name = name
    @type = type
    @value = value
    @required = required
    @error = error
    @help_text = help_text
    @suffix = suffix
    @inputmode = inputmode
    @placeholder = placeholder
    @html_options = html_options
  end

  def input_classes
    base = "w-full rounded-md border px-3 py-2 text-sm text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 placeholder:text-slate-400 dark:placeholder:text-slate-500 transition-colors duration-150"
    if @error
      "#{base} border-red-500 focus:ring-red-500/20 focus:border-red-500"
    else
      "#{base} border-slate-200 dark:border-slate-600 focus:outline-none focus:ring-2 focus:ring-blue-500/20 dark:focus:ring-blue-400/20 focus:border-blue-500 dark:focus:border-blue-400"
    end
  end
end
```

Create `app/components/input_component.html.erb`:

```erb
<div>
  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
    <%= @label %>
    <% if @required %>
      <span class="text-red-500 ml-0.5">*</span>
    <% end %>
  </label>

  <% if @suffix %>
    <div class="flex items-center gap-2">
      <input type="<%= @type %>"
             name="<%= @name %>"
             value="<%= @value %>"
             class="<%= input_classes %>"
             placeholder="<%= @placeholder %>"
             <%= "inputmode=#{@inputmode}" if @inputmode %>
             <%= "required" if @required %>
             <%= tag.attributes(**@html_options) %>>
      <span class="text-slate-600 dark:text-slate-400 text-sm font-medium whitespace-nowrap"><%= @suffix %></span>
    </div>
  <% else %>
    <input type="<%= @type %>"
           name="<%= @name %>"
           value="<%= @value %>"
           class="<%= input_classes %>"
           placeholder="<%= @placeholder %>"
           <%= "inputmode=#{@inputmode}" if @inputmode %>
           <%= "required" if @required %>
           <%= tag.attributes(**@html_options) %>>
  <% end %>

  <% if @error %>
    <p class="text-sm text-red-600 dark:text-red-400 mt-1.5"><%= @error %></p>
  <% end %>

  <% if @help_text && !@error %>
    <p class="text-sm text-slate-500 dark:text-slate-400 mt-1.5"><%= @help_text %></p>
  <% end %>
</div>
```

- [ ] **Step 5: Write SelectComponent implementation**

Create `app/components/select_component.rb`:

```ruby
# frozen_string_literal: true

class SelectComponent < ViewComponent::Base
  renders_many :options, ->(value:, label:, selected: false) do
    OpenStruct.new(value: value, label: label, selected: selected)
  end

  def initialize(label:, name:, prompt: nil, error: nil, required: false, **html_options)
    @label = label
    @name = name
    @prompt = prompt
    @error = error
    @required = required
    @html_options = html_options
  end

  def select_classes
    base = "w-full rounded-md border px-3 py-2 text-sm text-slate-900 dark:text-slate-100 bg-white dark:bg-slate-700 transition-colors duration-150"
    if @error
      "#{base} border-red-500 focus:ring-red-500/20 focus:border-red-500"
    else
      "#{base} border-slate-200 dark:border-slate-600 focus:outline-none focus:ring-2 focus:ring-blue-500/20 dark:focus:ring-blue-400/20 focus:border-blue-500 dark:focus:border-blue-400"
    end
  end
end
```

Create `app/components/select_component.html.erb`:

```erb
<div>
  <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
    <%= @label %>
    <% if @required %>
      <span class="text-red-500 ml-0.5">*</span>
    <% end %>
  </label>

  <select name="<%= @name %>" class="<%= select_classes %>" <%= "required" if @required %> <%= tag.attributes(**@html_options) %>>
    <% if @prompt %>
      <option value=""><%= @prompt %></option>
    <% end %>
    <% options.each do |opt| %>
      <option value="<%= opt.value %>" <%= "selected" if opt.selected %>><%= opt.label %></option>
    <% end %>
  </select>

  <% if @error %>
    <p class="text-sm text-red-600 dark:text-red-400 mt-1.5"><%= @error %></p>
  <% end %>
</div>
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bin/rails test test/components/input_component_test.rb test/components/select_component_test.rb`
Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add app/components/input_component.rb app/components/input_component.html.erb app/components/select_component.rb app/components/select_component.html.erb test/components/input_component_test.rb test/components/select_component_test.rb
git commit -m "feat: add InputComponent and SelectComponent with error states, dark mode"
```

---

## Task 6: ToastComponent and EmptyStateComponent

**Files:**
- Create: `app/components/toast_component.rb`
- Create: `app/components/toast_component.html.erb`
- Create: `app/components/empty_state_component.rb`
- Create: `app/components/empty_state_component.html.erb`
- Create: `test/components/toast_component_test.rb`
- Create: `test/components/empty_state_component_test.rb`

- [ ] **Step 1: Write failing tests for ToastComponent**

Create `test/components/toast_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class ToastComponentTest < ViewComponent::TestCase
  def test_renders_success_toast
    render_inline(ToastComponent.new(type: :success, message: "저장되었습니다"))

    assert_text "저장되었습니다"
    assert_selector "[data-controller='toast']"
  end

  def test_renders_warning_toast
    render_inline(ToastComponent.new(type: :warning, message: "주의"))

    assert_text "주의"
  end

  def test_renders_danger_toast
    render_inline(ToastComponent.new(type: :danger, message: "오류 발생"))

    assert_text "오류 발생"
  end

  def test_renders_info_toast
    render_inline(ToastComponent.new(type: :info, message: "안내"))

    assert_text "안내"
  end

  def test_includes_close_button
    render_inline(ToastComponent.new(type: :success, message: "메시지"))

    assert_selector "button[data-action='toast#dismiss']"
  end

  def test_includes_dark_mode_classes
    render_inline(ToastComponent.new(type: :info, message: "테스트"))

    assert_selector "div[class*='dark:']"
  end
end
```

- [ ] **Step 2: Write failing tests for EmptyStateComponent**

Create `test/components/empty_state_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class EmptyStateComponentTest < ViewComponent::TestCase
  def test_renders_with_title_and_description
    render_inline(EmptyStateComponent.new(
      icon: "magnifying-glass",
      title: "물건이 없습니다",
      description: "검색 조건을 변경해 보세요"
    ))

    assert_text "물건이 없습니다"
    assert_text "검색 조건을 변경해 보세요"
    assert_selector "svg"
  end

  def test_renders_cta_button
    render_inline(EmptyStateComponent.new(
      icon: "clock",
      title: "스냅샷 없음",
      description: "아직 저장된 스냅샷이 없습니다",
      cta_text: "예산 설정하기",
      cta_href: "/settings/budget"
    ))

    assert_selector "a[href='/settings/budget']", text: "예산 설정하기"
  end

  def test_renders_without_cta
    render_inline(EmptyStateComponent.new(
      icon: "inbox",
      title: "비어 있음",
      description: "항목이 없습니다"
    ))

    assert_no_selector "a"
  end

  def test_includes_dark_mode_classes
    render_inline(EmptyStateComponent.new(icon: "inbox", title: "빈 상태", description: "설명"))

    assert_selector "div[class*='dark:']"
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/components/toast_component_test.rb test/components/empty_state_component_test.rb`
Expected: FAIL — uninitialized constants

- [ ] **Step 4: Write ToastComponent**

Create `app/components/toast_component.rb`:

```ruby
# frozen_string_literal: true

class ToastComponent < ViewComponent::Base
  ICONS = {
    success: { name: "check-circle", color: "text-green-500" },
    warning: { name: "exclamation-triangle", color: "text-amber-500" },
    danger:  { name: "x-circle", color: "text-red-500" },
    info:    { name: "information-circle", color: "text-blue-500" }
  }.freeze

  def initialize(type: :info, message:, duration: 5000)
    @type = type
    @message = message
    @duration = duration
  end

  def icon_config
    ICONS.fetch(@type)
  end
end
```

Create `app/components/toast_component.html.erb`:

```erb
<div data-controller="toast"
     data-toast-duration-value="<%= @duration %>"
     class="flex items-start gap-3 rounded-lg bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 shadow-lg px-4 py-3 min-w-80 max-w-md pointer-events-auto">
  <%= heroicon icon_config[:name], variant: :outline, options: { class: "flex-shrink-0 w-5 h-5 #{icon_config[:color]}" } %>
  <p class="text-sm text-slate-700 dark:text-slate-300 flex-1"><%= @message %></p>
  <button data-action="toast#dismiss"
          class="text-slate-400 hover:text-slate-600 dark:text-slate-500 dark:hover:text-slate-300 flex-shrink-0"
          aria-label="닫기">
    <%= heroicon "x-mark", variant: :outline, options: { class: "w-4 h-4" } %>
  </button>
</div>
```

- [ ] **Step 5: Write EmptyStateComponent**

Create `app/components/empty_state_component.rb`:

```ruby
# frozen_string_literal: true

class EmptyStateComponent < ViewComponent::Base
  def initialize(icon:, title:, description:, cta_text: nil, cta_href: nil)
    @icon = icon
    @title = title
    @description = description
    @cta_text = cta_text
    @cta_href = cta_href
  end
end
```

Create `app/components/empty_state_component.html.erb`:

```erb
<div class="flex flex-col items-center justify-center py-16 px-4">
  <%= heroicon @icon, variant: :outline, options: { class: "w-12 h-12 text-slate-300 dark:text-slate-600 mb-4" } %>
  <h3 class="text-lg font-semibold text-slate-700 dark:text-slate-300 mb-1"><%= @title %></h3>
  <p class="text-sm text-slate-500 dark:text-slate-400 text-center max-w-sm mb-6"><%= @description %></p>
  <% if @cta_text && @cta_href %>
    <%= render ButtonComponent.new(tag: :a, href: @cta_href, icon: "plus") { @cta_text } %>
  <% end %>
</div>
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bin/rails test test/components/toast_component_test.rb test/components/empty_state_component_test.rb`
Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add app/components/toast_component.rb app/components/toast_component.html.erb app/components/empty_state_component.rb app/components/empty_state_component.html.erb test/components/toast_component_test.rb test/components/empty_state_component_test.rb
git commit -m "feat: add ToastComponent and EmptyStateComponent with dark mode"
```

---

## Task 7: StatCardComponent, WizardStepComponent, SummaryTableComponent

**Files:**
- Create: `app/components/stat_card_component.rb` + `.html.erb`
- Create: `app/components/wizard_step_component.rb` + `.html.erb`
- Create: `app/components/summary_table_component.rb` + `.html.erb`
- Create: `test/components/stat_card_component_test.rb`
- Create: `test/components/wizard_step_component_test.rb`
- Create: `test/components/summary_table_component_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/components/stat_card_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class StatCardComponentTest < ViewComponent::TestCase
  def test_renders_stat_card
    render_inline(StatCardComponent.new(label: "최대 입찰가", value: "5,000만원"))

    assert_text "최대 입찰가"
    assert_text "5,000만원"
    assert_selector "div.bg-blue-600.text-white"
  end

  def test_renders_sublabel
    render_inline(StatCardComponent.new(label: "최대 입찰가", value: "15,000만원", sublabel: "(약 1.5억원)"))

    assert_text "(약 1.5억원)"
  end

  def test_renders_muted_variant
    render_inline(StatCardComponent.new(label: "감정가", value: "8,000만원", variant: :muted))

    assert_selector "div.bg-slate-50"
    assert_no_selector "div.bg-blue-600"
  end
end
```

Create `test/components/wizard_step_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class WizardStepComponentTest < ViewComponent::TestCase
  def test_renders_step_with_title
    render_inline(WizardStepComponent.new(title: "유용자금 입력", current_step: 1, total_steps: 3)) { "폼 내용" }

    assert_text "유용자금 입력"
    assert_text "폼 내용"
  end

  def test_renders_progress_bar
    render_inline(WizardStepComponent.new(title: "예비비 설정", current_step: 2, total_steps: 3)) { "내용" }

    assert_selector "[data-step]", count: 3
  end

  def test_renders_description
    render_inline(WizardStepComponent.new(title: "제목", description: "설명 텍스트", current_step: 1, total_steps: 3)) { "내용" }

    assert_text "설명 텍스트"
  end

  def test_wraps_in_max_width
    render_inline(WizardStepComponent.new(title: "제목", current_step: 1, total_steps: 3)) { "내용" }

    assert_selector "div.max-w-lg.mx-auto"
  end
end
```

Create `test/components/summary_table_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class SummaryTableComponentTest < ViewComponent::TestCase
  def test_renders_rows
    rows = [
      { label: "유용자금", value: "3,000만원" },
      { label: "수선비", value: "200만원" }
    ]
    render_inline(SummaryTableComponent.new(rows: rows))

    assert_text "유용자금"
    assert_text "3,000만원"
    assert_text "수선비"
    assert_text "200만원"
  end

  def test_renders_with_title
    render_inline(SummaryTableComponent.new(rows: [{ label: "항목", value: "값" }], title: "비용 내역"))

    assert_selector "h2", text: "비용 내역"
  end

  def test_renders_highlighted_row
    rows = [
      { label: "합계", value: "500만원", highlight: true }
    ]
    render_inline(SummaryTableComponent.new(rows: rows))

    assert_selector "div.bg-slate-50", text: "합계"
  end

  def test_includes_dark_mode_classes
    render_inline(SummaryTableComponent.new(rows: [{ label: "항목", value: "값" }]))

    assert_selector "div[class*='dark:']"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/stat_card_component_test.rb test/components/wizard_step_component_test.rb test/components/summary_table_component_test.rb`
Expected: FAIL — uninitialized constants

- [ ] **Step 3: Write StatCardComponent**

Create `app/components/stat_card_component.rb`:

```ruby
# frozen_string_literal: true

class StatCardComponent < ViewComponent::Base
  VARIANTS = {
    primary: { container: "bg-blue-600 dark:bg-blue-700 text-white rounded-xl p-6 text-center", label: "text-sm opacity-80 mb-1", value: "text-4xl font-bold mb-1", sublabel: "text-sm opacity-80" },
    muted: { container: "bg-slate-50 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg p-4", label: "text-sm text-slate-600 dark:text-slate-400", value: "text-2xl font-bold text-slate-900 dark:text-slate-100", sublabel: "text-sm text-slate-500 dark:text-slate-400" }
  }.freeze

  def initialize(label:, value:, sublabel: nil, variant: :primary)
    @label = label
    @value = value
    @sublabel = sublabel
    @variant_config = VARIANTS.fetch(variant)
  end
end
```

Create `app/components/stat_card_component.html.erb`:

```erb
<div class="<%= @variant_config[:container] %>">
  <p class="<%= @variant_config[:label] %>"><%= @label %></p>
  <p class="<%= @variant_config[:value] %>"><%= @value %></p>
  <% if @sublabel %>
    <p class="<%= @variant_config[:sublabel] %>"><%= @sublabel %></p>
  <% end %>
</div>
```

- [ ] **Step 4: Write WizardStepComponent**

Create `app/components/wizard_step_component.rb`:

```ruby
# frozen_string_literal: true

class WizardStepComponent < ViewComponent::Base
  def initialize(title:, current_step:, total_steps:, description: nil)
    @title = title
    @current_step = current_step
    @total_steps = total_steps
    @description = description
  end

  def step_class(step)
    if step < @current_step
      "bg-blue-600 dark:bg-blue-500"
    elsif step == @current_step
      "bg-blue-600 dark:bg-blue-500 ring-2 ring-blue-200 dark:ring-blue-800"
    else
      "bg-slate-200 dark:bg-slate-700"
    end
  end

  def connector_class(step)
    step < @current_step ? "bg-blue-600 dark:bg-blue-500" : "bg-slate-200 dark:bg-slate-700"
  end
end
```

Create `app/components/wizard_step_component.html.erb`:

```erb
<div class="max-w-lg mx-auto">
  <%# Progress bar %>
  <div class="flex items-center justify-center gap-2 mb-8">
    <% (1..@total_steps).each do |step| %>
      <div data-step="<%= step %>" class="w-3 h-3 rounded-full <%= step_class(step) %>"></div>
      <% if step < @total_steps %>
        <div class="w-8 h-0.5 <%= connector_class(step) %>"></div>
      <% end %>
    <% end %>
  </div>

  <%# Title %>
  <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100 mb-2"><%= @title %></h1>

  <% if @description %>
    <p class="text-sm text-slate-500 dark:text-slate-400 mb-6"><%= @description %></p>
  <% end %>

  <%# Content %>
  <%= content %>
</div>
```

- [ ] **Step 5: Write SummaryTableComponent**

Create `app/components/summary_table_component.rb`:

```ruby
# frozen_string_literal: true

class SummaryTableComponent < ViewComponent::Base
  def initialize(rows:, title: nil)
    @rows = rows
    @title = title
  end
end
```

Create `app/components/summary_table_component.html.erb`:

```erb
<div class="bg-white dark:bg-slate-800 border border-slate-200 dark:border-slate-700 rounded-lg overflow-hidden">
  <% if @title %>
    <h2 class="text-lg font-semibold p-4 bg-slate-50 dark:bg-slate-800/80 border-b border-slate-200 dark:border-slate-700 text-slate-900 dark:text-slate-100"><%= @title %></h2>
  <% end %>

  <div class="divide-y divide-slate-100 dark:divide-slate-700/50">
    <% @rows.each do |row| %>
      <div class="flex justify-between px-4 py-3 <%= 'bg-slate-50 dark:bg-slate-800/50 font-semibold' if row[:highlight] %>">
        <span class="text-slate-600 dark:text-slate-400 text-sm"><%= row[:label] %></span>
        <span class="font-medium text-sm text-slate-900 dark:text-slate-100 tabular-nums"><%= row[:value] %></span>
      </div>
    <% end %>
  </div>
</div>
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bin/rails test test/components/stat_card_component_test.rb test/components/wizard_step_component_test.rb test/components/summary_table_component_test.rb`
Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add app/components/stat_card_component.rb app/components/stat_card_component.html.erb app/components/wizard_step_component.rb app/components/wizard_step_component.html.erb app/components/summary_table_component.rb app/components/summary_table_component.html.erb test/components/stat_card_component_test.rb test/components/wizard_step_component_test.rb test/components/summary_table_component_test.rb
git commit -m "feat: add StatCardComponent, WizardStepComponent, SummaryTableComponent"
```

---

## Task 8: SnapshotCardComponent and CompareTableComponent

**Files:**
- Create: `app/components/snapshot_card_component.rb` + `.html.erb`
- Create: `app/components/compare_table_component.rb` + `.html.erb`
- Create: `test/components/snapshot_card_component_test.rb`
- Create: `test/components/compare_table_component_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/components/snapshot_card_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class SnapshotCardComponentTest < ViewComponent::TestCase
  def test_renders_snapshot_card
    render_inline(SnapshotCardComponent.new(
      version: 1,
      trigger: "onboarding",
      max_bid_amount: 5000,
      calculated_at: Time.zone.parse("2026-04-05 14:30"),
      show_path: "/settings/budget_snapshots/1",
      recalculate_path: "/settings/budget_snapshots/1/recalculate"
    ))

    assert_text "v1"
    assert_text "onboarding"
    assert_text "5,000만원"
  end

  def test_renders_trigger_badge
    render_inline(SnapshotCardComponent.new(
      version: 2, trigger: "manual_edit", max_bid_amount: 3000,
      calculated_at: Time.current, show_path: "#", recalculate_path: "#"
    ))

    assert_selector "span.rounded-full", text: "manual_edit"
  end

  def test_includes_action_links
    render_inline(SnapshotCardComponent.new(
      version: 1, trigger: "onboarding", max_bid_amount: 5000,
      calculated_at: Time.current, show_path: "/show", recalculate_path: "/recalc"
    ))

    assert_selector "a[href='/show']"
  end

  def test_includes_dark_mode_classes
    render_inline(SnapshotCardComponent.new(
      version: 1, trigger: "onboarding", max_bid_amount: 5000,
      calculated_at: Time.current, show_path: "#", recalculate_path: "#"
    ))

    assert_selector "div[class*='dark:']"
  end
end
```

Create `test/components/compare_table_component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class CompareTableComponentTest < ViewComponent::TestCase
  def test_renders_diff_table
    diff = [
      { label: "유용자금", was: "3,000", now: "4,000", delta: 1000 },
      { label: "수선비", was: "200", now: "150", delta: -50 }
    ]
    render_inline(CompareTableComponent.new(diff: diff))

    assert_text "유용자금"
    assert_text "3,000"
    assert_text "4,000"
    assert_selector "span.text-green-600", text: "+1,000"
    assert_selector "span.text-red-600"
  end

  def test_renders_header_row
    render_inline(CompareTableComponent.new(diff: [{ label: "항목", was: "1", now: "2", delta: 1 }]))

    assert_text "항목"
    assert_text "기존"
    assert_text "변경"
    assert_text "차이"
  end

  def test_includes_dark_mode_classes
    render_inline(CompareTableComponent.new(diff: [{ label: "항목", was: "1", now: "2", delta: 1 }]))

    assert_selector "div[class*='dark:']"
  end
end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bin/rails test test/components/snapshot_card_component_test.rb test/components/compare_table_component_test.rb`
Expected: FAIL — uninitialized constants

- [ ] **Step 3: Write SnapshotCardComponent**

Create `app/components/snapshot_card_component.rb`:

```ruby
# frozen_string_literal: true

class SnapshotCardComponent < ViewComponent::Base
  TRIGGER_VARIANTS = {
    "onboarding" => :info,
    "manual_edit" => :success,
    "recalculate" => :warning
  }.freeze

  def initialize(version:, trigger:, max_bid_amount:, calculated_at:, show_path:, recalculate_path:)
    @version = version
    @trigger = trigger
    @max_bid_amount = max_bid_amount
    @calculated_at = calculated_at
    @show_path = show_path
    @recalculate_path = recalculate_path
  end

  def badge_variant
    TRIGGER_VARIANTS.fetch(@trigger, :default)
  end

  def formatted_amount
    ActiveSupport::NumberHelper.number_to_delimited(@max_bid_amount)
  end

  def formatted_date
    @calculated_at&.strftime("%Y-%m-%d %H:%M")
  end
end
```

Create `app/components/snapshot_card_component.html.erb`:

```erb
<div class="border border-slate-200 dark:border-slate-700 rounded-lg p-4 bg-white dark:bg-slate-800 hover:bg-slate-50 dark:hover:bg-slate-700/50 transition-colors">
  <div class="flex justify-between items-start">
    <div>
      <div class="flex items-center gap-2 mb-1">
        <span class="text-sm font-medium text-slate-500 dark:text-slate-400">v<%= @version %></span>
        <%= render BadgeComponent.new(variant: badge_variant) { @trigger } %>
      </div>
      <% if @max_bid_amount %>
        <p class="text-lg font-bold text-slate-900 dark:text-slate-100 mt-1">최대입찰가: <%= formatted_amount %>만원</p>
      <% end %>
      <p class="text-xs text-slate-400 dark:text-slate-500 mt-1"><%= formatted_date %></p>
    </div>
    <div class="flex gap-2">
      <%= render ButtonComponent.new(variant: :ghost, size: :sm, tag: :a, href: @show_path, icon: "eye") { "보기" } %>
      <%= render ButtonComponent.new(variant: :ghost, size: :sm, tag: :a, href: @recalculate_path, icon: "arrow-path", data: { turbo_method: :post }) { "재계산" } %>
    </div>
  </div>
</div>
```

- [ ] **Step 4: Write CompareTableComponent**

Create `app/components/compare_table_component.rb`:

```ruby
# frozen_string_literal: true

class CompareTableComponent < ViewComponent::Base
  def initialize(diff:)
    @diff = diff
  end

  def format_delta(delta)
    return "-" if delta.nil?

    formatted = ActiveSupport::NumberHelper.number_to_delimited(delta.abs)
    delta > 0 ? "+#{formatted}" : "-#{formatted}"
  end

  def delta_class(delta)
    return "text-slate-400" if delta.nil?

    delta > 0 ? "text-green-600 dark:text-green-400" : "text-red-600 dark:text-red-400"
  end
end
```

Create `app/components/compare_table_component.html.erb`:

```erb
<div class="border border-slate-200 dark:border-slate-700 rounded-lg overflow-hidden">
  <%# Header %>
  <div class="grid grid-cols-4 bg-slate-50 dark:bg-slate-800/80">
    <div class="px-4 py-3 text-sm font-medium text-slate-700 dark:text-slate-300">항목</div>
    <div class="px-4 py-3 text-sm font-medium text-slate-700 dark:text-slate-300 text-right">기존</div>
    <div class="px-4 py-3 text-sm font-medium text-slate-700 dark:text-slate-300 text-right">변경</div>
    <div class="px-4 py-3 text-sm font-medium text-slate-700 dark:text-slate-300 text-right">차이</div>
  </div>

  <%# Rows %>
  <% @diff.each do |row| %>
    <div class="grid grid-cols-4 border-t border-slate-100 dark:border-slate-700/50">
      <div class="px-4 py-3 text-sm text-slate-600 dark:text-slate-400"><%= row[:label] %></div>
      <div class="px-4 py-3 text-sm text-right font-medium text-slate-700 dark:text-slate-300 tabular-nums"><%= row[:was] %></div>
      <div class="px-4 py-3 text-sm text-right font-medium text-slate-700 dark:text-slate-300 tabular-nums"><%= row[:now] %></div>
      <div class="px-4 py-3 text-sm text-right font-medium tabular-nums">
        <span class="<%= delta_class(row[:delta]) %>"><%= format_delta(row[:delta]) %></span>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `bin/rails test test/components/snapshot_card_component_test.rb test/components/compare_table_component_test.rb`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add app/components/snapshot_card_component.rb app/components/snapshot_card_component.html.erb app/components/compare_table_component.rb app/components/compare_table_component.html.erb test/components/snapshot_card_component_test.rb test/components/compare_table_component_test.rb
git commit -m "feat: add SnapshotCardComponent and CompareTableComponent"
```

---

## Task 9: Stimulus Controllers (sidebar, dark-mode, dropdown, toast)

**Files:**
- Create: `app/javascript/controllers/sidebar_controller.js`
- Create: `app/javascript/controllers/dark_mode_controller.js`
- Create: `app/javascript/controllers/dropdown_controller.js`
- Create: `app/javascript/controllers/toast_controller.js`
- Delete: `app/javascript/controllers/hello_controller.js`

- [ ] **Step 1: Write sidebar_controller.js**

Create `app/javascript/controllers/sidebar_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "content", "backdrop", "toggleIcon"]
  static values = { collapsed: { type: Boolean, default: false } }

  connect() {
    const saved = localStorage.getItem("sidebar-collapsed")
    if (saved !== null) {
      this.collapsedValue = saved === "true"
    }
    this.applyState()
  }

  toggle() {
    this.collapsedValue = !this.collapsedValue
    localStorage.setItem("sidebar-collapsed", this.collapsedValue)
    this.applyState()
  }

  toggleMobile() {
    this.sidebarTarget.classList.toggle("hidden")
    this.backdropTarget.classList.toggle("hidden")
    document.body.classList.toggle("overflow-hidden")
  }

  close() {
    this.sidebarTarget.classList.add("hidden")
    this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }

  applyState() {
    if (this.collapsedValue) {
      this.sidebarTarget.classList.add("w-16")
      this.sidebarTarget.classList.remove("w-64")
      this.contentTarget.classList.add("md:ml-16")
      this.contentTarget.classList.remove("lg:ml-64")
    } else {
      this.sidebarTarget.classList.remove("w-16")
      this.sidebarTarget.classList.add("w-64")
      this.contentTarget.classList.remove("md:ml-16")
      this.contentTarget.classList.add("lg:ml-64")
    }

    if (this.hasToggleIconTarget) {
      this.toggleIconTarget.classList.toggle("rotate-180", !this.collapsedValue)
    }
  }
}
```

- [ ] **Step 2: Write dark_mode_controller.js**

Create `app/javascript/controllers/dark_mode_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sunIcon", "moonIcon"]

  connect() {
    const saved = localStorage.getItem("dark-mode")
    if (saved !== null) {
      this.setDarkMode(saved === "true")
    } else if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
      this.setDarkMode(true)
    }
    this.updateIcons()
  }

  toggle() {
    const isDark = document.documentElement.classList.contains("dark")
    this.setDarkMode(!isDark)
    localStorage.setItem("dark-mode", !isDark)
    this.updateIcons()
  }

  setDarkMode(enabled) {
    document.documentElement.classList.toggle("dark", enabled)
  }

  updateIcons() {
    const isDark = document.documentElement.classList.contains("dark")
    if (this.hasSunIconTarget && this.hasMoonIconTarget) {
      this.sunIconTarget.classList.toggle("hidden", isDark)
      this.moonIconTarget.classList.toggle("hidden", !isDark)
    }
  }
}
```

- [ ] **Step 3: Write dropdown_controller.js**

Create `app/javascript/controllers/dropdown_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "chevron"]
  static values = { open: { type: Boolean, default: true } }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.toggle("hidden", !this.openValue)
    }
    if (this.hasChevronTarget) {
      this.chevronTarget.classList.toggle("rotate-180", this.openValue)
    }
  }
}
```

- [ ] **Step 4: Write toast_controller.js**

Create `app/javascript/controllers/toast_controller.js`:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 5000 } }

  connect() {
    this.element.classList.add("animate-slide-in")
    if (this.durationValue > 0) {
      this.timeout = setTimeout(() => this.dismiss(), this.durationValue)
    }
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.classList.add("opacity-0", "translate-x-full", "transition-all", "duration-300")
    setTimeout(() => this.element.remove(), 300)
  }
}
```

- [ ] **Step 5: Delete hello_controller.js**

Delete `app/javascript/controllers/hello_controller.js` (unused example controller).

- [ ] **Step 6: Commit**

```bash
git add app/javascript/controllers/sidebar_controller.js app/javascript/controllers/dark_mode_controller.js app/javascript/controllers/dropdown_controller.js app/javascript/controllers/toast_controller.js
git rm app/javascript/controllers/hello_controller.js
git commit -m "feat: add sidebar, dark-mode, dropdown, toast Stimulus controllers"
```

---

## Task 10: Header and Sidebar Components

**Files:**
- Create: `app/components/header/component.rb` + `component.html.erb`
- Create: `app/components/sidebar/component.rb` + `component.html.erb`
- Create: `test/components/header/component_test.rb`
- Create: `test/components/sidebar/component_test.rb`

- [ ] **Step 1: Write failing tests for Header**

Create `test/components/header/component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class Header::ComponentTest < ViewComponent::TestCase
  def test_renders_header_with_app_name
    render_inline(Header::Component.new)

    assert_text "Oh My Auction"
    assert_selector "header.fixed.top-0"
    assert_selector "header.bg-slate-800"
  end

  def test_renders_dark_mode_toggle
    render_inline(Header::Component.new)

    assert_selector "[data-controller='dark-mode']"
  end

  def test_renders_mobile_hamburger
    render_inline(Header::Component.new)

    assert_selector "button[data-action='sidebar#toggleMobile']"
    assert_selector "button.md\\:hidden"
  end

  def test_includes_dark_mode_classes
    render_inline(Header::Component.new)

    assert_selector "header[class*='dark:bg-slate-900']"
  end
end
```

- [ ] **Step 2: Write failing tests for Sidebar**

Create `test/components/sidebar/component_test.rb`:

```ruby
# frozen_string_literal: true

require "test_helper"

class Sidebar::ComponentTest < ViewComponent::TestCase
  def test_renders_sidebar
    render_inline(Sidebar::Component.new(current_path: "/"))

    assert_selector "nav[data-sidebar-target='sidebar']"
  end

  def test_renders_menu_groups
    render_inline(Sidebar::Component.new(current_path: "/"))

    assert_text "물건검색"
    assert_text "권리분석"
    assert_text "입찰"
    assert_text "낙찰"
  end

  def test_renders_menu_items
    render_inline(Sidebar::Component.new(current_path: "/"))

    assert_text "예산 설정"
    assert_text "물건 목록"
  end

  def test_marks_active_item
    render_inline(Sidebar::Component.new(current_path: "/"))

    assert_selector "a[class*='bg-blue-50']", text: "물건 목록"
  end

  def test_renders_disabled_items
    render_inline(Sidebar::Component.new(current_path: "/"))

    assert_selector "[class*='opacity-50']"
  end

  def test_renders_toggle_button
    render_inline(Sidebar::Component.new(current_path: "/"))

    assert_selector "button[data-action='sidebar#toggle']"
  end

  def test_includes_dark_mode_classes
    render_inline(Sidebar::Component.new(current_path: "/"))

    assert_selector "nav[class*='dark:']"
  end
end
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `bin/rails test test/components/header/component_test.rb test/components/sidebar/component_test.rb`
Expected: FAIL — uninitialized constants

- [ ] **Step 4: Write Header::Component**

Create `app/components/header/component.rb`:

```ruby
# frozen_string_literal: true

class Header::Component < ViewComponent::Base
  def initialize(app_name: "Oh My Auction")
    @app_name = app_name
  end
end
```

Create `app/components/header/component.html.erb`:

```erb
<header class="fixed top-0 left-0 right-0 z-40 h-16 bg-slate-800 dark:bg-slate-900 flex items-center justify-between px-4">
  <%# Left: hamburger + logo %>
  <div class="flex items-center gap-3">
    <button data-action="sidebar#toggleMobile"
            class="md:hidden p-2 rounded-md text-slate-300 hover:text-white hover:bg-slate-700 transition-colors duration-150"
            aria-label="메뉴 열기">
      <%= heroicon "bars-3", variant: :outline, options: { class: "w-6 h-6" } %>
    </button>
    <span class="font-bold text-lg text-white"><%= @app_name %></span>
  </div>

  <%# Right: dark mode + notifications + avatar %>
  <div class="flex items-center gap-1">
    <%# Dark mode toggle %>
    <div data-controller="dark-mode">
      <button data-action="dark-mode#toggle"
              class="p-2 rounded-md text-slate-300 hover:text-white hover:bg-slate-700 transition-colors duration-150"
              aria-label="다크 모드 전환">
        <span data-dark-mode-target="sunIcon">
          <%= heroicon "sun", variant: :outline, options: { class: "w-5 h-5" } %>
        </span>
        <span data-dark-mode-target="moonIcon" class="hidden">
          <%= heroicon "moon", variant: :outline, options: { class: "w-5 h-5" } %>
        </span>
      </button>
    </div>

    <%# Notifications placeholder %>
    <button class="p-2 rounded-md text-slate-300 hover:text-white hover:bg-slate-700 transition-colors duration-150"
            aria-label="알림">
      <%= heroicon "bell", variant: :outline, options: { class: "w-5 h-5" } %>
    </button>

    <%# User avatar placeholder %>
    <button class="p-2 rounded-md text-slate-300 hover:text-white hover:bg-slate-700 transition-colors duration-150"
            aria-label="프로필">
      <%= heroicon "user-circle", variant: :outline, options: { class: "w-5 h-5" } %>
    </button>
  </div>
</header>
```

- [ ] **Step 5: Write Sidebar::Component**

Create `app/components/sidebar/component.rb`:

```ruby
# frozen_string_literal: true

class Sidebar::Component < ViewComponent::Base
  MenuItem = Data.define(:label, :icon, :path, :enabled)

  MENU_GROUPS = [
    {
      title: "물건검색",
      items: [
        MenuItem.new(label: "예산 설정", icon: "calculator", path: "/onboarding", enabled: true),
        MenuItem.new(label: "물건 목록", icon: "magnifying-glass", path: "/", enabled: true),
        MenuItem.new(label: "시세 조회", icon: "chart-bar", path: nil, enabled: false)
      ]
    },
    {
      title: "권리분석",
      items: [
        MenuItem.new(label: "권리분석 리포트", icon: "document-magnifying-glass", path: nil, enabled: false),
        MenuItem.new(label: "수익 계산기", icon: "banknotes", path: nil, enabled: false),
        MenuItem.new(label: "대출 매칭", icon: "building-library", path: nil, enabled: false)
      ]
    },
    {
      title: "입찰",
      items: [
        MenuItem.new(label: "진행 체크리스트", icon: "clipboard-document-check", path: nil, enabled: false),
        MenuItem.new(label: "가상 입찰", icon: "play-circle", path: nil, enabled: false),
        MenuItem.new(label: "사전 임장", icon: "map-pin", path: nil, enabled: false)
      ]
    },
    {
      title: "낙찰",
      items: [
        MenuItem.new(label: "명도 가이드", icon: "key", path: nil, enabled: false),
        MenuItem.new(label: "전문가 연결", icon: "user-group", path: nil, enabled: false)
      ]
    }
  ].freeze

  def initialize(current_path:)
    @current_path = current_path
  end

  def menu_groups
    MENU_GROUPS
  end

  def active?(item)
    item.enabled && item.path == @current_path
  end

  def item_classes(item)
    base = "flex items-center gap-3 px-3 py-2 rounded-md text-sm transition-colors duration-150"
    if !item.enabled
      "#{base} opacity-50 cursor-not-allowed text-slate-400 dark:text-slate-600"
    elsif active?(item)
      "#{base} bg-blue-50 dark:bg-blue-900/50 text-blue-700 dark:text-blue-400 font-medium"
    else
      "#{base} text-slate-600 dark:text-slate-400 hover:bg-slate-100 dark:hover:bg-slate-700 hover:text-slate-900 dark:hover:text-slate-100"
    end
  end
end
```

Create `app/components/sidebar/component.html.erb`:

```erb
<nav data-sidebar-target="sidebar"
     class="fixed left-0 top-16 bottom-0 z-30 bg-white dark:bg-slate-800 border-r border-slate-200 dark:border-slate-700 transition-[width] duration-200 w-64 hidden md:block overflow-y-auto">
  <div class="py-4 px-2">
    <% menu_groups.each_with_index do |group, index| %>
      <div class="<%= 'mt-6' if index > 0 %>" data-controller="dropdown">
        <%# Group title %>
        <button data-action="dropdown#toggle"
                class="w-full flex items-center justify-between px-3 py-2 text-xs font-semibold text-slate-400 dark:text-slate-500 uppercase tracking-wider hover:text-slate-600 dark:hover:text-slate-300">
          <span><%= group[:title] %></span>
          <%= heroicon "chevron-down", variant: :outline, options: {
            class: "w-4 h-4 transition-transform duration-200 rotate-180",
            data: { dropdown_target: "chevron" }
          } %>
        </button>

        <%# Menu items %>
        <div data-dropdown-target="menu" class="mt-1 space-y-0.5">
          <% group[:items].each do |item| %>
            <% if item.enabled %>
              <a href="<%= item.path %>" class="<%= item_classes(item) %>">
                <%= heroicon item.icon, variant: :outline, options: { class: "w-5 h-5 flex-shrink-0" } %>
                <span><%= item.label %></span>
              </a>
            <% else %>
              <button class="<%= item_classes(item) %> w-full"
                      data-action="click->toast#show"
                      data-toast-message="준비 중입니다"
                      disabled>
                <%= heroicon item.icon, variant: :outline, options: { class: "w-5 h-5 flex-shrink-0" } %>
                <span><%= item.label %></span>
              </button>
            <% end %>
          <% end %>
        </div>
      </div>
    <% end %>
  </div>

  <%# Toggle button %>
  <div class="absolute bottom-0 left-0 right-0 border-t border-slate-200 dark:border-slate-700 px-3 py-3">
    <button data-action="sidebar#toggle"
            class="w-full flex items-center justify-center p-2 rounded-md text-slate-400 hover:text-slate-600 dark:text-slate-500 dark:hover:text-slate-300 transition-colors duration-150"
            aria-label="사이드바 접기/펼치기">
      <%= heroicon "chevron-left", variant: :outline, options: {
        class: "w-5 h-5 transition-transform duration-200",
        data: { sidebar_target: "toggleIcon" }
      } %>
    </button>
  </div>
</nav>
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `bin/rails test test/components/header/component_test.rb test/components/sidebar/component_test.rb`
Expected: All tests PASS

- [ ] **Step 7: Commit**

```bash
git add app/components/header/ app/components/sidebar/ test/components/header/ test/components/sidebar/
git commit -m "feat: add Header and Sidebar components with navigation, dark mode, responsive"
```

---

## Task 11: Application Layout (App Shell)

**Files:**
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Rewrite application layout**

Replace `app/views/layouts/application.html.erb` with:

```erb
<!DOCTYPE html>
<html class="h-full">
  <head>
    <title><%= content_for(:title) || "Oh My Auction" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="Oh My Auction">
    <meta name="mobile-web-app-capable" content="yes">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <link rel="preconnect" href="https://cdn.jsdelivr.net" crossorigin>
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/orioncactus/pretendard@v1.3.9/dist/web/variable/pretendardvariable-dynamic-subset.min.css">

    <%= stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>

    <script>
      if (localStorage.getItem("dark-mode") === "true" ||
          (!localStorage.getItem("dark-mode") && window.matchMedia("(prefers-color-scheme: dark)").matches)) {
        document.documentElement.classList.add("dark")
      }
    </script>
  </head>

  <body class="h-full bg-slate-50 dark:bg-slate-900 font-sans antialiased break-keep"
        data-controller="sidebar">
    <%# Skip to main content %>
    <a href="#main-content"
       class="sr-only focus:not-sr-only focus:absolute focus:z-50 focus:p-4 focus:bg-white focus:text-blue-600">
      본문으로 건너뛰기
    </a>

    <%# Header %>
    <%= render Header::Component.new %>

    <%# Sidebar %>
    <%= render Sidebar::Component.new(current_path: request.path) %>

    <%# Mobile backdrop %>
    <div class="fixed inset-0 bg-slate-900/50 z-30 md:hidden hidden"
         data-sidebar-target="backdrop"
         data-action="click->sidebar#close"></div>

    <%# Main content area %>
    <div class="min-h-screen pt-16 transition-[margin] duration-200 md:ml-16 lg:ml-64"
         data-sidebar-target="content">
      <main id="main-content" class="px-4 py-4 md:px-6 md:py-6">
        <%# Flash messages %>
        <div id="flash_messages" class="fixed top-20 right-4 z-50 flex flex-col gap-2 pointer-events-none">
          <% flash.each do |type, message| %>
            <% toast_type = case type.to_s
               when "notice", "success" then :success
               when "alert", "error" then :danger
               when "warning" then :warning
               else :info
               end %>
            <%= render ToastComponent.new(type: toast_type, message: message) %>
          <% end %>
        </div>

        <%= yield %>
      </main>

      <%# Footer %>
      <footer class="border-t border-slate-200 dark:border-slate-700 px-4 py-4 md:px-6 text-center">
        <p class="text-xs text-slate-400 dark:text-slate-500">
          © <%= Date.current.year %> Oh My Auction. All rights reserved.
        </p>
      </footer>
    </div>
  </body>
</html>
```

- [ ] **Step 2: Verify the layout renders**

Run: `bin/rails tailwindcss:build && bin/rails test`
Expected: All existing tests still pass (layout is backward compatible)

- [ ] **Step 3: Commit**

```bash
git add app/views/layouts/application.html.erb
git commit -m "feat: rewrite application layout with App Shell (header, sidebar, footer, dark mode)"
```

---

## Task 12: Redesign Onboarding Views (step1, step2, step3)

**Files:**
- Modify: `app/views/onboardings/step1.html.erb`
- Modify: `app/views/onboardings/step2.html.erb`
- Modify: `app/views/onboardings/step3.html.erb`

- [ ] **Step 1: Redesign step1.html.erb**

Replace `app/views/onboardings/step1.html.erb` with:

```erb
<turbo-frame id="onboarding_wizard">
  <%= render WizardStepComponent.new(
    title: "투자 가능한 유용자금을 입력하세요",
    description: "유용자금이란 현재 투자에 사용할 수 있는 현금을 말합니다",
    current_step: 1,
    total_steps: 3
  ) do %>
    <%= form_with model: @setting, url: step1_onboarding_path, method: :post, data: { turbo_frame: "onboarding_wizard" } do |f| %>
      <% if @setting.errors[:available_cash].any? %>
        <div class="mb-4 p-3 bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 rounded-lg text-sm">
          <%= @setting.errors[:available_cash].join(", ") %>
        </div>
      <% end %>

      <div class="mb-6" data-controller="number-format" data-number-format-initial-value="<%= @setting.available_cash || 3000 %>">
        <label for="available_cash_display" class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">
          유용자금
        </label>
        <div class="flex items-center gap-2">
          <input type="text" id="available_cash_display"
            inputmode="numeric"
            class="w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 placeholder:text-slate-400 dark:placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-blue-500/20 dark:focus:ring-blue-400/20 focus:border-blue-500 dark:focus:border-blue-400 transition-colors duration-150"
            placeholder="3,000"
            data-number-format-target="display"
            data-action="input->number-format#format">
          <%= f.hidden_field :available_cash, data: { number_format_target: "hidden" } %>
          <span class="text-slate-600 dark:text-slate-400 font-medium whitespace-nowrap">만원</span>
        </div>
      </div>

      <div class="mt-8">
        <%= render ButtonComponent.new(icon: "arrow-right", **{ class: "w-full" }) { "다음" } %>
      </div>
    <% end %>
  <% end %>
</turbo-frame>
```

- [ ] **Step 2: Redesign step2.html.erb**

Replace `app/views/onboardings/step2.html.erb` with:

```erb
<turbo-frame id="onboarding_wizard">
  <%= render WizardStepComponent.new(
    title: "예비비 설정",
    current_step: 2,
    total_steps: 3
  ) do %>
    <div data-controller="reserve-fund"
         data-reserve-fund-defaults-value="<%= @reserve_defaults.to_json %>"
         data-reserve-fund-unit-value="<%= @setting.area_unit || 'pyeong' %>">

      <%= form_with model: @setting, url: step2_onboarding_path, method: :post, data: { turbo_frame: "onboarding_wizard" } do |f| %>
        <div class="space-y-5">
          <%# Property type %>
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">부동산 유형</label>
            <%= f.collection_select :property_type_id, @property_types, :id, :name,
              { prompt: "선택하세요" },
              { class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150",
                data: { reserve_fund_target: "propertyType",
                        action: "change->reserve-fund#propertyTypeChanged" } } %>
          </div>

          <%# Area unit %>
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">면적 단위</label>
            <div class="flex gap-4">
              <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-300">
                <%= f.radio_button :area_unit, "pyeong",
                  checked: (@setting.area_unit || "pyeong") == "pyeong",
                  data: { action: "change->reserve-fund#unitChanged" },
                  class: "text-blue-600 focus:ring-blue-500" %>
                <span>평</span>
              </label>
              <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-300">
                <%= f.radio_button :area_unit, "sqm",
                  checked: @setting.area_unit == "sqm",
                  data: { action: "change->reserve-fund#unitChanged" },
                  class: "text-blue-600 focus:ring-blue-500" %>
                <span>㎡</span>
              </label>
            </div>
          </div>

          <%# Area range %>
          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5"
                     data-reserve-fund-target="areaMinLabel">
                면적 최소 (<%= (@setting.area_unit || "pyeong") == "pyeong" ? "평" : "㎡" %>)
              </label>
              <%= f.number_field :area_range_min, inputmode: "numeric",
                class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150",
                data: { reserve_fund_target: "areaMin", action: "change->reserve-fund#areaChanged" } %>
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5"
                     data-reserve-fund-target="areaMaxLabel">
                면적 최대 (<%= (@setting.area_unit || "pyeong") == "pyeong" ? "평" : "㎡" %>)
              </label>
              <%= f.number_field :area_range_max, inputmode: "numeric",
                class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150",
                data: { reserve_fund_target: "areaMax", action: "change->reserve-fund#areaChanged" } %>
            </div>
          </div>

          <%# Auto-calc toggle %>
          <div>
            <label class="flex items-center gap-2">
              <input type="checkbox" checked
                     data-reserve-fund-target="autoCalc"
                     data-action="change->reserve-fund#toggleAutoCalc"
                     class="rounded border-slate-300 dark:border-slate-600 text-blue-600 focus:ring-blue-500">
              <span class="text-sm font-medium text-slate-700 dark:text-slate-300">면적/유형에 따라 자동 계산</span>
            </label>
            <p class="text-xs text-slate-400 dark:text-slate-500 mt-1 ml-6">체크 해제 시 직접 입력할 수 있습니다</p>
          </div>

          <%# Reserve fund items %>
          <div class="space-y-3">
            <% [
              [:repair_cost, "수선비", "repairCost"],
              [:acquisition_tax, "취득세", "acquisitionTax"],
              [:scrivener_fee, "법무사비", "scrivenerFee"],
              [:moving_cost, "이사비", "movingCost"],
              [:maintenance_fee, "관리비", "maintenanceFee"]
            ].each do |field, label, target| %>
              <div class="flex items-center gap-2">
                <label class="w-24 text-sm font-medium text-slate-700 dark:text-slate-300"><%= label %></label>
                <%= f.number_field field, inputmode: "numeric",
                  class: "flex-1 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150",
                  data: { reserve_fund_target: target, action: "input->reserve-fund#updateTotal" } %>
                <span class="text-slate-600 dark:text-slate-400 text-sm whitespace-nowrap">만원</span>
              </div>
            <% end %>
          </div>

          <%# Total %>
          <div class="p-3 bg-slate-50 dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700">
            <p class="text-sm font-medium text-slate-700 dark:text-slate-300">
              예비비 합계: <span class="tabular-nums font-mono" data-reserve-fund-target="total">0</span>만원
            </p>
          </div>
        </div>

        <%# Navigation %>
        <div class="mt-8 flex gap-4">
          <%= render ButtonComponent.new(variant: :outline, tag: :a, href: start_onboarding_path, icon: "arrow-left", data: { turbo_frame: "onboarding_wizard" }, **{ class: "flex-1 justify-center" }) { "이전" } %>
          <%= render ButtonComponent.new(icon: "arrow-right", **{ class: "flex-1 justify-center" }) { "다음" } %>
        </div>
      <% end %>
    </div>
  <% end %>
</turbo-frame>
```

- [ ] **Step 3: Redesign step3.html.erb**

Replace `app/views/onboardings/step3.html.erb` with:

```erb
<turbo-frame id="onboarding_wizard">
  <%= render WizardStepComponent.new(
    title: "대출 및 낙찰가 설정",
    current_step: 3,
    total_steps: 3
  ) do %>
    <div data-controller="loan-slider"
         data-loan-slider-available-cash-value="<%= @setting.available_cash %>"
         data-loan-slider-total-reserves-value="<%= @setting.total_reserves %>">

      <%= form_with model: @setting, url: step3_onboarding_path, method: :post, data: { turbo_frame: "_top" } do |f| %>
        <% if @setting.errors.any? %>
          <div class="mb-4 p-3 bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 rounded-lg text-sm">
            <% @setting.errors.full_messages.each do |msg| %>
              <p><%= msg %></p>
            <% end %>
          </div>
        <% end %>

        <div class="space-y-6">
          <%# Loan policy selection %>
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-3">대출 정책 선택</label>
            <div class="space-y-2">
              <% if @loan_policies.present? %>
                <% @loan_policies.each do |policy| %>
                  <label class="flex items-center gap-3 p-3 border border-slate-200 dark:border-slate-700 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700/50 cursor-pointer transition-colors">
                    <%= f.radio_button :loan_policy_id, policy.id,
                      data: { loan_ratio: policy.loan_ratio, action: "change->loan-slider#selectPolicy" },
                      class: "text-blue-600 focus:ring-blue-500" %>
                    <div>
                      <span class="font-medium text-slate-900 dark:text-slate-100"><%= policy.policy_name %></span>
                      <span class="text-sm text-slate-500 dark:text-slate-400 ml-2">LTV <%= (policy.loan_ratio * 100).to_i %>%</span>
                      <% if policy.description.present? %>
                        <p class="text-xs text-slate-400 dark:text-slate-500 mt-1"><%= policy.description %></p>
                      <% end %>
                    </div>
                  </label>
                <% end %>
              <% else %>
                <p class="text-slate-500 dark:text-slate-400 text-sm">선택한 부동산 유형에 해당하는 대출 정책이 없습니다.</p>
              <% end %>
            </div>
          </div>

          <%# LTV slider %>
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">대출 비율 (LTV)</label>
            <input type="range" min="0" max="90" step="5"
                   value="<%= (@setting.loan_ratio.to_f * 100).to_i %>"
                   class="w-full accent-blue-600"
                   data-loan-slider-target="slider"
                   data-action="input->loan-slider#slide">
            <div class="flex justify-between text-xs text-slate-500 dark:text-slate-400 mt-1">
              <span>0%</span>
              <span class="font-medium text-slate-700 dark:text-slate-300" data-loan-slider-target="ratioDisplay"><%= (@setting.loan_ratio.to_f * 100).to_i %>%</span>
              <span>90%</span>
            </div>
            <input type="hidden" name="budget_setting[loan_ratio]" data-loan-slider-target="hiddenRatio" value="<%= @setting.loan_ratio %>">
          </div>

          <%# Max bid preview %>
          <div class="p-4 bg-blue-50 dark:bg-blue-900/20 rounded-lg border border-blue-200 dark:border-blue-800">
            <p class="text-sm text-slate-600 dark:text-slate-400">예상 최대입찰가</p>
            <p class="text-2xl font-bold text-blue-700 dark:text-blue-400 tabular-nums font-mono" data-loan-slider-target="maxBidPreview">계산 중...</p>
          </div>

          <%# Failed rounds slider %>
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">유찰 회차</label>
            <input type="range" min="0" max="3" step="1"
                   value="<%= @setting.failed_auction_rounds %>"
                   name="budget_setting[failed_auction_rounds]"
                   class="w-full accent-blue-600"
                   data-loan-slider-target="roundsSlider"
                   data-action="input->loan-slider#slideRounds">
            <div class="flex justify-between text-xs text-slate-500 dark:text-slate-400 mt-1">
              <span>0회차 (신건)</span>
              <span class="font-medium text-slate-700 dark:text-slate-300" data-loan-slider-target="roundsDisplay"><%= @setting.failed_auction_rounds %>회차</span>
              <span>3회차</span>
            </div>
          </div>

          <%# Appraisal limit preview %>
          <div class="p-4 bg-slate-50 dark:bg-slate-800 rounded-lg border border-slate-200 dark:border-slate-700">
            <p class="text-sm text-slate-600 dark:text-slate-400">검색 가능 감정가 상한</p>
            <p class="text-xl font-bold text-slate-700 dark:text-slate-300 tabular-nums font-mono" data-loan-slider-target="limitPreview">계산 중...</p>
          </div>

          <p class="text-xs text-slate-400 dark:text-slate-500">
            ※ 이 계산은 추정치입니다. 정확한 대출 한도는 금융기관에 확인하세요.
          </p>
        </div>

        <%# Navigation %>
        <div class="mt-8 flex gap-4">
          <%= render ButtonComponent.new(variant: :outline, tag: :a, href: start_onboarding_path, icon: "arrow-left", data: { turbo_frame: "onboarding_wizard" }, **{ class: "flex-1 justify-center" }) { "이전" } %>
          <%= render ButtonComponent.new(icon: "check", **{ class: "flex-1 justify-center" }) { "저장" } %>
        </div>
      <% end %>
    </div>
  <% end %>
</turbo-frame>
```

- [ ] **Step 4: Verify onboarding tests pass**

Run: `bin/rails test test/`
Expected: All tests PASS

- [ ] **Step 5: Commit**

```bash
git add app/views/onboardings/step1.html.erb app/views/onboardings/step2.html.erb app/views/onboardings/step3.html.erb
git commit -m "feat: redesign onboarding wizard views with WizardStepComponent, dark mode"
```

---

## Task 13: Redesign Onboarding Complete and Home Page

**Files:**
- Modify: `app/views/onboardings/complete.html.erb`
- Modify: `app/views/home/index.html.erb`

- [ ] **Step 1: Redesign complete.html.erb**

Replace `app/views/onboardings/complete.html.erb` with:

```erb
<div class="max-w-lg mx-auto">
  <div class="text-center mb-8">
    <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100 mb-2">예산 설정 완료</h1>
    <p class="text-slate-500 dark:text-slate-400">나의 최대 입찰 가능 금액이 계산되었습니다</p>
  </div>

  <% if @setting %>
    <%# Max bid hero card %>
    <%= render StatCardComponent.new(
      label: "최대 입찰가",
      value: "#{number_with_delimiter(@setting.max_bid_amount)}만원",
      sublabel: @setting.max_bid_amount && @setting.max_bid_amount >= 10000 ? "(약 #{(@setting.max_bid_amount / 10000.0).round(1)}억원)" : nil
    ) %>

    <% if @setting.failed_auction_rounds.to_i > 0 %>
      <div class="mt-6 p-4 bg-amber-50 dark:bg-amber-900/20 border border-amber-200 dark:border-amber-800 rounded-lg">
        <p class="text-sm text-amber-800 dark:text-amber-300">
          유찰 <%= @setting.failed_auction_rounds %>회차 기준 검색 가능 감정가:
          <strong class="tabular-nums font-mono"><%= number_with_delimiter(@setting.searchable_appraisal_limit) %>만원</strong>
        </p>
      </div>
    <% end %>

    <%# Cost breakdown %>
    <div class="mt-6">
      <%= render SummaryTableComponent.new(
        title: "비용 내역",
        rows: [
          { label: "유용자금", value: "#{number_with_delimiter(@setting.available_cash)}만원" },
          { label: "수선비", value: "#{number_with_delimiter(@setting.repair_cost)}만원" },
          { label: "취득세", value: "#{number_with_delimiter(@setting.acquisition_tax)}만원" },
          { label: "법무사비", value: "#{number_with_delimiter(@setting.scrivener_fee)}만원" },
          { label: "이사비", value: "#{number_with_delimiter(@setting.moving_cost)}만원" },
          { label: "관리비", value: "#{number_with_delimiter(@setting.maintenance_fee)}만원" },
          { label: "예비비 합계", value: "#{number_with_delimiter(@setting.total_reserves)}만원", highlight: true },
          { label: "대출 비율 (LTV)", value: "#{(@setting.loan_ratio.to_f * 100).round}%" }
        ]
      ) %>
    </div>

    <% if @snapshot %>
      <p class="text-xs text-slate-400 dark:text-slate-500 text-center mt-4">
        적용 정책: <%= @setting.loan_policy&.policy_name || "직접 설정" %> |
        계산일: <%= @snapshot.calculated_at.strftime("%Y-%m-%d %H:%M") %>
      </p>
    <% end %>

    <div class="mt-6 space-y-3">
      <%= render ButtonComponent.new(tag: :a, href: root_path, icon: "magnifying-glass", **{ class: "w-full justify-center" }) { "내 예산 범위 물건 보기" } %>
      <%= render ButtonComponent.new(variant: :outline, tag: :a, href: settings_budget_path, icon: "cog-6-tooth", **{ class: "w-full justify-center" }) { "설정 다시 하기" } %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 2: Redesign home/index.html.erb**

Replace `app/views/home/index.html.erb` with:

```erb
<% if defined?(current_user) && current_user&.budget_setting %>
  <div class="mb-6">
    <%= render StatCardComponent.new(
      label: "내 최대입찰가",
      value: "#{number_with_delimiter(current_user.budget_setting.max_bid_amount)}만원",
      variant: :muted
    ) %>
  </div>
<% end %>

<%= render EmptyStateComponent.new(
  icon: "magnifying-glass",
  title: "물건 목록이 준비 중입니다",
  description: "F02 기능이 구현되면 예산 범위 내 안전한 경매 물건을 검색할 수 있습니다.",
  cta_text: "예산 설정하기",
  cta_href: start_onboarding_path
) %>
```

- [ ] **Step 3: Verify tests pass**

Run: `bin/rails test`
Expected: All tests PASS

- [ ] **Step 4: Commit**

```bash
git add app/views/onboardings/complete.html.erb app/views/home/index.html.erb
git commit -m "feat: redesign onboarding complete and home page with components"
```

---

## Task 14: Redesign Settings Views

**Files:**
- Modify: `app/views/settings/budgets/show.html.erb`
- Modify: `app/views/settings/budget_snapshots/index.html.erb`
- Modify: `app/views/settings/budget_snapshots/show.html.erb`
- Modify: `app/views/settings/budget_snapshots/compare.html.erb`

- [ ] **Step 1: Redesign budgets/show.html.erb**

Replace `app/views/settings/budgets/show.html.erb` with:

```erb
<div class="max-w-2xl mx-auto">
  <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100 mb-6">예산 설정</h1>

  <% if notice %>
    <div class="mb-4">
      <%= render ToastComponent.new(type: :success, message: notice) %>
    </div>
  <% end %>

  <% if @setting.errors.any? %>
    <div class="mb-4 p-3 bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 rounded-lg text-sm">
      <% @setting.errors.full_messages.each do |msg| %>
        <p><%= msg %></p>
      <% end %>
    </div>
  <% end %>

  <%= form_with model: @setting, url: settings_budget_path, method: :patch do |f| %>
    <div class="space-y-6">
      <%# Section 1: Available Cash %>
      <%= render CardComponent.new(title: "유용자금") do %>
        <div class="flex items-center gap-2">
          <label class="w-24 text-sm font-medium text-slate-700 dark:text-slate-300">유용자금</label>
          <%= f.number_field :available_cash, inputmode: "numeric",
            class: "flex-1 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150" %>
          <span class="text-slate-600 dark:text-slate-400 font-medium text-sm">만원</span>
        </div>
      <% end %>

      <%# Section 2: Reserve Funds %>
      <%= render CardComponent.new(title: "예비비") do %>
        <div class="space-y-5">
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">부동산 유형</label>
            <%= f.collection_select :property_type_id, @property_types, :id, :name,
              { prompt: "선택하세요" },
              { class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150" } %>
          </div>

          <div class="grid grid-cols-2 gap-4">
            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">면적 최소 (㎡)</label>
              <%= f.number_field :area_range_min, inputmode: "numeric",
                class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150" %>
            </div>
            <div>
              <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">면적 최대 (㎡)</label>
              <%= f.number_field :area_range_max, inputmode: "numeric",
                class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150" %>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">면적 단위</label>
            <div class="flex gap-4">
              <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-300">
                <%= f.radio_button :area_unit, "pyeong", checked: @setting.area_unit == "pyeong", class: "text-blue-600 focus:ring-blue-500" %>
                <span>평</span>
              </label>
              <label class="flex items-center gap-2 text-sm text-slate-700 dark:text-slate-300">
                <%= f.radio_button :area_unit, "sqm", checked: @setting.area_unit == "sqm", class: "text-blue-600 focus:ring-blue-500" %>
                <span>㎡</span>
              </label>
            </div>
          </div>

          <div class="space-y-3">
            <% [ [:repair_cost, "수선비"], [:acquisition_tax, "취득세"], [:scrivener_fee, "법무사비"],
                 [:moving_cost, "이사비"], [:maintenance_fee, "관리비"] ].each do |field, label| %>
              <div class="flex items-center gap-2">
                <label class="w-24 text-sm font-medium text-slate-700 dark:text-slate-300"><%= label %></label>
                <%= f.number_field field, inputmode: "numeric",
                  class: "flex-1 rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150" %>
                <span class="text-slate-600 dark:text-slate-400 text-sm">만원</span>
              </div>
            <% end %>
          </div>
        </div>
      <% end %>

      <%# Section 3: Loan Policy %>
      <%= render CardComponent.new(title: "대출 정책") do %>
        <div class="space-y-5">
          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-2">대출 정책</label>
            <div class="space-y-2">
              <% @loan_policies.each do |policy| %>
                <label class="flex items-center gap-3 p-3 border border-slate-200 dark:border-slate-700 rounded-lg hover:bg-slate-50 dark:hover:bg-slate-700/50 cursor-pointer transition-colors">
                  <%= f.radio_button :loan_policy_id, policy.id, class: "text-blue-600 focus:ring-blue-500" %>
                  <div>
                    <span class="font-medium text-slate-900 dark:text-slate-100"><%= policy.policy_name %></span>
                    <span class="text-sm text-slate-500 dark:text-slate-400 ml-2">LTV <%= (policy.loan_ratio * 100).to_i %>%</span>
                  </div>
                </label>
              <% end %>
            </div>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">대출 비율 (LTV)</label>
            <%= f.number_field :loan_ratio, step: 0.01, min: 0, max: 1,
              class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150" %>
          </div>

          <div>
            <label class="block text-sm font-medium text-slate-700 dark:text-slate-300 mb-1.5">유찰 회차</label>
            <%= f.number_field :failed_auction_rounds, min: 0, max: 3,
              class: "w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150" %>
          </div>
        </div>
      <% end %>

      <%# Current max bid %>
      <% if @setting.max_bid_amount %>
        <%= render StatCardComponent.new(
          label: "현재 최대입찰가",
          value: "#{number_with_delimiter(@setting.max_bid_amount)}만원",
          variant: :muted
        ) %>
      <% end %>

      <%# Actions %>
      <div class="flex gap-4">
        <%= render ButtonComponent.new(variant: :outline, tag: :a, href: settings_budget_snapshots_path, icon: "clock", **{ class: "flex-1 justify-center" }) { "스냅샷 이력" } %>
        <%= render ButtonComponent.new(icon: "check", **{ class: "flex-1 justify-center" }) { "저장" } %>
      </div>
    </div>
  <% end %>
</div>
```

- [ ] **Step 2: Redesign budget_snapshots/index.html.erb**

Replace `app/views/settings/budget_snapshots/index.html.erb` with:

```erb
<div class="max-w-2xl mx-auto">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">스냅샷 이력</h1>
    <%= render ButtonComponent.new(variant: :ghost, tag: :a, href: settings_budget_path, icon: "arrow-left", size: :sm) { "예산 설정으로" } %>
  </div>

  <% if notice %>
    <div class="mb-4">
      <%= render ToastComponent.new(type: :success, message: notice) %>
    </div>
  <% end %>

  <% if @snapshots.any? %>
    <div class="space-y-3">
      <% @snapshots.each do |snapshot| %>
        <%= render SnapshotCardComponent.new(
          version: snapshot.version,
          trigger: snapshot.trigger,
          max_bid_amount: snapshot.max_bid_amount,
          calculated_at: snapshot.calculated_at,
          show_path: settings_budget_snapshot_path(snapshot),
          recalculate_path: recalculate_settings_budget_snapshot_path(snapshot)
        ) %>
      <% end %>
    </div>

    <% if @snapshots.size >= 2 %>
      <div class="mt-6">
        <%= render CardComponent.new(title: "스냅샷 비교") do %>
          <%= form_tag compare_settings_budget_snapshots_path, method: :get, class: "flex gap-3 items-end" do %>
            <div class="flex-1">
              <label class="block text-xs text-slate-500 dark:text-slate-400 mb-1">기준</label>
              <select name="ids[]" class="w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150">
                <% @snapshots.each do |s| %>
                  <option value="<%= s.id %>">v<%= s.version %> (<%= s.trigger %>)</option>
                <% end %>
              </select>
            </div>
            <div class="flex-1">
              <label class="block text-xs text-slate-500 dark:text-slate-400 mb-1">비교 대상</label>
              <select name="ids[]" class="w-full rounded-md border border-slate-200 dark:border-slate-600 bg-white dark:bg-slate-700 px-3 py-2 text-sm text-slate-900 dark:text-slate-100 focus:outline-none focus:ring-2 focus:ring-blue-500/20 focus:border-blue-500 transition-colors duration-150">
                <% @snapshots.each_with_index do |s, i| %>
                  <option value="<%= s.id %>" <%= "selected" if i == 1 %>>v<%= s.version %> (<%= s.trigger %>)</option>
                <% end %>
              </select>
            </div>
            <%= render ButtonComponent.new(variant: :secondary, icon: "arrows-right-left", size: :sm) { "비교" } %>
          <% end %>
        <% end %>
      </div>
    <% end %>
  <% else %>
    <%= render EmptyStateComponent.new(
      icon: "clock",
      title: "저장된 스냅샷이 없습니다",
      description: "예산 설정을 저장하면 스냅샷이 자동으로 생성됩니다.",
      cta_text: "예산 설정하기",
      cta_href: settings_budget_path
    ) %>
  <% end %>
</div>
```

- [ ] **Step 3: Redesign budget_snapshots/show.html.erb**

Replace `app/views/settings/budget_snapshots/show.html.erb` with:

```erb
<div class="max-w-lg mx-auto">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">스냅샷 v<%= @snapshot.version %></h1>
    <%= render ButtonComponent.new(variant: :ghost, tag: :a, href: settings_budget_snapshots_path, icon: "arrow-left", size: :sm) { "목록으로" } %>
  </div>

  <div class="mb-4 flex items-center gap-2">
    <% trigger_variant = case @snapshot.trigger
       when "onboarding" then :info
       when "manual_edit" then :success
       when "recalculate" then :warning
       else :default
       end %>
    <%= render BadgeComponent.new(variant: trigger_variant) { @snapshot.trigger } %>
    <span class="text-xs text-slate-400 dark:text-slate-500"><%= @snapshot.calculated_at&.strftime("%Y-%m-%d %H:%M") %></span>
  </div>

  <% if @snapshot.max_bid_amount %>
    <%= render StatCardComponent.new(
      label: "최대 입찰가",
      value: "#{number_with_delimiter(@snapshot.max_bid_amount)}만원"
    ) %>
  <% end %>

  <div class="mt-6">
    <%= render SummaryTableComponent.new(
      title: "상세 내역",
      rows: [
        { label: "유용자금", value: "#{number_with_delimiter(@snapshot.available_cash)}만원" },
        { label: "부동산 유형", value: @snapshot.property_type_name || "-" },
        { label: "면적", value: @snapshot.area_range || "-" },
        { label: "수선비", value: "#{number_with_delimiter(@snapshot.repair_cost)}만원" },
        { label: "취득세", value: "#{number_with_delimiter(@snapshot.acquisition_tax)}만원" },
        { label: "법무사비", value: "#{number_with_delimiter(@snapshot.scrivener_fee)}만원" },
        { label: "이사비", value: "#{number_with_delimiter(@snapshot.moving_cost)}만원" },
        { label: "관리비", value: "#{number_with_delimiter(@snapshot.maintenance_fee)}만원" },
        { label: "대출 정책", value: @snapshot.loan_policy_name || "-" },
        { label: "대출 비율 (LTV)", value: @snapshot.loan_ratio ? "#{(@snapshot.loan_ratio.to_f * 100).round}%" : "-" },
        { label: "유찰 회차", value: "#{@snapshot.failed_auction_rounds}회차" },
        { label: "검색 가능 감정가", value: "#{number_with_delimiter(@snapshot.searchable_appraisal_limit)}만원" }
      ]
    ) %>
  </div>

  <div class="mt-6">
    <%= button_to recalculate_settings_budget_snapshot_path(@snapshot), method: :post do %>
      <%= render ButtonComponent.new(variant: :outline, icon: "arrow-path", **{ class: "w-full justify-center" }) { "현재 조건으로 재계산" } %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Redesign budget_snapshots/compare.html.erb**

Replace `app/views/settings/budget_snapshots/compare.html.erb` with:

```erb
<div class="max-w-2xl mx-auto">
  <div class="flex justify-between items-center mb-6">
    <h1 class="text-2xl font-bold text-slate-900 dark:text-slate-100">스냅샷 비교</h1>
    <%= render ButtonComponent.new(variant: :ghost, tag: :a, href: settings_budget_snapshots_path, icon: "arrow-left", size: :sm) { "목록으로" } %>
  </div>

  <%# Comparison headers %>
  <div class="flex gap-4 mb-6">
    <%= render CardComponent.new do %>
      <div class="text-center">
        <p class="text-xs text-slate-500 dark:text-slate-400">기준</p>
        <p class="font-semibold text-slate-900 dark:text-slate-100">v<%= @snapshot_a.version %> (<%= @snapshot_a.trigger %>)</p>
        <p class="text-xs text-slate-400 dark:text-slate-500"><%= @snapshot_a.calculated_at&.strftime("%Y-%m-%d") %></p>
      </div>
    <% end %>
    <div class="flex items-center text-slate-400 dark:text-slate-500 font-medium">vs</div>
    <%= render CardComponent.new do %>
      <div class="text-center">
        <p class="text-xs text-slate-500 dark:text-slate-400">비교 대상</p>
        <p class="font-semibold text-slate-900 dark:text-slate-100">v<%= @snapshot_b.version %> (<%= @snapshot_b.trigger %>)</p>
        <p class="text-xs text-slate-400 dark:text-slate-500"><%= @snapshot_b.calculated_at&.strftime("%Y-%m-%d") %></p>
      </div>
    <% end %>
  </div>

  <% if @diff.empty? %>
    <%= render EmptyStateComponent.new(
      icon: "check-circle",
      title: "변경 사항 없음",
      description: "두 스냅샷의 값이 동일합니다."
    ) %>
  <% else %>
    <%
      field_labels = {
        available_cash: "유용자금",
        repair_cost: "수선비",
        acquisition_tax: "취득세",
        scrivener_fee: "법무사비",
        moving_cost: "이사비",
        maintenance_fee: "관리비",
        loan_ratio: "대출 비율",
        max_bid_amount: "최대입찰가",
        failed_auction_rounds: "유찰 회차",
        searchable_appraisal_limit: "검색 가능 감정가"
      }

      diff_rows = @diff.map do |field, change|
        was_val = field == :loan_ratio ? "#{(change[:was].to_f * 100).round}%" : (change[:was].is_a?(Numeric) ? number_with_delimiter(change[:was]) : change[:was])
        now_val = field == :loan_ratio ? "#{(change[:now].to_f * 100).round}%" : (change[:now].is_a?(Numeric) ? number_with_delimiter(change[:now]) : change[:now])
        { label: field_labels[field] || field.to_s, was: was_val, now: now_val, delta: change[:delta] }
      end
    %>
    <%= render CompareTableComponent.new(diff: diff_rows) %>
  <% end %>
</div>
```

- [ ] **Step 5: Verify all tests pass**

Run: `bin/rails test`
Expected: All tests PASS

- [ ] **Step 6: Commit**

```bash
git add app/views/settings/budgets/show.html.erb app/views/settings/budget_snapshots/index.html.erb app/views/settings/budget_snapshots/show.html.erb app/views/settings/budget_snapshots/compare.html.erb
git commit -m "feat: redesign settings and snapshot views with CardComponent, SummaryTable, dark mode"
```

---

## Task 15: Final Verification and Cleanup

**Files:**
- Review all modified files

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: All tests PASS

- [ ] **Step 2: Run RuboCop**

Run: `bin/rubocop`
Expected: No offenses (or fix any new offenses)

- [ ] **Step 3: Run Brakeman security scan**

Run: `bin/brakeman --quiet --no-pager`
Expected: No warnings

- [ ] **Step 4: Build Tailwind and verify**

Run: `bin/rails tailwindcss:build`
Expected: Build succeeds without errors

- [ ] **Step 5: Fix any issues found**

Address any test failures, lint issues, or security warnings discovered in steps 1-4.

- [ ] **Step 6: Final commit (if fixes needed)**

```bash
git add -A
git commit -m "chore: fix lint and test issues from UI redesign"
```
