# OAuth Hardening: CSP Rollout (Phases 4–5)

**Date:** 2026-04-22 (revised 2026-04-25 — scope reduced to CSP)
**Status:** Phase 1 shipped in #20; Phase 4 ready to implement; Phases 2 and 3 deferred
**Companion to:** `2026-04-22-sns-login-design.md` (the original SNS login spec)

## Context

The SNS login implementation shipped (commits `63ce30d` … `fd63a79`) covers Case A/B/C OAuth flow, GuestMerger with per-association policy, rate limiting, session-fixation defense, remember_token cookie, and a comprehensive test suite. An objective post-ship review surfaced 18 candidate improvement areas. Five highest-leverage items were initially scoped (Phases 1–5).

After a 2026-04-25 re-evaluation, only Phase 1 (already shipped in #20) and Phases 4–5 (CSP rollout) are kept. **Phases 2 (revocable `remember_token`) and 3 (merge-out-of-transaction) are deferred** — they address hypothetical risks with no current user signal (zero production users, unknown GuestMerger failure rate) and add code complexity prematurely. They may revive if real-world signals emerge: lost-device support requests for Phase 2, or GuestMerger failure rate >0.1% for Phase 3.

This spec covers Phases 4–5 only. Git history retains the original five-phase design if Phases 2/3 are revived.

## Decisions (from brainstorming)

| # | Topic | Decision |
|---|---|---|
| 1 | `Identity.raw_info` handling | **Drop the column entirely.** Whitelist needed fields as typed columns. Shipped in #20. |
| 4 | CSP rollout | **Report-Only first, enforce in a follow-up PR after a 1–2 week observation window.** Strict-from-day-one risks blocking external assets we haven't catalogued. |
| 5 | Bundling | **Two sequential PRs (Phase 4 → Phase 5).** Phase 1 already shipped. Phases 2/3 deferred. |

## Goals & Non-Goals

**Goals**
- Add a server-side XSS defense layer (CSP) — currently zero CSP coverage.

**Non-Goals (deferred to separate specs if/when prioritized)**
- **Revocable `remember_token`** (original Phase 2) — defer until lost-device support requests appear post-launch.
- **Merge-out-of-transaction** (original Phase 3) — defer until production GuestMerger failure rate is measured.
- Per-device session management UI ("이 기기에서 로그아웃")
- Account linking / unlinking from a settings page
- PKCE for any provider
- Terms-of-service version tracking
- Identity merge audit log
- Provider registry refactor (currently 4-file change to add a new provider)
- Account-aware (per-email) rate limiting beyond the existing IP throttle
- Encrypted-at-rest secrets beyond Rails encrypted credentials

## Architecture

### Phase 4 — CSP Report-Only

**Activate `config/initializers/content_security_policy.rb`:**

```ruby
Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :https
    policy.object_src  :none
    policy.script_src  :self, :nonce
    policy.style_src   :self, :nonce
    policy.connect_src :self
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self, "https://accounts.google.com",
                              "https://nid.naver.com",
                              "https://kauth.kakao.com"
    policy.report_uri  "/csp_reports"
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
  config.content_security_policy_report_only = true
end
```

**Reporting endpoint:**

```ruby
# app/controllers/csp_reports_controller.rb
class CspReportsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create
  skip_before_action :ensure_current_user, only: :create

  def create
    Rails.logger.tagged("csp.violation") do
      Rails.logger.warn(request.raw_post)
    end
    head :no_content
  end
end

# config/routes.rb
post "/csp_reports", to: "csp_reports#create"
```

The endpoint just logs. No DB table, no aggregation — Rails logs are enough for the observation window. If volume becomes a problem we throttle via rack-attack later.

**Audit pass before activation:** scan ERB templates for inline `<script>` and `style=` attributes; convert any found to nonce-tagged or external assets. Stimulus and Turbo Streams use neither, so the impact should be minimal.

### Phase 5 — CSP enforce (separate PR, after observation)

A single config change plus a test update. Held to its own PR so the observation window is explicit:

```ruby
config.content_security_policy_report_only = false
```

Spec note: Phase 5 ships **only after** the team confirms `csp.violation` log volume is at zero (or known acceptable) for at least one week of normal traffic.

## Component Inventory

| Phase | File | Change |
|---|---|---|
| 4 | `config/initializers/content_security_policy.rb` | Activate, Report-Only |
| 4 | `app/controllers/csp_reports_controller.rb` | New |
| 4 | `config/routes.rb` | `post "/csp_reports"` |
| 4 | ERB templates audit | Convert any inline scripts/styles found |
| 5 | `config/initializers/content_security_policy.rb` | `report_only = false` |

## Data Model Changes

None — Phases 4–5 are config + controller only.

## Error Handling

| Scenario | Behavior |
|---|---|
| Phase 4: ERB inline script discovered post-deploy | CSP Report-Only logs it; no user impact. Fix forward. |
| Phase 4: high CSP report volume | Add rack-attack throttle on `/csp_reports`. |

## Testing Plan

| Phase | Test file | Cases |
|---|---|---|
| 4 | `test/integration/csp_test.rb` (new) | Response carries `Content-Security-Policy-Report-Only` header; nonce appears in header and in injected `<script nonce="...">` tags |
| 4 | `test/controllers/csp_reports_controller_test.rb` (new) | POST returns 204; payload appears in logs (capture via `Rails.logger`) |
| 5 | `test/integration/csp_test.rb` | Updated to expect `Content-Security-Policy` (not `-Report-Only`) |

## Rollout Sequence

Each Phase ships as its own PR. Phase 5 must follow Phase 4 by ≥ 1 week of clean reports.

## Risks

| Risk | Mitigation |
|---|---|
| Phase 4 Report-Only generates noise from third-party browser extensions | Filter at ingest endpoint (skip reports where `source-file` is `chrome-extension://`). |
| Phase 5 enforce blocks something we missed | Roll back the one-line config change; re-open observation window. |

## Open Questions

None.
