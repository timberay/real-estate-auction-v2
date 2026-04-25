# OAuth Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Content-Security-Policy layer (Report-Only → enforce) to the SNS-login system. Phase 1 (PII minimization, `raw_info` → `email_verified`) shipped in #20. Phases 2 (revocable `remember_token`) and 3 (merge-out-of-transaction) from the original spec are deferred — they address hypothetical risks with no current user signal and add code complexity prematurely. They may revive post-launch if real-world signals emerge.

**Architecture:** Two sequential PRs (Phases 4–5). Phase 5 follows Phase 4 after a ≥1-week observation window with zero `csp.violation` log entries from first-party traffic.

**Tech Stack:** Rails 8.1 · SQLite · OmniAuth (google_oauth2 · kakao · naver) · ViewComponent · Hotwire (Turbo + Stimulus) · Minitest · Tidy-First TDD discipline per `CLAUDE.md`.

**Spec:** `docs/superpowers/specs/2026-04-22-oauth-hardening-design.md`

---

## File Structure

### Files created

| Phase | Path | Responsibility |
|---|---|---|
| 4 | `app/controllers/csp_reports_controller.rb` | Receives browser CSP violation reports and tags them in `Rails.logger` |
| 4 | `test/controllers/csp_reports_controller_test.rb` | Exercises the reporting endpoint |
| 4 | `test/integration/csp_test.rb` | Asserts CSP header + nonce injection end-to-end |

### Files modified

| Phase | Path | Change |
|---|---|---|
| 4 | `config/initializers/content_security_policy.rb` | Activate policy in Report-Only mode |
| 4 | `config/routes.rb` | `post "/csp_reports"` |
| 4 | `app/views/layouts/application.html.erb` | Replace inline `<script>` dark-mode FOUC with nonce-tagged `javascript_tag` |
| 5 | `config/initializers/content_security_policy.rb` | Flip `content_security_policy_report_only = false` |
| 5 | `test/integration/csp_test.rb` | Expect enforcement header, not Report-Only |

---

# Phase 4 — CSP Report-Only + reporting endpoint

**PR scope:** Replace the commented-out default CSP initializer with an active Report-Only policy; add a report-ingest controller that logs tagged payloads; convert the one inline script in `application.html.erb` to a nonce-tagged `javascript_tag`.

---

### Task 4.1: Nonce-tag the dark-mode FOUC script (structural prep)

The current `<script>` block in `application.html.erb:31-38` runs before CSS load to prevent flash-of-wrong-theme. It uses `localStorage` directly and does not participate in importmap — it must be authored inline. Under CSP we must attach a nonce.

**Files:**
- Modify: `app/views/layouts/application.html.erb`

- [ ] **Step 1: Convert inline script to nonce-tagged helper**

Replace lines 31–38 of `app/views/layouts/application.html.erb`:
```erb
  <%= javascript_tag nonce: true do %>
    (function() {
      const darkMode = localStorage.getItem("dark-mode");
      if (darkMode === "true" || (darkMode === null && window.matchMedia("(prefers-color-scheme: dark)").matches)) {
        document.documentElement.classList.add("dark");
      }
    })();
  <% end %>
```

Note: the `<script>…</script>` block was between the closing `</head>` and opening `<body>` in the source; `javascript_tag` emits the same structure. Leave the placement unchanged.

- [ ] **Step 2: Run existing tests**

```bash
bin/rails test
```
Expected: all pass — the rendered markup is equivalent (before CSP activation, `nonce: true` is a no-op).

- [ ] **Step 3: Commit (structural)**

```bash
git add app/views/layouts/application.html.erb
git commit -m "refactor(ui): nonce-ready javascript_tag for dark-mode FOUC"
```

---

### Task 4.2: CSP Report-Only + reports endpoint (TDD)

**Files:**
- Create: `app/controllers/csp_reports_controller.rb`
- Create: `test/controllers/csp_reports_controller_test.rb`
- Create: `test/integration/csp_test.rb`
- Modify: `config/initializers/content_security_policy.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing tests — CSP header + nonce**

Create `test/integration/csp_test.rb`:
```ruby
require "test_helper"

class CspTest < ActionDispatch::IntegrationTest
  test "response carries Content-Security-Policy-Report-Only header" do
    get "/auth/login"
    header = response.headers["Content-Security-Policy-Report-Only"]
    assert header.present?, "Report-Only header missing"
    assert_match(/default-src 'self'/, header)
    assert_match(%r{report-uri /csp_reports}, header)
  end

  test "nonce is injected into the header and the dark-mode script" do
    get "/auth/login"
    header = response.headers["Content-Security-Policy-Report-Only"]
    nonce = header[/script-src[^;]*'nonce-([^']+)'/, 1]
    assert nonce.present?, "script-src nonce missing from header"
    assert_match(/<script nonce="#{Regexp.escape(nonce)}">/, response.body)
  end

  test "no enforcement header while in Report-Only mode" do
    get "/auth/login"
    assert_nil response.headers["Content-Security-Policy"]
  end
end
```

Create `test/controllers/csp_reports_controller_test.rb`:
```ruby
require "test_helper"

class CspReportsControllerTest < ActionDispatch::IntegrationTest
  test "POST returns 204 and logs the raw payload with csp.violation tag" do
    captured = StringIO.new
    original = Rails.logger
    Rails.logger = ActiveSupport::TaggedLogging.new(Logger.new(captured))

    payload = '{"csp-report":{"document-uri":"http://example/x","violated-directive":"script-src"}}'
    post "/csp_reports", params: payload, headers: { "CONTENT_TYPE" => "application/csp-report" }

    assert_response :no_content
    assert_match "csp.violation", captured.string
    assert_match "violated-directive", captured.string
  ensure
    Rails.logger = original if original
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
bin/rails test test/integration/csp_test.rb test/controllers/csp_reports_controller_test.rb
```
Expected: all fail — policy not active, controller not defined, route missing.

- [ ] **Step 3: Activate the CSP initializer**

Replace `config/initializers/content_security_policy.rb`:
```ruby
# Be sure to restart your server when you modify this file.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, :https
    policy.object_src  :none
    policy.script_src  :self
    policy.style_src   :self
    policy.connect_src :self
    policy.frame_ancestors :none
    policy.base_uri    :self
    policy.form_action :self,
                       "https://accounts.google.com",
                       "https://nid.naver.com",
                       "https://kauth.kakao.com"
    policy.report_uri  "/csp_reports"
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src style-src]
  config.content_security_policy_report_only = true
end
```

Note: the Pretendard font comes from `https://cdn.jsdelivr.net`. It is loaded via `<link rel="stylesheet">`, which is governed by `style-src` — but stylesheets referenced from an external origin count against `style-src` only for `<style>`/`style=""`; external stylesheet *requests* are governed by the fetch directive `style-src` for the stylesheet itself. This will require a `style-src` whitelist entry. Revisit during the observation window (see Task 4.3). Starting with `:self` is deliberate — the whole point of Report-Only is to discover these without impact.

Same logic for the Pretendard `.woff2` files (`font-src`) — the external origin is not yet whitelisted. Observation will surface the need.

- [ ] **Step 4: Create the reports controller**

Create `app/controllers/csp_reports_controller.rb`:
```ruby
class CspReportsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create
  skip_before_action :ensure_current_user, only: :create
  skip_before_action :capture_return_to_url, only: :create
  skip_before_action :touch_last_seen, only: :create

  def create
    Rails.logger.tagged("csp.violation") do
      Rails.logger.warn(request.raw_post.presence || "<empty>")
    end
    head :no_content
  end
end
```

- [ ] **Step 5: Add route**

Edit `config/routes.rb` — insert after the `root` line:
```ruby
post "/csp_reports", to: "csp_reports#create"
```

- [ ] **Step 6: Run tests to verify pass**

Run:
```bash
bin/rails test test/integration/csp_test.rb test/controllers/csp_reports_controller_test.rb
```
Expected: all pass.

- [ ] **Step 7: Full regression**

```bash
bin/rails test
```
Expected: all pass.

- [ ] **Step 8: Manual smoke check — boot dev server and confirm header**

Run:
```bash
bin/dev &
sleep 5
curl -sI http://localhost:3000/auth/login | grep -i 'content-security'
kill %1
```
Expected: a single `Content-Security-Policy-Report-Only:` header with `default-src 'self'` and `report-uri /csp_reports`.

- [ ] **Step 9: Commit**

```bash
git add config/initializers/content_security_policy.rb \
        app/controllers/csp_reports_controller.rb \
        config/routes.rb \
        test/integration/csp_test.rb \
        test/controllers/csp_reports_controller_test.rb
git commit -m "feat(security): CSP Report-Only + /csp_reports logger sink"
```

**End of Phase 4.** Push branch, open PR, merge. Begin observation window.

---

# Phase 5 — Enforce CSP

**PR scope:** One config flag flip and a test update. Ships **only after** at least one week of clean `csp.violation` logs (filter: ignore `source-file` starting with `chrome-extension://`, `moz-extension://`, `safari-web-extension://`).

---

### Task 5.1: Verify observation window is clean

- [ ] **Step 1: Inspect the report log**

Run (substitute the correct production log location if different):
```bash
grep -h 'csp.violation' log/production.log | \
  grep -vE 'chrome-extension://|moz-extension://|safari-web-extension://' | \
  wc -l
```
Expected: `0` across ≥ 1 week of normal traffic. If not zero, triage each distinct violation and decide: (a) add to whitelist (update Task 4.2 initializer), (b) fix the offending template, or (c) block Phase 5 until resolved.

- [ ] **Step 2: Re-verify the fix list**

Common likely findings to expect during observation:
- `https://cdn.jsdelivr.net` (Pretendard font CSS) → add to `style-src` and `font-src`.
- `data:` URIs in `img-src` → already allowed.
- Provider OAuth redirect pages → already covered via `form-action`.

If any of these emerged and were added to the initializer, land those changes in a *separate* Phase 4.5 PR **before** flipping enforcement.

---

### Task 5.2: Flip CSP to enforce mode (TDD)

**Files:**
- Modify: `config/initializers/content_security_policy.rb`
- Modify: `test/integration/csp_test.rb`

- [ ] **Step 1: Update the integration test**

Edit `test/integration/csp_test.rb`. Replace all three tests:
```ruby
require "test_helper"

class CspTest < ActionDispatch::IntegrationTest
  test "response carries Content-Security-Policy (enforcement) header" do
    get "/auth/login"
    header = response.headers["Content-Security-Policy"]
    assert header.present?, "Enforcement header missing"
    assert_match(/default-src 'self'/, header)
    assert_match(%r{report-uri /csp_reports}, header)
  end

  test "nonce is injected into the enforcement header and the dark-mode script" do
    get "/auth/login"
    header = response.headers["Content-Security-Policy"]
    nonce = header[/script-src[^;]*'nonce-([^']+)'/, 1]
    assert nonce.present?, "script-src nonce missing"
    assert_match(/<script nonce="#{Regexp.escape(nonce)}">/, response.body)
  end

  test "no Report-Only header in enforcement mode" do
    get "/auth/login"
    assert_nil response.headers["Content-Security-Policy-Report-Only"]
  end
end
```

- [ ] **Step 2: Run tests to verify failure**

Run:
```bash
bin/rails test test/integration/csp_test.rb
```
Expected: all fail — `Content-Security-Policy` header is nil, Report-Only header is still present.

- [ ] **Step 3: Flip the flag**

Edit `config/initializers/content_security_policy.rb`. Replace the last active line:
```ruby
config.content_security_policy_report_only = false
```

- [ ] **Step 4: Run tests to verify pass**

Run:
```bash
bin/rails test test/integration/csp_test.rb
```
Expected: all pass.

- [ ] **Step 5: Full regression + manual smoke**

```bash
bin/rails test
bin/dev &
sleep 5
curl -sI http://localhost:3000/auth/login | grep -i 'content-security'
kill %1
```
Expected: test suite green; one `Content-Security-Policy:` header (no `-Report-Only`).

- [ ] **Step 6: Commit**

```bash
git add config/initializers/content_security_policy.rb test/integration/csp_test.rb
git commit -m "feat(security): enforce Content-Security-Policy"
```

**End of Phase 5.** Push branch, open PR, merge. OAuth Hardening (CSP scope) complete.

---

## Validation Checklist (post-Phase-5 verification)

Run after Phase 5 merges to prod.

- [ ] Open a fresh browser, navigate to root, inspect DevTools → Security tab → verify `Content-Security-Policy` (no `-Report-Only`) header is present.
- [ ] Log in via Kakao, Google, Naver — each still redirects back and logs the user in.
- [ ] Verify dark-mode toggle still works with no FOUC (nonce applied correctly).
- [ ] Tail `log/production.log`; after 24h confirm no `csp.violation` entries from first-party traffic.
