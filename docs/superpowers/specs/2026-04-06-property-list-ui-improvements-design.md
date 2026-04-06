# Property List UI Improvements Design Spec

## Context

The properties index page has several UI issues that need addressing:
- The case number input form uses a raw `text_field` instead of the `InputComponent`, doesn't follow design token conventions, and spans full width unnecessarily.
- Price labels ("감정가", "최저가") lack clarity — no tooltips explaining what these values mean for users unfamiliar with auction terminology.
- There is no visual indicator when a property's appraisal price exceeds the user's configured budget (`max_bid_amount`).
- The grid layout maxes out at 3 columns on desktop, wasting space on wider screens.

## Changes

### 1. Case Number Input Form Redesign

**Problem:** Raw `text_field` with full-width layout, no label, no help text. Doesn't use `InputComponent`.

**Solution:**
- Replace raw `text_field` with `InputComponent` (label + help text + placeholder)
- Label: "경매번호로 물건 추가"
- Help text: "법원 경매 사건번호를 입력하세요"
- Placeholder: "예: 2026타경1234"
- Constrain width with `max-w-md`
- Add `size` option to `InputComponent` (`sm`/`md`/`lg`) so input height matches the adjacent `ButtonComponent`
  - `sm`: `py-1.5` (32px)
  - `md`: `py-2.5` (40px) — default, matches ButtonComponent default
  - `lg`: `py-3` (48px)
- Update DESIGN.md to document the size option

**Files:**
- `app/components/input_component.rb` — add `size:` parameter
- `app/components/input_component.html.erb` — apply size classes
- `app/views/properties/index.html.erb` — replace raw form with InputComponent
- `~/.claude/skills/rails-ui/DESIGN.md` — document input size option

### 2. Price Labels with Tooltips

**Problem:** Current card shows "감정가 80,000만원" and "최저가 56,000만원" in a single line with no explanation.

**Solution:**
- Split prices into two rows with label-value `justify-between` layout
- Rename "최저가" → "최저매각가" for accuracy
- Add hover tooltips via a Stimulus `tooltip` controller:
  - 감정가: "감정평가사가 책정한 시장가치"
  - 최저매각가: "법원이 정한 최소 입찰금액"
- Tooltip: small `absolute` positioned element on hover, styled per design tokens

**Files:**
- `app/components/property_card_component.html.erb` — restructure price display
- `app/javascript/controllers/tooltip_controller.js` — new Stimulus controller for hover tooltips

### 3. Budget Exceeded Badge

**Problem:** No indication when a property's appraisal price exceeds the user's max bid amount.

**Solution:**
- Add `max_bid_amount:` parameter to `PropertyCardComponent`
- When `appraisal_price > max_bid_amount` (and max_bid_amount is set), show a warning badge next to the case number and safety badge
- Use `BadgeComponent.new(variant: :warning)` with text "예산 초과"
- Comparison criterion: `appraisal_price > max_bid_amount` (conservative — appraisal price, not min bid price)
- Controller passes `current_user.budget_setting&.max_bid_amount` to the component

**Files:**
- `app/components/property_card_component.rb` — add `max_bid_amount:` param, `budget_exceeded?` helper
- `app/components/property_card_component.html.erb` — render warning badge conditionally
- `app/controllers/properties_controller.rb` — pass `max_bid_amount` to view
- `app/views/properties/index.html.erb` — pass `max_bid_amount` to PropertyCardComponent

### 4. Responsive 4-Column Grid

**Problem:** Grid maxes out at 3 columns (`sm:grid-cols-2 lg:grid-cols-3`).

**Solution:**
- Change to: `sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4`
- Breakpoints: mobile 1col / sm(640px) 2col / md(768px) 3col / lg(1024px) 4col

**Files:**
- `app/views/properties/index.html.erb` — update grid classes

## Out of Scope

- Tooltip component extraction (inline Stimulus controller is sufficient for now)
- Budget setting creation/editing UI
- Real API adapter implementation (remains mock)

## Verification

1. Run `bin/rails test` — all existing tests pass
2. Run `bin/rubocop` — no style violations
3. Manual browser check at different viewport widths (mobile/tablet/desktop) to verify responsive grid
4. Verify tooltip hover behavior on price labels
5. Verify "예산 초과" badge appears only when `appraisal_price > max_bid_amount`
6. Verify input and button height alignment in the case number form
