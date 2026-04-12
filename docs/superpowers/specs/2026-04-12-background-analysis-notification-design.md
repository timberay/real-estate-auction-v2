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

#### 3. Header Component

Add an analysis indicator area next to the bell icon:

- `<span id="analysis_indicator">` — empty by default
- When analysis is running: contains a small `animate-spin` icon with sr-only text
- When idle: empty (no visual change)

#### 4. PdfAnalysisJob Broadcast Changes

Replace the current `broadcast_progress` method. New broadcast behavior:

| Event | Toast | Indicator |
|-------|-------|-----------|
| Analysis started (in job `perform`) | append info toast: "AI 분석 중... (문서가 많으면 수 분 소요)" | replace with spinner |
| Analysis completed | append success toast: "분석 완료" + "결과 보기" link | replace with empty |
| Analysis failed | append danger toast: error message | replace with empty |

The "saving" intermediate state is removed from user-facing notifications (unnecessary detail).

Broadcast target channel: `user_notifications_#{user.id}` (instead of current `analysis_progress_#{user.id}`).

#### 5. AnalysesController#create

Change Turbo Stream response:
- **Before:** replaces `#analysis_form` with progress partial
- **After:** resets the form (re-renders clean form state) so the user can immediately upload another file or navigate away

The "분석이 시작되었습니다" feedback comes from the job's first broadcast, not the controller response.

#### 6. Inspections::StartController#create

No changes needed. Already uses `redirect_to` with flash notice, which displays as a toast via existing flash handling.

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
