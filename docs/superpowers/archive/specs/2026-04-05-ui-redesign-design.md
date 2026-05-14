# UI Redesign — Full Layout & Content Improvement

## 1. Overview

Redesign the entire application UI to comply with `DESIGN.md` and `design_tokens.json` specifications. This includes installing the CSS/component infrastructure, building the App Shell layout, creating reusable ViewComponents, and redesigning all existing views.

### App Name

**Oh My Auction**

### Current State

- No Tailwind CSS build pipeline (classes used but no gem/config)
- No ViewComponent library
- No Heroicons
- Bare layout: `<body><%= yield %></body>` — no header, sidebar, or footer
- No dark mode support
- All views are standalone monolithic templates
- No shared partials or reusable components

### Target State

- Full Tailwind CSS pipeline with dark mode (`darkMode: 'class'`)
- ViewComponent-based reusable UI components
- App Shell layout (Header + Sidebar + Main Content + Footer)
- Dark mode toggle with localStorage persistence
- All existing views redesigned to DESIGN.md spec
- Responsive: mobile drawer → tablet collapsed → desktop expanded sidebar

---

## 2. Approach

**Bottom-Up (Component → Layout → Views)**

1. Install gems + configure Tailwind
2. Build base ViewComponents
3. Build App Shell layout (Header → Sidebar → Footer)
4. Create Stimulus controllers (sidebar, dark-mode, dropdown, toast)
5. Redesign all existing views using components

---

## 3. Infrastructure

### 3.1 Gem Installation

| Gem | Purpose |
|-----|---------|
| `tailwindcss-rails` | Tailwind CSS build pipeline |
| `view_component` | Reusable UI component framework |
| `heroicon` | Heroicons v2 icon library |
| `lookbook` (dev/test) | Component preview browser |

### 3.2 Tailwind Configuration

- `darkMode: 'class'`
- Font family: Pretendard (sans), JetBrains Mono (mono)
- All spacing, radius, shadow, breakpoint values from `design_tokens.json`
- Container max-width: 1280px

---

## 4. App Shell

### 4.1 Layout Structure

```
┌─────────────────────────────────────────────────┐
│  Header (fixed top, h-16, bg-slate-800, z-40)   │
│  "Oh My Auction" | ── spacer ── | 🌙 | 🔔 | 👤  │
├──────────┬──────────────────────────────────────┤
│ Sidebar  │  Main Content Area                   │
│ (fixed)  │  (margin-left = sidebar width)       │
│          │  padding: px-4 py-4 / md:px-6 py-6  │
│ w-64     │                                      │
│ (expand) │  <%= yield %>                        │
│ w-16     │                                      │
│ (collapse)                                      │
│          │  Footer (border-t, text-xs)          │
│ [Toggle] │  © 2026 Oh My Auction                │
└──────────┴──────────────────────────────────────┘
```

### 4.2 Header

- Position: `fixed top-0 left-0 right-0 z-40`
- Height: `h-16`
- Background: `bg-slate-800 dark:bg-slate-900`
- Left: Logo text "Oh My Auction" (`font-bold text-lg text-white`) + hamburger (mobile only)
- Right: dark mode toggle (sun/moon icon) + notification bell + user avatar placeholder

### 4.3 Sidebar Navigation

**Menu Structure (4 groups with dropdown expand/collapse):**

```
물건검색 ▾
  ├─ 예산 설정        (F01) → active
  ├─ 물건 목록        (F02) → active (root_path)
  └─ 시세 조회        (F06) → disabled "준비 중"

권리분석 ▾
  ├─ 권리분석 리포트   (F03) → disabled
  ├─ 수익 계산기      (F04) → disabled
  └─ 대출 매칭        (F07) → disabled

입찰 ▾
  ├─ 진행 체크리스트   (F05) → disabled
  ├─ 가상 입찰        (F08) → disabled
  └─ 사전 임장        (F09) → disabled

낙찰 ▾
  ├─ 명도 가이드      (F10) → disabled
  └─ 전문가 연결      (F11) → disabled
```

**Behavior:**
- Group title click toggles children visibility (Stimulus `dropdown_controller`)
- Disabled items: `opacity-50 cursor-not-allowed`, click shows toast "준비 중입니다"
- Active item: `bg-blue-50 dark:bg-blue-900/50 text-blue-700 dark:text-blue-400 font-medium`
- Bottom: collapse toggle button (chevron-left / chevron-right)

**Responsive:**

| Breakpoint | State | Behavior |
|-----------|-------|----------|
| < 768px (mobile) | Hidden | Hamburger opens overlay drawer (w-64, z-40, backdrop) |
| md: 768px | Collapsed (w-16) | Icon-only, tooltip on hover, groups hidden |
| lg: 1024px+ | Expanded (w-64) | Full icon + label + group dropdowns |

**Icons per menu item (Heroicons v2 outline):**

| Menu Item | Icon |
|-----------|------|
| 예산 설정 | `calculator` |
| 물건 목록 | `magnifying-glass` |
| 시세 조회 | `chart-bar` |
| 권리분석 리포트 | `document-magnifying-glass` |
| 수익 계산기 | `banknotes` |
| 대출 매칭 | `building-library` |
| 진행 체크리스트 | `clipboard-document-check` |
| 가상 입찰 | `play-circle` |
| 사전 임장 | `map-pin` |
| 명도 가이드 | `key` |
| 전문가 연결 | `user-group` |

### 4.4 Footer

- Position: bottom of main content (scrolls with content, not fixed)
- Border: `border-t border-slate-200 dark:border-slate-700`
- Content: `text-xs text-slate-400 dark:text-slate-500 text-center`
- Text: `© 2026 Oh My Auction. All rights reserved.`

### 4.5 Dark Mode Toggle

- Location: Header right side
- Icon: sun (light) / moon (dark), `w-5 h-5`
- Button: `p-2 rounded-md text-slate-300 hover:text-white hover:bg-slate-700`
- Persistence: `localStorage` key `dark-mode`
- On load: check localStorage, then `prefers-color-scheme`

---

## 5. ViewComponents

### 5.1 Core Components

| Component | File | Variants/Options |
|-----------|------|-----------------|
| `ButtonComponent` | `app/components/button_component.rb` | variant: primary/secondary/outline/danger/ghost/link, size: sm/md/lg, icon, disabled, loading |
| `CardComponent` | `app/components/card_component.rb` | header/body/footer slots, title, description |
| `BadgeComponent` | `app/components/badge_component.rb` | variant: default/success/warning/danger/info/accent |
| `InputComponent` | `app/components/input_component.rb` | label, error, help_text, required, suffix, inputmode |
| `SelectComponent` | `app/components/select_component.rb` | label, options, error, prompt |
| `ToastComponent` | `app/components/toast_component.rb` | type: success/warning/danger/info, message, auto-dismiss |
| `EmptyStateComponent` | `app/components/empty_state_component.rb` | icon, title, description, CTA button |
| `Header::Component` | `app/components/header/component.rb` | app_name |
| `Sidebar::Component` | `app/components/sidebar/component.rb` | menu_items, current_page |

### 5.2 Page-Specific Components

| Component | File | Usage |
|-----------|------|-------|
| `WizardStepComponent` | `app/components/wizard_step_component.rb` | Onboarding steps 1-3: title, description, current_step, total_steps, progress bar |
| `SummaryTableComponent` | `app/components/summary_table_component.rb` | Key-value display: complete page, snapshot show (replaces `<table>` with flex rows) |
| `SnapshotCardComponent` | `app/components/snapshot_card_component.rb` | Snapshot list item: version, trigger badge, amount, date, actions |
| `CompareTableComponent` | `app/components/compare_table_component.rb` | Snapshot comparison: CSS Grid, delta coloring (green +, red -) |
| `StatCardComponent` | `app/components/stat_card_component.rb` | Hero number card: max bid amount display, label, sublabel |

---

## 6. Stimulus Controllers

| Controller | File | Responsibility |
|-----------|------|----------------|
| `sidebar_controller` | `sidebar_controller.js` | Toggle expanded/collapsed, mobile drawer open/close, backdrop, localStorage `sidebar-collapsed`, margin-left transition on main content |
| `dark_mode_controller` | `dark_mode_controller.js` | Toggle `dark` class on `<html>`, swap sun/moon icon, localStorage `dark-mode`, respect `prefers-color-scheme` on initial load |
| `dropdown_controller` | `dropdown_controller.js` | Sidebar group expand/collapse, rotate chevron indicator |
| `toast_controller` | `toast_controller.js` | Show/auto-dismiss toast notifications (5s), slide-in animation, support for disabled menu click feedback |

Existing controllers (`number_format`, `reserve_fund`, `loan_slider`, `navigation`, `area_unit`, `failed_rounds`) are preserved unchanged.

---

## 7. View Redesign

### 7.1 Onboarding Wizard (step1, step2, step3)

**Changes:**
- Wrap each step in `WizardStepComponent` with 3-step progress bar
- Remove self-contained `container`, `px-*`, `py-*`, `max-w-*` (App Shell manages padding)
- `WizardStepComponent` applies `max-w-lg mx-auto` internally (form page exception per DESIGN.md)
- Replace inline form fields with `InputComponent` / `SelectComponent`
- Replace inline buttons with `ButtonComponent` (with Heroicons: arrow-right, arrow-left)
- All colors: `gray-*` → `slate-*` with `dark:` variants
- Korean text: `break-keep` applied globally via body class

### 7.2 Onboarding Complete

**Changes:**
- Max bid hero → `StatCardComponent` (bg-blue-600, large number)
- Cost breakdown table → `SummaryTableComponent` (flex rows, no `<table>`)
- CTA buttons → `ButtonComponent` (primary: "내 예산 범위 물건 보기", outline: "설정 다시 하기")
- Failed rounds alert → `BadgeComponent`(warning) + text

### 7.3 Settings > Budget (settings/budgets/show)

**Changes:**
- 3 sections each wrapped in `CardComponent` (유용자금 / 예비비 / 대출 정책)
- Form fields → `InputComponent`, `SelectComponent`
- Current max bid → `StatCardComponent`
- Action buttons → `ButtonComponent` with icons (bookmark-square, arrow-path)

### 7.4 Snapshot Index (budget_snapshots/index)

**Changes:**
- Each snapshot → `SnapshotCardComponent`
- Compare form → `CardComponent` with `SelectComponent` + `ButtonComponent`
- Empty state → `EmptyStateComponent` (icon: clock, "저장된 스냅샷이 없습니다")

### 7.5 Snapshot Show (budget_snapshots/show)

**Changes:**
- Max bid → `StatCardComponent`
- Detail table → `SummaryTableComponent`
- Recalculate button → `ButtonComponent` (variant: :outline, icon: arrow-path)

### 7.6 Snapshot Compare (budget_snapshots/compare)

**Changes:**
- Comparison headers → 2 mini `CardComponent` with "vs" separator
- Diff table → `CompareTableComponent` (CSS Grid, delta colors)
- No diff state → `EmptyStateComponent`

### 7.7 Home (home/index)

**Changes:**
- F02 placeholder → `EmptyStateComponent` (icon: magnifying-glass, "물건 목록이 준비 중입니다", CTA: "예산 설정하기")
- Budget summary → `StatCardComponent` + `ButtonComponent` (link variant)

---

## 8. Quality Checklist

Per DESIGN.md / SKILL.md quality requirements:

- [ ] Only design token values used (no arbitrary `[...]` values except `calc()`)
- [ ] All components follow DESIGN.md specs
- [ ] Reusable patterns extracted into ViewComponents
- [ ] Turbo Frame IDs preserved for wizard flow
- [ ] Mobile-first responsive design verified
- [ ] `focus-visible` ring on all interactive elements
- [ ] `break-keep` on Korean text (body class)
- [ ] No inline styles
- [ ] All components include `dark:` variant classes
- [ ] No text smaller than `text-xs` (12px)
- [ ] Action buttons have Heroicons (no text-only action buttons)
- [ ] Sub-pages have no own padding/margin/max-width (except form pages with internal max-w)
- [ ] Brand colors use blue group classes (active brand = blue)
- [ ] Disabled menu items show "준비 중" feedback
