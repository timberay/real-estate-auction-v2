# Background Analysis with Global Toast Notification

**Date:** 2026-04-12
**Status:** Approved

## Problem

When a user starts AI analysis, the UI shows an inline progress indicator that replaces the form. The user feels trapped on the page — afraid that navigating away will cancel the analysis — and waits idle until completion. In reality, `PdfAnalysisJob` runs independently via Solid Queue, but the UI gives no assurance of this.

## Solution

Decouple analysis progress from the page where it was initiated. Replace the inline progress indicator with:

1. **Global toast notifications** — visible on any page, powered by Turbo Stream broadcast
2. **Header analysis indicator** — a small spinner/badge in the nav bar showing "analysis in progress"

The user can navigate freely after starting analysis. Completion (or failure) is communicated via toast wherever they are.

## Design

### User Flow

1. User uploads PDF and clicks "분석 시작"
2. Toast appears: "분석이 시작되었습니다" (info type)
3. Header shows a spinning indicator next to the bell icon
4. User navigates freely — browses other properties, starts another task, etc.
5. Analysis completes → toast appears: "분석 완료" with "결과 보기" link (success type)
6. Header indicator disappears
7. On failure → toast appears with error message (danger type), header indicator disappears

### Architecture: Global Turbo Stream Channel

A single user-scoped Turbo Stream channel handles all real-time notifications:

- **Channel name:** `user_notifications_#{user.id}`
- **Subscribed in:** `application.html.erb` layout (available on every page)
- **Actions:**
  - `append` to toast container — adds a new toast notification
  - `replace` on analysis indicator — updates header badge state

### Component Changes

#### 1. Layout (`application.html.erb`)

Add to the layout:
- `turbo_stream_from "user_notifications_#{current_user.id}"` — global subscription
- `<div id="global_toasts">` — container for broadcast toast notifications (placed in the existing fixed toast area)

#### 2. ToastComponent

Extend to accept optional link parameters:

- `action_url` (String, optional) — URL for the action link
- `action_label` (String, optional) — link text (e.g., "결과 보기")

When both are present, render a link after the message text. Existing usage (without links) remains unchanged.

**Auto-dismiss behavior:** When `action_url` is present, set `duration: 0` to disable auto-dismiss. The user must manually close the toast via the "x" button. This prevents the "결과 보기" link from disappearing before the user notices it. The existing `toast_controller.js` already handles `duration: 0` (skips `setTimeout`) and `element.remove()` on dismiss, so DOM cleanup is covered.

#### 3. Header Component

Add an analysis indicator area next to the bell icon:

- `<span id="analysis_indicator">` — empty by default
- When analysis is running: contains a small `animate-spin` icon with sr-only text
- When idle: empty (no visual change)

#### 4. PdfAnalysisJob Broadcast Changes

Replace the current `broadcast_progress` method. New broadcast behavior:

| Event | Toast | Indicator |
|-------|-------|-----------|
| Analysis completed | append success toast: "분석 완료" + "결과 보기" link (no auto-dismiss) | replace with empty |
| Analysis failed | append danger toast: error message (no auto-dismiss) | replace with empty |

The "analyzing" and "saving" intermediate states are removed from job broadcasts. The initial "started" feedback is handled by the controller (see section 5 below), not the job. The job only broadcasts terminal states (completed/failed).

Broadcast target channel: `user_notifications_#{user.id}` (instead of current `analysis_progress_#{user.id}`).

#### 5. AnalysesController#create

Change Turbo Stream response to provide **immediate feedback** without waiting for the job to start:
- **Before:** replaces `#analysis_form` with progress partial
- **After:** responds with multiple Turbo Stream actions in one response:
  1. Reset the form (re-render clean form state)
  2. Append "분석이 시작되었습니다" info toast to `#global_toasts`
  3. Replace `#analysis_indicator` with spinner

This ensures the user gets instant visual confirmation even if the job queue has latency. The job only broadcasts terminal states (completed/failed).

#### 6. Inspections::StartController#create

Change to Turbo Stream response (same pattern as AnalysesController):
1. Flash notice "분석이 시작되었습니다" (existing redirect handles this)
2. Replace `#analysis_indicator` with spinner

Since this controller uses `redirect_to`, the flash notice already appears as a toast. The only addition is broadcasting the header spinner indicator on redirect.

### Files to Remove

- `app/views/analyses/_progress.html.erb` — replaced by global toast notifications

### Views to Update

- `app/views/analyses/new.html.erb` — remove `turbo_stream_from "analysis_progress_*"` subscription and `#analysis_progress` div
- `app/views/properties/show.html.erb` — remove `turbo_stream_from "analysis_progress_*"` subscription and `#analysis_progress` div

### New Files

| File | Purpose |
|------|---------|
| `app/views/notifications/_toast.html.erb` | Partial for broadcast toast — renders ToastComponent inside the global container |
| `app/views/notifications/_analysis_indicator.html.erb` | Partial for header indicator state (spinning or empty) |

## Scope Boundaries

**In scope:**
- Both entry points: `/analyses/new` and `/properties/:id`
- Global toast with action link
- Header spinner indicator
- Cleanup of inline progress UI

**Out of scope:**
- Notification history / notification center
- Concurrent multi-analysis management
- Bell icon as notification hub (future work)
- Cancel analysis feature

## Known Limitations

**Multiple concurrent analyses:** If a user starts two analyses back-to-back, the first to complete will clear the header spinner even though the second is still running. This is acceptable for MVP since concurrent analysis is an uncommon edge case. A future fix would track active job count (e.g., via DB column or cache counter) before clearing the indicator.
