# Tab Rating Badge Design

## Context

The inspection analysis screen has 6 content tabs (매각물건명세서, 등기부등본, 건축물대장, 온라인조회, 현장임장, 기타) plus a final grade tab. Currently, tab labels show only a `checked/total` count. Users want to see at-a-glance safety ratings per tab after saving, and the page should scroll to top after save.

## Requirements

1. **Per-tab rating badge**: After saving a tab, display a colored text badge (안전/주의/경고) before the tab label
2. **Rating calculation**: Reuse existing 4-level rating logic (safe/caution/danger/incomplete) scoped to each tab's results
3. **Scroll to top on save**: After clicking "저장", the page scrolls to the top of the tab view

## Design Decisions

- **Badge style**: Korean text badge with colored background (not dots, not emojis)
- **Rating logic**: Extend `InspectionRatingService` with a `tab_rating(tab_key)` method
- **Display timing**: Badge appears only for tabs that have been fully answered (all `has_risk` non-nil). Tabs with no results or incomplete results show no badge.
- **Grade tab**: Never shows a badge (it displays the overall rating separately)

## Rating Calculation

`InspectionRatingService#tab_rating(tab_key)` returns:

| Condition | Return | Badge |
|-----------|--------|-------|
| No results for tab | `nil` | None |
| Any `has_risk` is nil | `:incomplete` | None |
| Any risk with `resolvable: false` | `:danger` | 경고 (red) |
| Any risk (all resolvable) | `:caution` | 주의 (yellow) |
| No risks | `:safe` | 안전 (green) |

This is identical to the existing `call` logic but scoped to a single tab's `InspectionResult` records.

## Badge Styling (Tailwind)

| Rating | Text | Classes |
|--------|------|---------|
| `:safe` | 안전 | `bg-green-800 text-green-200 text-[10px] font-semibold px-1.5 py-0.5 rounded` |
| `:caution` | 주의 | `bg-yellow-800 text-yellow-200 text-[10px] font-semibold px-1.5 py-0.5 rounded` |
| `:danger` | 경고 | `bg-red-800 text-red-200 text-[10px] font-semibold px-1.5 py-0.5 rounded` |

Badge is placed before the tab label text, inside the existing `link_to` block.

## Scroll to Top

The controller's `update` action redirects with `anchor: "top"`. The edit view gets an `id="top"` element at the top of the page content.

## Files to Modify

| File | Change |
|------|--------|
| `app/services/inspection_rating_service.rb` | Add `tab_rating(tab_key)` method |
| `app/components/inspection_tabs_component.rb` | Compute rating per tab via service, pass to template |
| `app/components/inspection_tabs_component.html.erb` | Render text badge before tab label |
| `app/views/inspections/tabs/edit.html.erb` | Add `id="top"` anchor element |
| `app/controllers/inspections/tabs_controller.rb` | Add `anchor: "top"` to redirect |

## Verification

1. Save a tab with all items answered as safe → tab shows green "안전" badge
2. Save a tab with a resolvable risk → tab shows yellow "주의" badge
3. Save a tab with an unresolvable risk → tab shows red "경고" badge
4. Tab with unanswered items → no badge displayed
5. Tab never saved → no badge displayed
6. After save, page scrolls to top of the tab view
7. Grade tab never shows a badge
