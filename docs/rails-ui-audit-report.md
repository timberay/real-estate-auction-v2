# Rails UI Design System Audit Report

**Date:** 2026-04-12
**Audited against:** `design_tokens.json` v2.0.0, `DESIGN.md`

---

## Summary

| Severity | Count |
|----------|-------|
| Critical | 3 |
| High | 10 |
| Medium | 9 |
| Low | 3 |

---

## Critical Violations

### C1. `text-xs` usage (minimum font size = `text-sm`)

Rule: No font size smaller than `text-sm` (14px). `text-xs` (12px) is prohibited.

| # | File | Line(s) | Current | Fix |
|---|------|---------|---------|-----|
| 1 | `app/views/search_results/_inline_result_item.html.erb` | 10, 15, 16, 18 | `text-xs` on badge, prices, address | Replace with `text-sm` |
| 2 | `app/views/search_results/_inline_result_item_error.html.erb` | 6 | `text-xs text-red-500` | Replace with `text-sm` |
| 3 | `app/views/search_results/_inline_error.html.erb` | 7 | `text-xs` on close button | Replace with `text-sm` |
| 4 | `app/views/search_results/_inline_results.html.erb` | 9 | `text-xs text-amber-500` | Replace with `text-sm` |
| 5 | `app/views/search_results/index.html.erb` | 18 | `text-xs text-slate-500` | Replace with `text-sm` |
| 6 | `app/views/properties/documents/_form.html.erb` | 2 | `text-xs text-amber-600` | Replace with `text-sm` |
| 7 | `app/views/properties/documents/_list.html.erb` | 8 | `text-xs` on delete button | Replace with `text-sm` |
| 8 | `app/views/settings/data_sources/show.html.erb` | 32 | `text-xs text-yellow-700` | Replace with `text-sm` |
| 9 | `app/views/inspections/_layout.html.erb` | 8, 10, 12 | `text-xs` on badges | Replace with `text-sm` |
| 10 | `app/components/property_card_component.html.erb` | 8, 10, 12, 15 | `text-xs` on badges | Replace with `text-sm` |
| 11 | `app/components/rights_report_section_component.html.erb` | 51 | `text-xs` in table cell | Replace with `text-sm` |
| 12 | `app/components/inspection_item_component.html.erb` | 54 | `text-xs` in evidence block | Replace with `text-sm` |
| 13 | `app/components/rights_timeline_component.html.erb` | 29, 34 | `text-xs` on badge and cards | Replace with `text-sm` |

### C2. `settings/data_sources/show.html.erb` — uses `gray-*` instead of `slate-*`, no dark mode, no focus rings

| # | File | Line(s) | Current | Fix |
|---|------|---------|---------|-----|
| 1 | `app/views/settings/data_sources/show.html.erb` | 3-67 | `text-gray-600`, `border-gray-200`, `bg-gray-200`, `bg-gray-100`, etc. | Replace all `gray-*` with `slate-*` equivalents |
| 2 | Same file | Entire file | No `dark:` variants anywhere | Add dark mode classes throughout |
| 3 | Same file | 51, 55, 59 | Buttons missing focus-visible rings | Add `focus-visible:ring-2 focus-visible:ring-blue-500/50` |
| 4 | Same file | 3 | Sub-page adds own padding `px-4 py-8` | Remove padding, keep `max-w-2xl mx-auto` |
| 5 | Same file | 28 | Arbitrary values `top-[2px]`, `start-[2px]` | Acceptable for toggle switch (exception for complex positioning) |

### C3. Badge backgrounds use `*-50` (below light mode minimum contrast)

Rule: Badge backgrounds must be `*-200`+, status card backgrounds `*-100`+.

| # | File | Line(s) | Current | Fix |
|---|------|---------|---------|-----|
| 1 | `app/components/badge_component.rb` | 6-10 | `bg-green-50`, `bg-yellow-50`, `bg-red-50`, `bg-blue-50`, `bg-amber-50` | Replace with `bg-green-200`, `bg-yellow-200`, `bg-red-200`, `bg-blue-200`, `bg-amber-200` |

---

## High Violations

### H1. Status container backgrounds use `*-50` (should be `*-100`+)

| # | File | Line(s) | Current | Fix |
|---|------|---------|---------|-----|
| 1 | `app/components/report_summary_component.rb` | 3-5 | `bg-green-50`, `bg-yellow-50`, `bg-red-50` | Replace with `bg-green-100`, `bg-yellow-100`, `bg-red-100` |
| 2 | `app/components/grade_summary_component.rb` | 3-6 | `bg-green-50`, `bg-yellow-50`, `bg-red-50`, `bg-slate-50` | Replace with `bg-green-100`, `bg-yellow-100`, `bg-red-100`, `bg-slate-100` |
| 3 | `app/components/dividend_simulator_component.rb` | 3-5 | `bg-green-50`, `bg-yellow-50`, `bg-red-50` | Replace with `bg-green-100`, `bg-yellow-100`, `bg-red-100` |
| 4 | `app/components/rights_report_section_component.html.erb` | 7, 34 | `bg-green-50`, `bg-amber-50` | Replace with `bg-green-100`, `bg-amber-100` |
| 5 | `app/components/report_summary_component.html.erb` | 33 | `bg-amber-50` | Replace with `bg-amber-100` |
| 6 | `app/components/risk_items_list_component.html.erb` | 7, 20 | `bg-red-50`, `bg-yellow-50` | Replace with `bg-red-100`, `bg-yellow-100` |
| 7 | `app/views/settings/budgets/show.html.erb` | 6, 12 | `bg-green-50`, `bg-red-50` | Replace with `bg-green-100`, `bg-red-100` |
| 8 | `app/views/settings/budget_snapshots/index.html.erb` | 9 | `bg-green-50` | Replace with `bg-green-100` |
| 9 | `app/views/onboardings/step1.html.erb` | 11 | `bg-red-50` | Replace with `bg-red-100` |
| 10 | `app/views/onboardings/step3.html.erb` | 13, 59 | `bg-red-50`, `bg-blue-50` | Replace with `bg-red-100`, `bg-blue-100` |

### H2. Borders use `*-300` (should be `*-400`+)

| # | File | Line(s) | Current | Fix |
|---|------|---------|---------|-----|
| 1 | `app/components/report_summary_component.rb` | 3-5 | `border-green-300`, `border-yellow-300`, `border-red-300` | Replace with `border-green-400`, `border-yellow-400`, `border-red-400` |
| 2 | `app/components/grade_summary_component.rb` | 3-6 | `border-green-300`, `border-yellow-300`, `border-red-300`, `border-slate-300` | Replace with `border-green-400`, `border-yellow-400`, `border-red-400`, `border-slate-400` |
| 3 | `app/components/rights_report_section_component.html.erb` | 7, 34 | `border-green-300`, `border-amber-300` | Replace with `border-green-400`, `border-amber-400` |
| 4 | `app/components/report_summary_component.html.erb` | 33 | `border-amber-300` | Replace with `border-amber-400` |
| 5 | `app/components/risk_items_list_component.html.erb` | 7, 20 | `border-red-300`, `border-yellow-300` | Replace with `border-red-400`, `border-yellow-400` |
| 6 | `app/components/registry_timeline_component.html.erb` | 10, 27 | `border-red-300`, `border-green-300` | Replace with `border-red-400`, `border-green-400` |
| 7 | `app/views/search_results/_inline_error.html.erb` | 7 | `border-red-300` | Replace with `border-red-400` |
| 8 | `app/components/inspection_item_component.html.erb` | 114, 155 | `border-yellow-300` | Replace with `border-yellow-400` |

### H3. Arbitrary pixel values (not calc-based)

| # | File | Line(s) | Current | Fix |
|---|------|---------|---------|-----|
| 1 | `app/components/rights_timeline_component.html.erb` | 6 | `min-w-[400px]` | Replace with `min-w-96` (384px) or acceptable design value |

### H4. Missing dark mode variants on interactive elements

| # | File | Line(s) | Current | Fix |
|---|------|---------|---------|-----|
| 1 | `app/views/properties/documents/_form.html.erb` | 10 | submit button `bg-slate-600` — no `dark:` variant | Add dark mode classes |
| 2 | `app/views/properties/documents/_list.html.erb` | 8 | delete button `text-red-500 hover:text-red-700` — no dark mode | Add dark mode classes |
| 3 | `app/components/dividend_simulator_component.html.erb` | 17 | submit button — no dark mode or focus ring | Add dark mode + focus ring |
| 4 | `app/views/search_results/_inline_result_item.html.erb` | 5, 10, 15, 16, 18 | Multiple elements missing dark mode variants | Add dark mode |

---

## Medium Violations

### M1. `*-50` backgrounds in non-badge/non-status contexts (informational)

These `*-50` backgrounds are used for subtle highlights (table headers, alternating rows, source doc containers) within dark-bordered cards, where contrast is adequate. Lower priority.

| # | File | Pattern |
|---|------|---------|
| 1 | `app/components/source_doc_viewer_component.html.erb` | `bg-amber-50`, `bg-red-50` in standalone containers |
| 2 | `app/views/inspections/_layout.html.erb` | `bg-amber-50` in price badges |
| 3 | `app/views/properties/documents/_form.html.erb` | `file:bg-blue-50` for file input |
| 4 | `app/components/dividend_simulator_component.html.erb` | `bg-amber-50` in disclaimer |
| 5 | `app/components/inspection_item_component.html.erb` | `bg-yellow-50` in override/resolution sections |
| 6 | `app/components/rights_timeline_component.html.erb` | `bg-blue-50`, `bg-red-50`, `bg-slate-50` in cards |
| 7 | `app/components/registry_timeline_component.html.erb` | `bg-red-50`, `bg-green-50` in timeline cards |
| 8 | `app/views/search_results/_inline_result_item_error.html.erb` | `bg-red-50` in error card |
| 9 | `app/views/search_results/_inline_error.html.erb` | `bg-red-50` in error card |

### M2. `border-slate-300` usage

`border-slate-300` is used in several places (checkboxes, dashed borders, inputs). For slate specifically, `-300` is borderline acceptable as it provides adequate contrast. Tracked but not auto-fixed.

### M3. Missing focus-visible rings on some interactive elements

Various buttons and links missing `focus-visible:ring-*` classes, but lower severity as they are non-primary interactions (inline links, delete buttons, etc.).

---

## Low Violations

### L1. Evidence block in inspection_item uses very light text colors

`app/components/inspection_item_component.rb` lines 140-152: uses `text-red-300`, `text-indigo-300`, `text-slate-300`, `text-slate-200` which may be hard to read in light mode. These appear to be inside a dark-background evidence block, so actual visibility depends on context.

### L2. `hover:bg-slate-50` and `hover:border-slate-300` in various components

Used for hover states on light backgrounds. Technically below the `-100` floor but acceptable for hover-only ephemeral states.

### L3. `bg-slate-50` as semantic primary background

Used correctly per design tokens (`semantic.bg.primary = bg-slate-50`). Not a violation.

---

## Files With No Violations

- `app/views/layouts/application.html.erb` - Fully compliant
- `app/components/card_component.html.erb` - Compliant
- `app/components/sidebar/component.rb` - Compliant
- `app/components/button_component.rb` - Compliant (has focus rings, dark mode)
- `app/components/header/component.html.erb` - Compliant
- `app/components/toast_component.html.erb` - Compliant
- All Stimulus controllers - No UI class violations (pure JS)
