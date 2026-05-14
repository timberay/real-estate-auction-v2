# UI/UX Improvements — Design Spec

7 UI/UX issues identified from user testing. All changes are frontend-only (views, components, Stimulus controllers) with one minor model method addition.

## 1. New Analysis Page — File Upload UX

**File:** `app/views/analyses/new.html.erb`

**Problems:**
- "분석 시작" button is clickable even when no file is selected
- File input button appears disabled/inactive (styling issue)
- Selected files display in a single line; multiple files should show as a list

**Changes:**
- Add a Stimulus controller (`file-upload`) to manage file selection state
- Disable "분석 시작" button by default; enable only when files are selected
- Display selected file names as a vertical list below the file input
- Ensure "파일 선택" and "분석 시작" buttons use consistent sizing (both use the same height/padding)

## 2. Property Show — Document Upload Simplification

**Files:** `app/views/properties/documents/_form.html.erb`, `app/views/properties/show.html.erb`

**Problems:**
- File input button appears disabled/inactive (same styling issue as #1)
- Standalone "업로드" button is confusing — analysis start already handles upload

**Changes:**
- Merge document upload and analysis start into a single form on property show page
- Remove `_form.html.erb` usage from show page; instead, embed file input directly in a unified form that POSTs to `property_inspections_start_path`
- Update `Inspections::StartController#create` to accept and attach documents from the form before starting analysis (if new files are submitted)
- Apply the same `file-upload` Stimulus controller for file list display and consistent styling
- Keep `_form.html.erb` as-is for any other usage, but property show no longer uses it

## 3. Analysis History — Re-analyze & View Results

**File:** `app/views/properties/show.html.erb`

**Problem:** Properties with existing analysis show the same "분석 시작" button, with no way to view results.

**Changes:**
- Add `analyzed?` method to `Property` model: returns `true` if `inspection_results.exists?`
- When `analyzed?` is true, show two buttons:
  - "분석 결과 보기" — links to `edit_property_inspections_tab_path(@property, tab_key: "rights_analysis")`
  - "다시 분석" — same POST action as current "분석 시작"
- When `analyzed?` is false, show "분석 시작" as current (but disabled when no documents)

## 4. Property Card — AI Analysis Badge

**Files:** `app/components/property_card_component.rb`, `app/components/property_card_component.html.erb`

**Problem:** No visual indicator on property cards for completed AI analysis.

**Changes:**
- Pass `analyzed` boolean to `PropertyCardComponent` (computed via `property.inspection_results.exists?`)
- When `analyzed` is true, render a purple `BadgeComponent` with text "AI 분석완료" in the badge row (alongside SafetyBadgeComponent)
- Badge variant: `:accent` (purple)

## 5. Criteria Search Button Relocation + Add Button Text

**File:** `app/views/properties/index.html.erb`

**Problems:**
- "조건검색" button is next to case number input — not intuitive since it searches by region
- "+" button has no text label

**Changes:**
- Move the criteria search form/button to the region select row (inline with the dropdown)
- Change "+" icon-only button to show "+ 추가" (icon + text)
- Remove `max-w-2xl` from the criteria-search container so the region/case-number input area spans the same width as the filter/search bar below (both full-width within the content area)

## 6. Search Result Card — Price Order

**File:** `app/views/search_results/_inline_result_item.html.erb`

**Problem:** 감정가 appears in the header line while 최저매각가 is below. Should follow the same order as property cards (감정가 first, then 최저매각가).

**Changes:**
- Move 감정가 out of the header row into its own line below case number
- Display 감정가 first, then 최저매각가 below it
- Both on separate lines with consistent label + value formatting

## 7. Responsive Grid Breakpoint

**Files:** `app/views/properties/index.html.erb`, `app/views/search_results/_inline_results.html.erb`

**Problem:** At `lg` (1024px), 4-column grid makes cards too narrow with sidebar present.

**Changes:**
- Property cards grid: `sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4` → `sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4`
- Search results grid: same breakpoint change for consistency

## 8. Button Size Consistency (Cross-cutting)

**Problem:** "파일 선택" and "분석 시작" buttons have different sizes.

**Changes:**
- Both buttons use the same height and padding classes
- Use `ButtonComponent` where possible for consistency, or apply matching Tailwind classes (`h-10 px-4 text-sm`)

## Files Modified

| File | Changes |
|------|---------|
| `app/views/analyses/new.html.erb` | #1, #8: file upload UX, button sizing |
| `app/views/properties/show.html.erb` | #2, #3: remove upload btn, add re-analyze/view results |
| `app/controllers/inspections/start_controller.rb` | #2: accept and attach documents before analysis |
| `app/views/properties/index.html.erb` | #5, #7: move search btn, grid breakpoint |
| `app/views/search_results/_inline_result_item.html.erb` | #6: price order |
| `app/views/search_results/_inline_results.html.erb` | #7: grid breakpoint |
| `app/components/property_card_component.rb` | #4: accept analyzed param |
| `app/components/property_card_component.html.erb` | #4: render AI badge |
| `app/models/property.rb` | #3: add `analyzed?` method |
| `app/javascript/controllers/file_upload_controller.js` | #1, #2: new Stimulus controller |
| `app/components/sidebar/component.rb` | #9: menu label changes |

## 9. Sidebar Menu Label Changes

**File:** `app/components/sidebar/component.rb`

**Problem:** Menu group and item labels don't clearly convey their purpose.

**Changes to `MENU_GROUPS`:**
- Item: "새 분석" → "AI분석"
- Group: "분석 (P1)" → "리포트"
- Group: "낙찰 후 (P2)" → "가이드"

## Out of Scope

- Backend logic changes (analysis flow, document processing)
- New pages or routes
- Dark mode regressions (all changes must respect existing dark mode classes)
