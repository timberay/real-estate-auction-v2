# Inspection Auto-Answer Display & Edit Design

**Date:** 2026-04-07
**Status:** Approved

## Problem

The inspection system auto-detects risks via `InspectionRunner` using `DETECTION_RULES`, but the UI only shows "위험/안전" status without:
1. Showing which answer (yes/no) was selected by the auto-detection
2. Explaining what yes/no means for each item
3. Allowing users to override auto-detected answers they believe are incorrect

Each `InspectionItem` already has a `logic` JSON field with `{"yes": "...", "no": "..."}` explanations, but this data is not surfaced in the UI.

## Decisions

### 1. Yes/No Meaning Display — Always Visible

Each inspection item card shows both yes and no explanations from the `logic` field at all times.

- **Selected answer**: highlighted with background color + bold text
- **Unselected answer**: dimmed (`text-slate-400`)
- Items without `logic` data: this section is omitted
- For unanswered manual items (`has_risk == nil`): both options shown without highlight

Visual layout within an item card:
```
┌──────────────────────────────────────────────────────┐
│ [AUTO] Question text                        안전     │
│ (description)                                        │
│                                                      │
│  ✔ Yes: "Safe explanation from logic.yes"            │  ← highlighted
│    No:  "Risk explanation from logic.no"             │  ← dimmed
└──────────────────────────────────────────────────────┘
```

Mapping: `has_risk == false` → Yes is selected (safe). `has_risk == true` → No is selected (risk detected). This matches the question phrasing convention where "yes" = safe, "no" = risky.

### 2. Inline Edit for AUTO Items

AUTO items display a "수정" (edit) button. Clicking it switches that card to edit mode.

**Read mode (default for AUTO items):**
```
┌──────────────────────────────────────────────────────┐
│ [AUTO] Question                          안전  [수정] │
│                                                      │
│  ✔ Yes: safe explanation                             │
│    No:  risk explanation                             │
└──────────────────────────────────────────────────────┘
```

**Edit mode (after clicking "수정"):**
```
┌──────────────────────────────────────────────────────┐
│ [AUTO → 수정됨] Question                      [취소] │
│                                                      │
│  ○ Yes: safe explanation                             │
│  ● No:  risk explanation                             │
│                                                      │
│  (if risk selected) Resolution UI appears            │
└──────────────────────────────────────────────────────┘
```

- **"수정" click** → Stimulus controller toggles card to edit mode (radio buttons enabled)
- **"취소" click** → Restores original auto value, exits edit mode
- **Save** → Uses existing tab-level "저장" button (bulk PATCH), consistent with current flow

### 3. Data Model — Manual Override with Auto Value Preservation

When a user modifies an AUTO result:

| Field | Before | After |
|-------|--------|-------|
| `source_type` | `auto` | `manual` |
| `has_risk` | auto-detected value | user-selected value |
| `auto_value` | (empty) | original auto-detected value (`"true"` or `"false"`) |
| `manual_value` | (empty) | (unused, available for future) |

**Badge logic:**
- `source_type == auto` → "AUTO" badge
- `source_type == manual` AND `auto_value` present → "수정됨" badge (was auto, user overrode)
- `source_type == manual` AND `auto_value` blank → "직접 확인" badge (always manual)
- `source_type.nil?` → no badge (unanswered)

**Re-run safety:** `InspectionRunner` already skips items where `source_type` is present and persisted. Since overridden items become `manual`, they are not overwritten on re-run.

### 4. No Schema Changes Required

All fields already exist on `InspectionResult`:
- `source_type` (enum: auto/manual)
- `has_risk` (boolean, nullable)
- `auto_value` (text)
- `manual_value` (text)

The `logic` field already exists on `InspectionItem` as a JSON column, populated from seed data.

## Affected Components

| File | Change |
|------|--------|
| `app/components/inspection_item_component.rb` | Add logic display, edit button, "수정됨" badge, edit-mode form fields |
| `app/components/inspection_item_component.html.erb` | Template for logic explanations, edit/cancel buttons, radio buttons in edit mode |
| `app/javascript/controllers/inspection_item_controller.js` | Add edit/cancel toggle actions, radio enable/disable, original value restoration |
| `app/controllers/inspections/tabs_controller.rb` | Handle overridden AUTO items: set `source_type=manual`, preserve `auto_value` |
| `app/services/inspection_runner.rb` | No changes needed |
| `app/models/inspection_item.rb` | No changes needed |
| `app/models/inspection_result.rb` | No changes needed |

## Testing Strategy

- **Model tests:** Verify badge logic helper methods (auto, overridden, manual)
- **Component tests:** Verify logic display renders correctly, edit button presence for AUTO items only, badge text for each source state
- **Controller tests:** Verify override saves correctly (source_type change, auto_value preservation)
- **Integration test:** Full flow — auto-detect → display → override → save → verify persisted state
- **E2E (Playwright):** Visual verification of edit mode toggle, logic display
