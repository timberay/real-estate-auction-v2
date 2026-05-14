# Rails-UI 스킬 업그레이드 + 프로젝트 UI 위반 수정 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** rails-ui 스킬에 감사에서 발견된 6가지 범용 규칙을 추가하고, 프로젝트 내 ~70건의 UI 위반을 수정한다.

**Architecture:** 2단계 — Phase 1에서 스킬 파일(SKILL.md, DESIGN.md)을 업그레이드하고, Phase 2에서 업그레이드된 지침 기준으로 프로젝트 코드를 수정한다. 모든 변경은 구조적(Tidy First) 커밋으로 처리한다.

**Tech Stack:** Tailwind CSS, ViewComponent, Heroicons v2, Stimulus

---

## Phase 1: Rails-UI 스킬 업그레이드 (범용 규칙 추가)

### Task 1: SKILL.md — 인라인 style 예외 규칙 추가

**Files:**
- Modify: `~/.claude/skills/rails-ui/SKILL.md:42-46`

- [ ] **Step 1: "Strictly Prohibited" 섹션의 inline styles 항목에 예외 추가**

현재 코드:
```
- Inline styles (`style=""` attributes)
```

수정:
```
- Inline styles (`style=""` attributes)
  - **Exception:** Dynamic percentage widths (e.g., progress bars) may use `style="width: #{percent}%"` when Tailwind utility classes cannot express the value
```

- [ ] **Step 2: Commit**

```bash
git add ~/.claude/skills/rails-ui/SKILL.md
git commit -m "style(rails-ui): add inline style exception for dynamic percentage widths"
```

---

### Task 2: SKILL.md — ViewComponent 일관 사용 규칙 추가

**Files:**
- Modify: `~/.claude/skills/rails-ui/SKILL.md:157` (ViewComponent Generation Rules 섹션 앞에 추가)

- [ ] **Step 1: "Strictly Prohibited" 섹션 끝에 2가지 규칙 추가**

Light Mode Minimum Contrast 규칙 뒤(line 155 이후), ViewComponent Generation Rules 앞에 추가:

```markdown
### Component Reuse Rules

- **All form inputs MUST use ViewComponents** (InputComponent, SelectComponent, etc.). Raw `<input>`, `<select>`, `<textarea>` tags in templates cause height/style inconsistency. Exception: hidden fields (`type="hidden"`) and radio/checkbox inputs within labeled groups.
- **All badge-like elements MUST use BadgeComponent.** Inline badge styling (`text-xs bg-blue-600 text-white px-1.5 py-0.5 rounded`) is prohibited — use BadgeComponent with the appropriate variant instead.
```

- [ ] **Step 2: Quality Checklist에 항목 추가**

```markdown
- [ ] **Form inputs use ViewComponents (no raw `<input>`/`<select>` except hidden/radio/checkbox)?**
- [ ] **Badge-like elements use BadgeComponent (no inline badge classes)?**
```

- [ ] **Step 3: Commit**

```bash
git add ~/.claude/skills/rails-ui/SKILL.md
git commit -m "style(rails-ui): add component reuse rules for forms and badges"
```

---

### Task 3: SKILL.md — 이모지 대신 아이콘 사용 규칙 추가

**Files:**
- Modify: `~/.claude/skills/rails-ui/SKILL.md:104-109` (Icon-First Rule 섹션)

- [ ] **Step 1: Icon-First Rule 섹션에 이모지 금지 규칙 추가**

기존 마지막 줄 뒤에 추가:
```markdown
- **No emoji as UI icons** — do not use emoji characters (📋, ✏️, ✓, ▶) for decorative or action icons. Use Heroicons consistently. Exception: emoji in user-generated content or inline text emphasis.
```

- [ ] **Step 2: Commit**

```bash
git add ~/.claude/skills/rails-ui/SKILL.md
git commit -m "style(rails-ui): prohibit emoji as UI icons, require Heroicons"
```

---

### Task 4: DESIGN.md — Wizard / Step Flow 컴포넌트 스펙 추가

**Files:**
- Modify: `~/.claude/skills/rails-ui/DESIGN.md` (Section 3.11 Pagination 뒤에 추가)

- [ ] **Step 1: Section 3.12 Wizard / Step Flow 추가**

Section 3.11 뒤에:
```markdown
### 3.12 Wizard / Step Flow

**Used for:** Multi-step forms, onboarding flows, guided processes.

```
Progress bar:  h-1 bg-slate-200 dark:bg-slate-700 rounded-full (track)
               h-1 bg-{brand}-600 dark:bg-{brand}-400 rounded-full transition-all (fill)
               Dynamic width via style="width: {percent}%" (inline style exception)
Progress text: text-sm text-slate-500 dark:text-slate-400 mt-1

Step indicator: text-sm font-medium text-slate-500 dark:text-slate-400
Active step:    text-{brand}-600 dark:text-{brand}-400 font-semibold

Navigation:     flex justify-between mt-6
Back button:    ButtonComponent(variant: :outline, icon: "arrow-left")
Next button:    ButtonComponent(variant: :primary, icon: "arrow-right")

Turbo Frame:    turbo-frame id="{wizard_name}_step" for step transitions
```

**Rules:**
- Progress bar fills dynamically — this is the one allowed use of inline `style="width:"` (see SKILL.md exception)
- Step content renders inside a Turbo Frame for seamless transitions
- Each step is a partial or ViewComponent, not a separate page
- "Back" always navigates to previous step; "Next" validates before advancing
```

- [ ] **Step 2: Commit**

```bash
git add ~/.claude/skills/rails-ui/DESIGN.md
git commit -m "style(rails-ui): add wizard/step flow component spec (Section 3.12)"
```

---

### Task 5: DESIGN.md — Accordion / Collapsible 컴포넌트 스펙 추가

**Files:**
- Modify: `~/.claude/skills/rails-ui/DESIGN.md` (새 Section 3.12 뒤에 추가)

- [ ] **Step 1: Section 3.13 Accordion / Collapsible 추가**

```markdown
### 3.13 Accordion / Collapsible

**Stimulus Controller:** `accordion_controller`

```
Container:     rounded-lg border border-slate-200 dark:border-slate-700
Header button: w-full px-4 py-3 flex items-center justify-between
               hover:bg-slate-50 dark:hover:bg-slate-800/50 rounded-lg
               focus-visible:ring-2 focus-visible:ring-{brand}-500/50 focus-visible:ring-offset-2
               dark:focus-visible:ring-{brand}-400/50 dark:focus-visible:ring-offset-slate-900
Toggle icon:   Heroicon chevron-down (w-5 h-5, transition-transform duration-200)
               Open state: rotate-180
Content:       hidden (closed) / block (open)
               border-t border-slate-200 dark:border-slate-700 px-4 py-4
Animation:     Stimulus value callback toggles hidden class
```

**Rules:**
- Toggle icon MUST be a Heroicon (chevron-down/chevron-up). Unicode arrows (▶, ▼) are prohibited.
- Accordion button requires `focus-visible:ring` for keyboard accessibility.
- Use Stimulus `values` API for open/closed state (`data-accordion-open-value`).
- Content toggle via `openValueChanged()` callback, not direct DOM manipulation in action handlers.
```

- [ ] **Step 2: Commit**

```bash
git add ~/.claude/skills/rails-ui/DESIGN.md
git commit -m "style(rails-ui): add accordion/collapsible component spec (Section 3.13)"
```

---

## Phase 2: 프로젝트 UI 위반 수정

### Task 6: 앱쉘 패딩 일관성 — Header + Footer

**Files:**
- Modify: `app/components/header/component.rb:5`
- Modify: `app/views/layouts/application.html.erb:69`

- [ ] **Step 1: Header에 반응형 패딩 추가**

`app/components/header/component.rb` line 5:
```ruby
# Before:
HEADER_CLASSES = "fixed top-0 left-0 right-0 z-40 h-16 bg-slate-800 dark:bg-slate-900 flex items-center justify-between px-4"

# After:
HEADER_CLASSES = "fixed top-0 left-0 right-0 z-40 h-16 bg-slate-800 dark:bg-slate-900 flex items-center justify-between px-4 md:px-6"
```

- [ ] **Step 2: Footer에 반응형 패딩 추가**

`app/views/layouts/application.html.erb` line 69:
```erb
<%# Before: %>
<footer class="border-t border-slate-200 dark:border-slate-700 px-4 py-4">

<%# After: %>
<footer class="border-t border-slate-200 dark:border-slate-700 px-4 md:px-6 py-4">
```

- [ ] **Step 3: 브라우저에서 md 브레이크포인트 전후로 Header/Main/Footer 좌측 경계 정렬 확인**

- [ ] **Step 4: Commit**

```bash
git add app/components/header/component.rb app/views/layouts/application.html.erb
git commit -m "fix(layout): align header and footer responsive padding with main content (px-4 md:px-6)"
```

---

### Task 7: Sub-page 레이아웃 소유권 위반 수정 (6개 파일)

**Files:**
- Modify: `app/views/properties/show.html.erb:2`
- Modify: `app/views/analyses/new.html.erb:3`
- Modify: `app/views/eviction_guide/guide.html.erb:4`
- Modify: `app/views/eviction_guide/simulator.html.erb:4`
- Modify: `app/components/eviction_guide/simulator_question_component.html.erb:1`
- Modify: `app/components/eviction_guide/f02_prefill_component.html.erb:1`
- Modify: `app/components/eviction_guide/simulator_result_component.html.erb:1`
- Modify: `app/components/eviction_guide/occupant_type_selector_component.html.erb:1`

주의: 이 컴포넌트들은 Turbo Frame 안에서 렌더링되어 레이아웃의 패딩이 이미 적용된 상태. max-w 제거 후 콘텐츠가 전체 폭을 사용하면 가독성이 떨어질 수 있으므로, 내부 콘텐츠 최대 폭 제한이 필요한 경우 CardComponent 등으로 감싸는 것이 올바른 패턴.

- [ ] **Step 1: properties/show.html.erb — max-w-2xl mx-auto 제거**

```erb
<%# Before: %>
<div class="max-w-2xl mx-auto space-y-4">

<%# After: %>
<div class="space-y-4">
```

- [ ] **Step 2: analyses/new.html.erb — max-w-2xl mx-auto 제거**

```erb
<%# Before: %>
<div class="max-w-2xl mx-auto space-y-4" data-controller="analysis-tabs" ...>

<%# After: %>
<div class="space-y-4" data-controller="analysis-tabs" ...>
```

- [ ] **Step 3: eviction_guide/guide.html.erb — max-w-3xl mx-auto 제거**

```erb
<%# Before: %>
<div class="max-w-3xl mx-auto">

<%# After (wrapper 제거, 내부 콘텐츠만): %>
<div>
```

- [ ] **Step 4: eviction_guide/simulator.html.erb — max-w-3xl mx-auto 제거**

```erb
<%# Before: %>
<div class="max-w-3xl mx-auto">

<%# After: %>
<div>
```

- [ ] **Step 5: simulator_question_component.html.erb — max-w-3xl mx-auto 제거**

```erb
<%# Before (line 1): %>
<div class="max-w-3xl mx-auto">

<%# After: %>
<div>
```

- [ ] **Step 6: f02_prefill_component.html.erb — max-w-2xl mx-auto 제거**

```erb
<%# Before: %>
<div class="max-w-2xl mx-auto">

<%# After: %>
<div>
```

- [ ] **Step 7: simulator_result_component.html.erb — max-w-2xl mx-auto 제거**

```erb
<%# Before: %>
<div class="max-w-2xl mx-auto">

<%# After: %>
<div>
```

- [ ] **Step 8: occupant_type_selector_component.html.erb — max-w-2xl mx-auto 제거**

```erb
<%# Before: %>
<div class="max-w-2xl mx-auto">

<%# After: %>
<div>
```

- [ ] **Step 9: 브라우저에서 각 페이지 확인 — 콘텐츠가 레이아웃 폭에 맞게 렌더링되는지 검증**

- [ ] **Step 10: Commit**

```bash
git add app/views/properties/show.html.erb app/views/analyses/new.html.erb \
  app/views/eviction_guide/guide.html.erb app/views/eviction_guide/simulator.html.erb \
  app/components/eviction_guide/simulator_question_component.html.erb \
  app/components/eviction_guide/f02_prefill_component.html.erb \
  app/components/eviction_guide/simulator_result_component.html.erb \
  app/components/eviction_guide/occupant_type_selector_component.html.erb
git commit -m "fix(layout): remove sub-page max-w/mx-auto wrappers, let layout own spacing"
```

---

### Task 8: text-xs → text-sm 일괄 수정 + arbitrary value 제거

**Files:**
- Modify: `app/components/profit_calculator_component.html.erb` (15+ instances)
- Modify: `app/components/eviction_guide/step_card_component.html.erb` (4 instances + 2 arbitrary)
- Modify: `app/components/inspection_tabs_component.html.erb` (1 instance)
- Modify: `app/components/consultation_guide_component.html.erb` (1 instance)
- Modify: `app/components/grade_summary_component.html.erb` (1 instance)
- Modify: `app/components/eviction_guide/f02_prefill_component.html.erb` (2 instances)
- Modify: `app/components/eviction_guide/simulator_result_component.html.erb` (1 instance)
- Modify: `app/components/eviction_guide/simulator_question_component.html.erb` (3 instances)

- [ ] **Step 1: profit_calculator_component.html.erb — 모든 text-xs를 text-sm으로 교체**

`text-xs` → `text-sm` replace_all. 해당 파일 내 모든 인스턴스:
- line 39, 59, 83, 110, 114, 118, 122, 132, 133, 134, 141, 144, 149, 154, 159, 164, 169, 174, 179, 184, 203

- [ ] **Step 2: step_card_component.html.erb — text-xs → text-sm 교체 + text-[0.7rem] → text-sm 교체**

4곳의 `text-xs` → `text-sm`:
- line 9: `text-xs font-bold` → `text-sm font-bold`
- line 14: `text-xs text-slate-500` → `text-sm text-slate-500`
- line 27: `text-xs text-slate-700` → `text-sm text-slate-700`
- line 32: `text-xs text-slate-700` → `text-sm text-slate-700`

2곳의 `text-[0.7rem]` → `text-sm`:
- line 28: `text-[0.7rem]` → `text-sm`
- line 33: `text-[0.7rem]` → `text-sm`

- [ ] **Step 3: inspection_tabs_component.html.erb — line 26 text-xs → text-sm**

```erb
<%# Before: %>
<span class="ml-1 bg-amber-400 text-amber-900 dark:bg-amber-500 dark:text-amber-950 text-xs font-bold px-1.5 py-0.5 rounded-full">

<%# After: %>
<span class="ml-1 bg-amber-400 text-amber-900 dark:bg-amber-500 dark:text-amber-950 text-sm font-bold px-1.5 py-0.5 rounded-full">
```

- [ ] **Step 4: consultation_guide_component.html.erb — line 10 text-xs → text-sm**

```erb
<%# Before: %>
<span class="font-mono text-xs">

<%# After: %>
<span class="font-mono text-sm">
```

- [ ] **Step 5: grade_summary_component.html.erb — line 5 text-xs → text-sm**

```erb
<%# Before: %>
<p class="mt-1 text-xs text-slate-500 dark:text-slate-400">

<%# After: %>
<p class="mt-1 text-sm text-slate-500 dark:text-slate-400">
```

- [ ] **Step 6: f02_prefill_component.html.erb — line 13, 29 text-xs → text-sm**

```erb
<%# Before (line 13): %>
<span class="text-xs bg-blue-600 text-white px-1.5 py-0.5 rounded">

<%# After: %>
<span class="text-sm bg-blue-600 text-white px-1.5 py-0.5 rounded">
```

line 29도 동일하게 교체.

- [ ] **Step 7: simulator_result_component.html.erb — line 22, 35, 39 text-xs → text-sm**

```erb
<%# Before (line 22): %>
<span class="<%= badge[:classes] %> px-2 py-0.5 rounded text-xs font-medium whitespace-nowrap">

<%# After: %>
<span class="<%= badge[:classes] %> px-2 py-0.5 rounded text-sm font-medium whitespace-nowrap">
```

line 35, 39도 동일.

- [ ] **Step 8: simulator_question_component.html.erb — line 8, 13, 20, 45, 59 text-xs → text-sm**

모든 `text-xs` → `text-sm` replace_all.

- [ ] **Step 9: Commit**

```bash
git add app/components/profit_calculator_component.html.erb \
  app/components/eviction_guide/step_card_component.html.erb \
  app/components/inspection_tabs_component.html.erb \
  app/components/consultation_guide_component.html.erb \
  app/components/grade_summary_component.html.erb \
  app/components/eviction_guide/f02_prefill_component.html.erb \
  app/components/eviction_guide/simulator_result_component.html.erb \
  app/components/eviction_guide/simulator_question_component.html.erb
git commit -m "fix(ui): replace all text-xs with text-sm to meet minimum font size rule"
```

---

### Task 9: Light mode border 컨트라스트 수정

**Files:**
- Modify: `app/components/bid_opinion_component.rb:7,13,19`
- Modify: `app/components/profit_calculator_component.html.erb:27,53`
- Modify: `app/components/dividend_simulator_component.html.erb:12`
- Modify: `app/components/inspection_item_component.html.erb:27,31`
- Modify: `app/components/eviction_guide/tab_navigation_component.html.erb:7`
- Modify: `app/views/eviction_guide/guide.html.erb:6`

- [ ] **Step 1: bid_opinion_component.rb — border-*-300 → border-*-400**

```ruby
# Before:
bg: "bg-green-50 dark:bg-green-900/20 border-green-300 dark:border-green-700",
bg: "bg-yellow-50 dark:bg-yellow-900/20 border-yellow-300 dark:border-yellow-700",
bg: "bg-red-50 dark:bg-red-900/20 border-red-300 dark:border-red-700",
bg: "bg-slate-50 dark:bg-slate-800/50 border-slate-300 dark:border-slate-600",

# After:
bg: "bg-green-100 dark:bg-green-900/20 border-green-400 dark:border-green-700",
bg: "bg-yellow-100 dark:bg-yellow-900/20 border-yellow-400 dark:border-yellow-700",
bg: "bg-red-100 dark:bg-red-900/20 border-red-400 dark:border-red-700",
bg: "bg-slate-100 dark:bg-slate-800/50 border-slate-400 dark:border-slate-600",
```

Note: bg도 *-50 → *-100으로 함께 상향 (Light mode contrast rule).

- [ ] **Step 2: profit_calculator_component.html.erb — border-slate-300 → border-slate-400**

line 27, 53: `border border-slate-300` → `border border-slate-400`

- [ ] **Step 3: dividend_simulator_component.html.erb — line 12 border-slate-300 → border-slate-400**

```erb
<%# Before: %>
class="flex-1 rounded-md border border-slate-300 dark:border-slate-600

<%# After: %>
class="flex-1 rounded-md border border-slate-400 dark:border-slate-600
```

- [ ] **Step 4: inspection_item_component.html.erb — line 27, 31 border-slate-300 → border-slate-400**

```erb
<%# Before: %>
class="rounded border border-slate-300 px-2 py-0.5

<%# After: %>
class="rounded border border-slate-400 px-2 py-0.5
```

- [ ] **Step 5: tab_navigation_component.html.erb — line 7 hover:border-slate-300 → hover:border-slate-400**

```erb
<%# Before: %>
'border-transparent text-slate-500 hover:border-slate-300 hover:text-slate-700

<%# After: %>
'border-transparent text-slate-500 hover:border-slate-400 hover:text-slate-700
```

- [ ] **Step 6: eviction_guide/guide.html.erb — line 6 bg-blue-50 → bg-blue-100**

```erb
<%# Before: %>
<div class="p-4 bg-blue-50 dark:bg-blue-900/20 border border-blue-200

<%# After: %>
<div class="p-4 bg-blue-100 dark:bg-blue-900/20 border border-blue-400
```

- [ ] **Step 7: Commit**

```bash
git add app/components/bid_opinion_component.rb \
  app/components/profit_calculator_component.html.erb \
  app/components/dividend_simulator_component.html.erb \
  app/components/inspection_item_component.html.erb \
  app/components/eviction_guide/tab_navigation_component.html.erb \
  app/views/eviction_guide/guide.html.erb
git commit -m "fix(ui): increase light mode border contrast to *-400 minimum, bg to *-100 minimum"
```

---

### Task 10: focus-visible:ring 추가

**Files:**
- Modify: `app/components/source_doc_viewer_component.html.erb:17,20`
- Modify: `app/components/inspection_item_component.html.erb:27,31`
- Modify: `app/components/eviction_guide/step_card_component.html.erb:5`
- Modify: `app/components/eviction_guide/simulator_question_component.html.erb:42,56`

- [ ] **Step 1: source_doc_viewer_component.html.erb — 탭 버튼에 focus ring 추가**

line 17, 20: 각 button에 추가:
```
focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-blue-400/50 dark:focus-visible:ring-offset-slate-900
```

- [ ] **Step 2: inspection_item_component.html.erb — 수정/취소 버튼에 focus ring 추가**

line 27, 31: 각 button에 추가:
```
focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-blue-400/50 dark:focus-visible:ring-offset-slate-900
```

- [ ] **Step 3: step_card_component.html.erb — 아코디언 버튼에 focus ring 추가**

line 5: button에 추가:
```
focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-blue-400/50 dark:focus-visible:ring-offset-slate-900
```

- [ ] **Step 4: simulator_question_component.html.erb — Yes/No 버튼에 focus ring 추가**

line 42, 56: 각 submit button에 추가:
```
focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2 dark:focus-visible:ring-blue-400/50 dark:focus-visible:ring-offset-slate-900
```

- [ ] **Step 5: Commit**

```bash
git add app/components/source_doc_viewer_component.html.erb \
  app/components/inspection_item_component.html.erb \
  app/components/eviction_guide/step_card_component.html.erb \
  app/components/eviction_guide/simulator_question_component.html.erb
git commit -m "fix(a11y): add focus-visible:ring to all interactive elements missing it"
```

---

### Task 11: 아코디언 토글 아이콘 — 유니코드 → Heroicon 교체

**Files:**
- Modify: `app/components/eviction_guide/step_card_component.html.erb:17`
- Modify: `app/components/eviction_guide/step_card_component.rb` (heroicon 헬퍼 추가 필요 시)

- [ ] **Step 1: ▶ 유니코드를 Heroicon chevron-down으로 교체**

line 17:
```erb
<%# Before: %>
<span class="text-slate-400 transition-transform" data-accordion-target="icon">▶</span>

<%# After: %>
<span class="text-slate-400 dark:text-slate-500 transition-transform duration-200" data-accordion-target="icon">
  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
    <path stroke-linecap="round" stroke-linejoin="round" d="m19.5 8.25-7.5 7.5-7.5-7.5"/>
  </svg>
</span>
```

- [ ] **Step 2: accordion_controller.js에서 rotate 클래스 확인**

`openValueChanged()`에서 icon target에 `rotate-180` 토글이 적용되는지 확인. 현재 `▶` 기준 transform이면 chevron-down 기준 `-rotate-180`으로 변경 필요.

- [ ] **Step 3: Commit**

```bash
git add app/components/eviction_guide/step_card_component.html.erb
git commit -m "fix(ui): replace unicode arrow with Heroicon chevron-down in accordion toggle"
```

---

### Task 12: 시뮬레이터 이모지 → Heroicon 교체

**Files:**
- Modify: `app/views/eviction_guide/simulator.html.erb:12,21`

- [ ] **Step 1: 📋 이모지를 Heroicon document-text로 교체**

line 12:
```erb
<%# Before: %>
<div class="text-3xl mb-2">📋</div>

<%# After: %>
<div class="mb-2 text-blue-600 dark:text-blue-400">
  <svg class="w-8 h-8 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
    <path stroke-linecap="round" stroke-linejoin="round" d="M19.5 14.25v-2.625a3.375 3.375 0 0 0-3.375-3.375h-1.5A1.125 1.125 0 0 1 13.5 7.125v-1.5a3.375 3.375 0 0 0-3.375-3.375H8.25m0 12.75h7.5m-7.5 3H12M10.5 2.25H5.625c-.621 0-1.125.504-1.125 1.125v17.25c0 .621.504 1.125 1.125 1.125h12.75c.621 0 1.125-.504 1.125-1.125V11.25a9 9 0 0 0-9-9Z"/>
  </svg>
</div>
```

- [ ] **Step 2: ✏️ 이모지를 Heroicon pencil-square로 교체**

line 21:
```erb
<%# Before: %>
<div class="text-3xl mb-2">✏️</div>

<%# After: %>
<div class="mb-2 text-slate-500 dark:text-slate-400">
  <svg class="w-8 h-8 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5">
    <path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L10.582 16.07a4.5 4.5 0 0 1-1.897 1.13L6 18l.8-2.685a4.5 4.5 0 0 1 1.13-1.897l8.932-8.931Zm0 0L19.5 7.125M18 14v4.75A2.25 2.25 0 0 1 15.75 21H5.25A2.25 2.25 0 0 1 3 18.75V8.25A2.25 2.25 0 0 1 5.25 6H10"/>
  </svg>
</div>
```

- [ ] **Step 3: Commit**

```bash
git add app/views/eviction_guide/simulator.html.erb
git commit -m "fix(ui): replace emoji icons with Heroicons in simulator entry cards"
```

---

### Task 13: 액션 버튼 Heroicon 추가

**Files:**
- Modify: `app/components/inspection_item_component.html.erb:27-33`
- Modify: `app/components/eviction_guide/f02_prefill_component.html.erb:46`

- [ ] **Step 1: inspection_item — 수정 버튼에 pencil 아이콘 추가**

line 27:
```erb
<%# Before: %>
... data-action="click->inspection-item#enterEditMode">수정</button>

<%# After: %>
... data-action="click->inspection-item#enterEditMode">
  <svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="m16.862 4.487 1.687-1.688a1.875 1.875 0 1 1 2.652 2.652L6.832 19.82a4.5 4.5 0 0 1-1.897 1.13l-2.685.8.8-2.685a4.5 4.5 0 0 1 1.13-1.897L16.863 4.487Z"/></svg>
  수정
</button>
```

- [ ] **Step 2: inspection_item — 취소 버튼에 x-mark 아이콘 추가**

line 31:
```erb
<%# After: %>
... data-action="click->inspection-item#cancelEditMode">
  <svg class="w-4 h-4 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M6 18 18 6M6 6l12 12"/></svg>
  취소
</button>
```

- [ ] **Step 3: f02_prefill — 확인 완료 버튼에 arrow-right 아이콘 추가**

line 46:
```erb
<%# Before: %>
<button type="submit"
        class="px-6 py-2 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700">
  확인 완료 → 시뮬레이션 시작
</button>

<%# After: %>
<button type="submit"
        class="inline-flex items-center gap-2 px-6 py-2 bg-blue-600 text-white rounded-lg font-semibold hover:bg-blue-700 focus-visible:ring-2 focus-visible:ring-blue-500/50 focus-visible:ring-offset-2 dark:bg-blue-500 dark:hover:bg-blue-400 dark:focus-visible:ring-blue-400/50 dark:focus-visible:ring-offset-slate-900">
  확인 완료 → 시뮬레이션 시작
  <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" stroke-width="1.5"><path stroke-linecap="round" stroke-linejoin="round" d="M13.5 4.5 21 12m0 0-7.5 7.5M21 12H3"/></svg>
</button>
```

- [ ] **Step 4: Commit**

```bash
git add app/components/inspection_item_component.html.erb \
  app/components/eviction_guide/f02_prefill_component.html.erb
git commit -m "fix(ui): add Heroicons to action buttons (edit, cancel, submit)"
```

---

### Task 14: dark: 변형 클래스 보완 + bottom disclaimer contrast 수정

**Files:**
- Modify: `app/components/profit_calculator_component.html.erb:203`

- [ ] **Step 1: profit_calculator — bottom disclaimer bg-amber-50 → bg-amber-100, text-xs → text-sm**

line 203:
```erb
<%# Before: %>
<div class="p-3 bg-amber-50 dark:bg-amber-900/10 border border-amber-200 dark:border-amber-800 rounded-lg text-xs text-amber-800 dark:text-amber-300">

<%# After: %>
<div class="p-3 bg-amber-100 dark:bg-amber-900/10 border border-amber-400 dark:border-amber-800 rounded-lg text-sm text-amber-800 dark:text-amber-300">
```

- [ ] **Step 2: Commit**

```bash
git add app/components/profit_calculator_component.html.erb
git commit -m "fix(ui): improve disclaimer contrast and font size in profit calculator"
```

---

## Summary

| Phase | Tasks | 커밋 수 | 변경 파일 수 |
|-------|-------|---------|-------------|
| Phase 1 (스킬 업그레이드) | Task 1-5 | 5 | 2 (SKILL.md, DESIGN.md) |
| Phase 2 (프로젝트 수정) | Task 6-14 | 9 | ~20 |
| **합계** | **14** | **14** | **~22** |
