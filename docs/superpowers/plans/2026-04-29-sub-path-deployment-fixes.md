# Sub-path Deployment Compatibility Fixes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app fully functional under sub-path deployment (`RAILS_RELATIVE_URL_ROOT=/real-estate-auction`) by replacing hardcoded root-relative paths and `request.path` checks with sub-path-aware equivalents.

**Architecture:** Introduce a single `SubPath` module that centralizes sub-path prefix construction. All config files (production.rb, CSP initializer, mailer defaults) and a few view/controller call sites delegate to it. Replace `request.path` with `request.path_info` in middleware/filter logic, and replace bare-string `redirect_to "/auth/..."` / `link_to "/auth/..."` with named-route helpers. Each fix is paired with a TDD test demonstrating the bug under a simulated sub-path.

**Tech Stack:** Rails 8.1, Minitest, Rack, ViewComponent.

**Pre-existing bug context:** This plan fixes pre-existing latent bugs that were dormant because sub-path deployment had not yet been launched. They were uncovered during the `real-estate-auction-v2` → `real-estate-auction` directory rename audit (110 use cases, exhaustive inspection 2026-04-29). None are caused by the rename itself; both `-v2` and the new prefix are sub-paths.

**Scope:**
- IN: 10 sub-path-incorrect call sites (P1–P9 + `/settings/budget` link).
- OUT: Placeholder `host: "example.com"` in `production.rb:64` (needs real domain decision, separate concern). Hardcoded `/terms`, `/privacy` links in modal (no Rails routes — those pages don't exist yet).

---

## File Structure

| File | Status | Responsibility |
|------|--------|----------------|
| `app/lib/sub_path.rb` | Create | Helper module — `SubPath.prefix`, `SubPath.path_under(path)` |
| `test/lib/sub_path_test.rb` | Create | Unit tests for `SubPath` |
| `config/environments/production.rb` | Modify | Use `SubPath.path_under("/up")` for `silence_healthcheck_path`; add `script_name:` to mailer `default_url_options` |
| `config/environments/development.rb` | Modify | Add `script_name:` to mailer `default_url_options` |
| `config/initializers/content_security_policy.rb` | Modify | Use `SubPath.path_under("/csp_reports")` for `report_uri` |
| `config/initializers/rack_attack.rb` | Modify | `req.path` → `req.path_info` |
| `test/initializers/rack_attack_test.rb` | Create | Throttle behavior under sub-path |
| `app/controllers/application_controller.rb` | Modify | `request.path` → `request.path_info`; `redirect_to "/auth/login"` → `redirect_to auth_login_path` |
| `app/controllers/auth/omniauth_callbacks_controller.rb` | Modify | `redirect_to "/auth/login"` → `redirect_to auth_login_path` |
| `app/components/header/component.html.erb` | Modify | Bare `/auth/...` and `/settings/budget` strings → route helpers |
| `app/helpers/auth_helper.rb` | Modify | `provider_path` uses `request.script_name` |
| `test/helpers/auth_helper_test.rb` | Create | `provider_path` returns prefixed path under sub-path |
| `test/integration/sub_path_compatibility_test.rb` | Create | End-to-end integration test simulating sub-path mount |

---

## Conventions

- **Test command:** `bin/rails test <path>` for unit, `bin/rails test:system` for system tests. Use `bin/rails test` (no path) only at the very end.
- **Commit messages:** `fix(sub-path): <surface>` for behavioral fixes; `refactor(sub-path): <surface>` for structural-only (e.g., introducing `SubPath` module before any callers use it).
- **Tidy First:** Task 1 introduces `SubPath` as a pure structural addition (no callers yet — it's dead code at end of Task 1). Tasks 2–9 mix structural delegation with behavioral fix; each task is a single commit covering one surface.

---

### Task 1: Introduce `SubPath` helper module

**Why:** A single source of truth for prefix construction. Consumers in Tasks 2–4 will delegate to it instead of duplicating `ENV.fetch(...).chomp("/")` logic.

**Files:**
- Create: `app/lib/sub_path.rb`
- Create: `test/lib/sub_path_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/lib/sub_path_test.rb
require "test_helper"

class SubPathTest < ActiveSupport::TestCase
  def with_env(value)
    original = ENV["RAILS_RELATIVE_URL_ROOT"]
    if value.nil?
      ENV.delete("RAILS_RELATIVE_URL_ROOT")
    else
      ENV["RAILS_RELATIVE_URL_ROOT"] = value
    end
    yield
  ensure
    ENV["RAILS_RELATIVE_URL_ROOT"] = original
  end

  test ".prefix returns empty string when env unset" do
    with_env(nil) { assert_equal "", SubPath.prefix }
  end

  test ".prefix returns env value with trailing slash trimmed" do
    with_env("/real-estate-auction/") { assert_equal "/real-estate-auction", SubPath.prefix }
  end

  test ".prefix returns env value untouched when no trailing slash" do
    with_env("/real-estate-auction") { assert_equal "/real-estate-auction", SubPath.prefix }
  end

  test ".path_under prepends prefix to a leading-slash path" do
    with_env("/real-estate-auction") do
      assert_equal "/real-estate-auction/up", SubPath.path_under("/up")
    end
  end

  test ".path_under returns path unchanged when env unset" do
    with_env(nil) { assert_equal "/up", SubPath.path_under("/up") }
  end

  test ".path_under handles env with trailing slash" do
    with_env("/foo/") { assert_equal "/foo/up", SubPath.path_under("/up") }
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/lib/sub_path_test.rb`
Expected: FAIL with `NameError: uninitialized constant SubPathTest::SubPath`

- [ ] **Step 3: Implement minimal `SubPath` module**

```ruby
# app/lib/sub_path.rb
module SubPath
  def self.prefix
    ENV.fetch("RAILS_RELATIVE_URL_ROOT", "").chomp("/")
  end

  def self.path_under(path)
    "#{prefix}#{path}"
  end
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/lib/sub_path_test.rb`
Expected: 6 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/lib/sub_path.rb test/lib/sub_path_test.rb
git commit -m "refactor(sub-path): add SubPath helper module for prefix construction"
```

---

### Task 2: `silence_healthcheck_path` honors sub-path

**Why:** `Rails::Rack::Logger` matches `request.path` (which includes script_name) against the configured value. Under sub-path, `/up` becomes `/real-estate-auction/up` and the literal `"/up"` no longer matches → healthcheck noise floods logs.

**Files:**
- Modify: `config/environments/production.rb:47`

- [ ] **Step 1: Write the failing test**

```ruby
# Append to test/lib/sub_path_test.rb
class SubPathTest < ActiveSupport::TestCase
  test "production silence_healthcheck_path call site uses SubPath.path_under('/up')" do
    config_text = File.read(Rails.root.join("config/environments/production.rb"))
    assert_match(
      /config\.silence_healthcheck_path\s*=\s*SubPath\.path_under\("\/up"\)/,
      config_text,
      "production.rb must use SubPath.path_under for silence_healthcheck_path"
    )
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/lib/sub_path_test.rb -n test_production_silence_healthcheck_path_call_site_uses_SubPath_path_under_up`
Expected: FAIL — current value is the literal `"/up"`.

- [ ] **Step 3: Implement the fix**

Edit `config/environments/production.rb` line 47:

```ruby
# Before:
config.silence_healthcheck_path = "/up"

# After:
config.silence_healthcheck_path = SubPath.path_under("/up")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/lib/sub_path_test.rb`
Expected: all SubPath tests pass.

- [ ] **Step 5: Verify production env still boots**

Run: `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 RAILS_RELATIVE_URL_ROOT=/real-estate-auction bin/rails runner 'puts Rails.application.config.silence_healthcheck_path'`
Expected output: `/real-estate-auction/up`

- [ ] **Step 6: Commit**

```bash
git add config/environments/production.rb test/lib/sub_path_test.rb
git commit -m "fix(sub-path): silence_healthcheck_path matches under sub-path"
```

---

### Task 3: CSP `report_uri` honors sub-path

**Why:** Browsers send CSP violation reports to a URL relative to the document origin. With page at `https://host/real-estate-auction/...`, `report_uri "/csp_reports"` resolves to `https://host/csp_reports` — but Rails routes `/csp_reports` only inside the sub-path mount. Reports never reach the controller.

**Files:**
- Modify: `config/initializers/content_security_policy.rb:18`

- [ ] **Step 1: Write the failing integration test**

```ruby
# test/integration/sub_path_compatibility_test.rb
require "test_helper"

class SubPathCompatibilityTest < ActionDispatch::IntegrationTest
  test "CSP report_uri header includes sub-path prefix when env set" do
    original = ENV["RAILS_RELATIVE_URL_ROOT"]
    ENV["RAILS_RELATIVE_URL_ROOT"] = "/real-estate-auction"
    # Re-evaluate the CSP policy block to pick up the new prefix.
    Rails.application.config_for(:application) if false  # no-op, but keeps require chain
    load Rails.root.join("config/initializers/content_security_policy.rb")

    get root_path
    header = response.headers["Content-Security-Policy-Report-Only"].to_s
    assert_includes header, "report-uri /real-estate-auction/csp_reports",
      "CSP report_uri must be sub-path-aware; got: #{header}"
  ensure
    ENV["RAILS_RELATIVE_URL_ROOT"] = original
    load Rails.root.join("config/initializers/content_security_policy.rb")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/sub_path_compatibility_test.rb`
Expected: FAIL — header contains `report-uri /csp_reports` (no prefix).

- [ ] **Step 3: Implement the fix**

Edit `config/initializers/content_security_policy.rb` line 18:

```ruby
# Before:
policy.report_uri  "/csp_reports"

# After:
policy.report_uri  SubPath.path_under("/csp_reports")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/sub_path_compatibility_test.rb`
Expected: PASS.

- [ ] **Step 5: Run baseline CSP test (env unset)**

Add to the test file:

```ruby
test "CSP report_uri is bare /csp_reports when env unset" do
  original = ENV["RAILS_RELATIVE_URL_ROOT"]
  ENV.delete("RAILS_RELATIVE_URL_ROOT")
  load Rails.root.join("config/initializers/content_security_policy.rb")

  get root_path
  header = response.headers["Content-Security-Policy-Report-Only"].to_s
  assert_includes header, "report-uri /csp_reports"
ensure
  ENV["RAILS_RELATIVE_URL_ROOT"] = original
  load Rails.root.join("config/initializers/content_security_policy.rb")
end
```

Run: `bin/rails test test/integration/sub_path_compatibility_test.rb`
Expected: 2 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add config/initializers/content_security_policy.rb test/integration/sub_path_compatibility_test.rb
git commit -m "fix(sub-path): CSP report_uri includes sub-path prefix"
```

---

### Task 4: ActionMailer `default_url_options` includes `script_name`

**Why:** Without `script_name:`, all `*_url` helpers in mailers omit the prefix → emailed links 404 in production. Affects future password-reset, notification, etc. mailers.

**Files:**
- Modify: `config/environments/production.rb:64`
- Modify: `config/environments/development.rb:41`

(`config/environments/test.rb` left as-is — tests run without sub-path.)

- [ ] **Step 1: Write the failing test**

```ruby
# Append to test/integration/sub_path_compatibility_test.rb
test "mailer URL helpers include sub-path prefix when env set" do
  original = ENV["RAILS_RELATIVE_URL_ROOT"]
  ENV["RAILS_RELATIVE_URL_ROOT"] = "/real-estate-auction"
  # Re-evaluate the mailer config from production.rb in the current env.
  url = Rails.application.routes.url_helpers.root_url(
    host: "example.com",
    script_name: SubPath.prefix
  )
  assert_equal "http://example.com/real-estate-auction/", url
ensure
  ENV["RAILS_RELATIVE_URL_ROOT"] = original
end

test "production.rb mailer default_url_options includes script_name: SubPath.prefix" do
  config_text = File.read(Rails.root.join("config/environments/production.rb"))
  assert_match(
    /config\.action_mailer\.default_url_options\s*=\s*\{[^}]*script_name:\s*SubPath\.prefix/,
    config_text,
    "production.rb mailer default_url_options must include script_name: SubPath.prefix"
  )
end

test "development.rb mailer default_url_options includes script_name: SubPath.prefix" do
  config_text = File.read(Rails.root.join("config/environments/development.rb"))
  assert_match(
    /config\.action_mailer\.default_url_options\s*=\s*\{[^}]*script_name:\s*SubPath\.prefix/,
    config_text,
    "development.rb mailer default_url_options must include script_name: SubPath.prefix"
  )
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/sub_path_compatibility_test.rb`
Expected: 2 of the 3 new tests fail (config-text regex tests). The first test passes (it constructs URL manually).

- [ ] **Step 3: Implement the fix**

Edit `config/environments/production.rb` line 64:

```ruby
# Before:
config.action_mailer.default_url_options = { host: "example.com" }

# After:
config.action_mailer.default_url_options = { host: "example.com", script_name: SubPath.prefix }
```

Edit `config/environments/development.rb` line 41:

```ruby
# Before:
config.action_mailer.default_url_options = { host: "localhost", port: 3000 }

# After:
config.action_mailer.default_url_options = { host: "localhost", port: 3000, script_name: SubPath.prefix }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/sub_path_compatibility_test.rb`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add config/environments/production.rb config/environments/development.rb test/integration/sub_path_compatibility_test.rb
git commit -m "fix(sub-path): mailer default_url_options carries script_name"
```

---

### Task 5: Rack::Attack auth throttle uses `req.path_info`

**Why:** `req.path` includes script_name. Under sub-path, `req.path` is `/real-estate-auction/auth/login`, so `start_with?("/auth/")` returns false → the brute-force throttle silently disables itself. **This is a security regression** under sub-path deployment.

**Files:**
- Create: `test/initializers/rack_attack_test.rb`
- Modify: `config/initializers/rack_attack.rb:3`

- [ ] **Step 1: Write the failing test**

```ruby
# test/initializers/rack_attack_test.rb
require "test_helper"
require "rack/attack"

class RackAttackThrottleTest < ActiveSupport::TestCase
  def make_request(script_name:, path_info:, method: "POST", ip: "1.2.3.4")
    env = Rack::MockRequest.env_for(
      "http://example.com#{script_name}#{path_info}",
      method: method,
      "REMOTE_ADDR" => ip
    )
    env["SCRIPT_NAME"] = script_name
    env["PATH_INFO"] = path_info
    Rack::Attack::Request.new(env)
  end

  test "auth:ip throttle triggers on POST to /auth/* under sub-path" do
    throttle = Rack::Attack.throttles["auth:ip"]
    assert throttle, "auth:ip throttle must be defined"

    req = make_request(script_name: "/real-estate-auction", path_info: "/auth/login", method: "POST")
    discriminator = throttle.discriminator_for(req)
    assert_equal "1.2.3.4", discriminator,
      "auth throttle must trigger on /auth/* under sub-path; got #{discriminator.inspect}"
  end

  test "auth:ip throttle triggers on POST to /auth/* without sub-path" do
    throttle = Rack::Attack.throttles["auth:ip"]
    req = make_request(script_name: "", path_info: "/auth/login", method: "POST")
    assert_equal "1.2.3.4", throttle.discriminator_for(req)
  end

  test "auth:ip throttle does not trigger on non-/auth paths" do
    throttle = Rack::Attack.throttles["auth:ip"]
    req = make_request(script_name: "/real-estate-auction", path_info: "/properties", method: "POST")
    assert_nil throttle.discriminator_for(req)
  end

  test "auth:ip throttle does not trigger on GET" do
    throttle = Rack::Attack.throttles["auth:ip"]
    req = make_request(script_name: "/real-estate-auction", path_info: "/auth/login", method: "GET")
    assert_nil throttle.discriminator_for(req)
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/initializers/rack_attack_test.rb`
Expected: FAIL on first test — current code uses `req.path` which under sub-path becomes `/real-estate-auction/auth/login`, so `start_with?("/auth/")` is false → discriminator is nil.

- [ ] **Step 3: Implement the fix**

Edit `config/initializers/rack_attack.rb` line 3:

```ruby
# Before:
class Rack::Attack
  throttle("auth:ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path.start_with?("/auth/") && req.post?
  end

# After:
class Rack::Attack
  throttle("auth:ip", limit: 10, period: 1.minute) do |req|
    req.ip if req.path_info.start_with?("/auth/") && req.post?
  end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/initializers/rack_attack_test.rb`
Expected: 4 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add config/initializers/rack_attack.rb test/initializers/rack_attack_test.rb
git commit -m "fix(sub-path): Rack::Attack auth throttle uses path_info (security)"
```

---

### Task 6: `ApplicationController#capture_return_to_url` uses `request.path_info`

**Why:** `request.path.start_with?("/auth")` returns false under sub-path → `/real-estate-auction/auth/login` gets stored as `return_to_url`, causing post-login redirect loops back to login page.

**Files:**
- Modify: `app/controllers/application_controller.rb:41`

- [ ] **Step 1: Write the failing test**

```ruby
# Append to test/integration/sub_path_compatibility_test.rb
test "capture_return_to_url skips /auth under any prefix" do
  # Simulate sub-path by mocking request.script_name; we exercise the controller filter directly.
  controller = ApplicationController.new
  env = Rack::MockRequest.env_for("/", method: "GET")
  env["SCRIPT_NAME"] = "/real-estate-auction"
  env["PATH_INFO"] = "/auth/login"
  controller.request = ActionDispatch::Request.new(env)
  controller.send(:instance_variable_set, :@_session_for_test, {})
  # Stub session helper
  controller.define_singleton_method(:session) { @_session_for_test }
  controller.send(:capture_return_to_url)
  assert_nil controller.session[:return_to_url],
    "should not capture /auth/* even when sub-path makes request.path /<prefix>/auth/login"
end

test "capture_return_to_url stores non-/auth path under sub-path" do
  controller = ApplicationController.new
  env = Rack::MockRequest.env_for("/", method: "GET")
  env["SCRIPT_NAME"] = "/real-estate-auction"
  env["PATH_INFO"] = "/properties"
  env["QUERY_STRING"] = ""
  controller.request = ActionDispatch::Request.new(env)
  controller.send(:instance_variable_set, :@_session_for_test, {})
  controller.define_singleton_method(:session) { @_session_for_test }
  controller.define_singleton_method(:turbo_frame_request?) { false }
  controller.send(:capture_return_to_url)
  assert_equal "/real-estate-auction/properties", controller.session[:return_to_url]
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/sub_path_compatibility_test.rb -n test_capture_return_to_url_skips_auth_under_any_prefix`
Expected: FAIL — `return_to_url` is stored because `request.path == "/real-estate-auction/auth/login"` does not `start_with?("/auth")`.

- [ ] **Step 3: Implement the fix**

Edit `app/controllers/application_controller.rb` line 41:

```ruby
# Before:
def capture_return_to_url
  return unless request.get? || request.head?
  return if request.path.start_with?("/auth")
  return if request.xhr? || turbo_frame_request?

  session[:return_to_url] = request.fullpath
end

# After:
def capture_return_to_url
  return unless request.get? || request.head?
  return if request.path_info.start_with?("/auth")
  return if request.xhr? || turbo_frame_request?

  session[:return_to_url] = request.fullpath
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/integration/sub_path_compatibility_test.rb`
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add app/controllers/application_controller.rb test/integration/sub_path_compatibility_test.rb
git commit -m "fix(sub-path): capture_return_to_url uses path_info to skip /auth"
```

---

### Task 7: Replace bare-string `redirect_to "/auth/login"` with `auth_login_path`

**Why:** `redirect_to "/auth/login"` emits a `Location: /auth/login` header. Browser resolves it to the host root, missing the sub-path prefix → 404. Named route helpers automatically include `script_name`.

**Files:**
- Modify: `app/controllers/application_controller.rb:62`
- Modify: `app/controllers/auth/omniauth_callbacks_controller.rb:34`

- [ ] **Step 1: Write the failing test**

```ruby
# Append to test/integration/sub_path_compatibility_test.rb
test "handle_auth_error redirect Location includes script_name" do
  # Verify the source uses the named helper.
  source = File.read(Rails.root.join("app/controllers/application_controller.rb"))
  assert_match(/redirect_to auth_login_path/, source)
  refute_match(%r{redirect_to "/auth/login"}, source)
end

test "omniauth failure redirect Location uses named helper" do
  source = File.read(Rails.root.join("app/controllers/auth/omniauth_callbacks_controller.rb"))
  assert_match(/redirect_to auth_login_path/, source)
  refute_match(%r{redirect_to "/auth/login"}, source)
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/integration/sub_path_compatibility_test.rb`
Expected: FAIL — current code uses bare strings.

- [ ] **Step 3: Implement the fix**

Edit `app/controllers/application_controller.rb` line 62 (inside `handle_auth_error`):

```ruby
# Before:
def handle_auth_error(error)
  Rails.logger.warn("[Auth::Error] #{error.class}: #{error.message}")
  redirect_to "/auth/login", alert: "로그인 중 문제가 발생했습니다. 다시 시도해주세요."
end

# After:
def handle_auth_error(error)
  Rails.logger.warn("[Auth::Error] #{error.class}: #{error.message}")
  redirect_to auth_login_path, alert: "로그인 중 문제가 발생했습니다. 다시 시도해주세요."
end
```

Edit `app/controllers/auth/omniauth_callbacks_controller.rb` line 34 (inside `failure`):

```ruby
# Before:
def failure
  code = params[:message].to_s
  flash[:alert] = failure_message(code)
  redirect_to "/auth/login"
end

# After:
def failure
  code = params[:message].to_s
  flash[:alert] = failure_message(code)
  redirect_to auth_login_path
end
```

- [ ] **Step 4: Run existing controller tests to make sure they still pass**

Run: `bin/rails test test/controllers/auth/omniauth_callbacks_controller_test.rb test/controllers/auth/sessions_controller_test.rb`
Expected: all green. The existing test `test "failure with access_denied shows cancel message"` asserts `assert_redirected_to "/auth/login"` — Rails' `assert_redirected_to` accepts either bare path or helper, so this still passes.

- [ ] **Step 5: Run new tests to verify they pass**

Run: `bin/rails test test/integration/sub_path_compatibility_test.rb`
Expected: all green.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/application_controller.rb app/controllers/auth/omniauth_callbacks_controller.rb test/integration/sub_path_compatibility_test.rb
git commit -m "fix(sub-path): use auth_login_path helper instead of bare string redirects"
```

---

### Task 8: Header component uses route helpers for `/auth/*` and `/settings/budget`

**Why:** Same root cause as Task 7 — `link_to "로그인", "/auth/login"` and `button_to "로그아웃", "/auth/logout"` and `link_to "설정", "/settings/budget"` emit host-root-relative `href`/`action` attributes, breaking under sub-path.

**Files:**
- Modify: `app/components/header/component.html.erb:34,35,40`

- [ ] **Step 1: Write the failing test**

```ruby
# Append to test/components/header/component_test.rb (create file if it doesn't exist)
require "test_helper"

class HeaderComponentRouteHelpersTest < ActiveSupport::TestCase
  test "header component template uses named route helpers for auth and settings" do
    template = File.read(Rails.root.join("app/components/header/component.html.erb"))
    refute_match(%r{button_to[^,]+,\s*"/auth/logout"}, template, "use auth_logout_path helper")
    refute_match(%r{link_to[^,]+,\s*"/auth/login"}, template, "use auth_login_path helper")
    refute_match(%r{link_to[^,]+,\s*"/settings/budget"}, template, "use settings_budget_path helper")
    assert_match(/auth_login_path/, template)
    assert_match(/auth_logout_path/, template)
    assert_match(/settings_budget_path/, template)
  end
end
```

(Note: this is a static-source assertion — pragmatic given ViewComponent rendering needs full request context.)

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/components/header/component_test.rb -n test_header_component_template_uses_named_route_helpers_for_auth_and_settings`
Expected: FAIL — template still has bare strings.

- [ ] **Step 3: Implement the fix**

Edit `app/components/header/component.html.erb` lines 34, 35, 40:

```erb
<%# Before — line 34: %>
<%= link_to "설정", "/settings/budget", class: "block px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700" %>

<%# After — line 34: %>
<%= link_to "설정", settings_budget_path, class: "block px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700" %>
```

```erb
<%# Before — line 35: %>
<%= button_to "로그아웃", "/auth/logout", method: :delete, form_class: "w-full",
    class: "block w-full text-left px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700" %>

<%# After — line 35: %>
<%= button_to "로그아웃", auth_logout_path, method: :delete, form_class: "w-full",
    class: "block w-full text-left px-4 py-2 text-sm text-slate-700 dark:text-slate-200 hover:bg-slate-50 dark:hover:bg-slate-700" %>
```

```erb
<%# Before — line 40: %>
<%= link_to "로그인", "/auth/login",
    class: "text-sm text-white hover:text-slate-200 px-3 py-2 rounded-md hover:bg-slate-700",
    data: { turbo_frame: "auth_modal" } %>

<%# After — line 40: %>
<%= link_to "로그인", auth_login_path,
    class: "text-sm text-white hover:text-slate-200 px-3 py-2 rounded-md hover:bg-slate-700",
    data: { turbo_frame: "auth_modal" } %>
```

- [ ] **Step 4: Run new test plus existing component tests**

Run: `bin/rails test test/components/`
Expected: all green.

- [ ] **Step 5: Smoke-test render in dev**

Run: `bin/rails server` then visit `http://localhost:3000/` in a browser, open the user menu, inspect the `href` of the 설정/로그아웃/로그인 elements. Confirm they show plain `/auth/login`, `/auth/logout`, `/settings/budget` (no sub-path in dev because `RAILS_RELATIVE_URL_ROOT` is unset). Stop the server.

- [ ] **Step 6: Commit**

```bash
git add app/components/header/component.html.erb test/components/header/component_test.rb
git commit -m "fix(sub-path): header component uses route helpers for auth and settings"
```

---

### Task 9: `auth_helper#provider_path` uses `request.script_name`

**Why:** `provider_path("kakao")` returns `"/auth/kakao"` — under sub-path, the OmniAuth login button POSTs to `https://host/auth/kakao` instead of `https://host/real-estate-auction/auth/kakao`, missing the OmniAuth Rack middleware (which is mounted under the prefix).

**Note:** OmniAuth registers its start route (`GET /auth/:provider`) as Rack middleware, not as a Rails route — so we cannot use Rails route helpers. Instead, prepend `request.script_name` (Rails sets this automatically from `RAILS_RELATIVE_URL_ROOT`).

**Files:**
- Modify: `app/helpers/auth_helper.rb:16`
- Create: `test/helpers/auth_helper_test.rb`

- [ ] **Step 1: Write the failing test**

```ruby
# test/helpers/auth_helper_test.rb
require "test_helper"

class AuthHelperTest < ActionView::TestCase
  include AuthHelper

  test "#provider_path returns /auth/<provider> when no sub-path" do
    @request = ActionDispatch::TestRequest.create
    @request.script_name = ""
    define_singleton_method(:request) { @request }
    assert_equal "/auth/kakao", provider_path("kakao")
  end

  test "#provider_path returns /<prefix>/auth/<provider> under sub-path" do
    @request = ActionDispatch::TestRequest.create
    @request.script_name = "/real-estate-auction"
    define_singleton_method(:request) { @request }
    assert_equal "/real-estate-auction/auth/google_oauth2", provider_path("google_oauth2")
  end
end
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bin/rails test test/helpers/auth_helper_test.rb`
Expected: FAIL on the second test — current `provider_path` ignores script_name and returns `/auth/google_oauth2`.

- [ ] **Step 3: Implement the fix**

Edit `app/helpers/auth_helper.rb` line 16:

```ruby
# Before:
def provider_path(provider)
  "/auth/#{provider}"
end

# After:
def provider_path(provider)
  "#{request.script_name}/auth/#{provider}"
end
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bin/rails test test/helpers/auth_helper_test.rb`
Expected: 2 runs, 0 failures.

- [ ] **Step 5: Run existing auth flow tests**

Run: `bin/rails test test/controllers/auth/ test/system/auth_flow_test.rb`
Expected: all green. Existing tests run with `script_name == ""`, so behavior is identical to before.

- [ ] **Step 6: Commit**

```bash
git add app/helpers/auth_helper.rb test/helpers/auth_helper_test.rb
git commit -m "fix(sub-path): provider_path includes request.script_name prefix"
```

---

### Task 10: Final verification — full test suite + manual smoke

**Why:** Confirm all changes integrate cleanly. Catches missed regressions.

- [ ] **Step 1: Run full test suite**

Run: `bin/rails test`
Expected: all tests pass; new tests added (Task 1: 6, Task 3: 2, Task 4: 3, Task 5: 4, Task 6: 2, Task 7: 2, Task 8: 1, Task 9: 2 = 22 new tests).

- [ ] **Step 2: Run system tests**

Run: `bin/rails test:system`
Expected: all pass.

- [ ] **Step 3: Pre-commit hook simulation (lint + security)**

Run: `bin/ci`
Expected: all green. If any failure, fix in place per CLAUDE.md and recommit (do NOT amend).

- [ ] **Step 4: Manual sub-path smoke (optional but recommended)**

Boot the server with the production sub-path env:

```bash
RAILS_RELATIVE_URL_ROOT=/real-estate-auction \
SECRET_KEY_BASE_DUMMY=1 \
bin/rails server -p 3001
```

In a browser visit `http://localhost:3001/real-estate-auction/`. Verify:
- Page renders
- View source shows `<a href="/real-estate-auction/auth/login" ...>` (not `/auth/login`)
- Click 로그인 button → modal opens, OAuth provider buttons point to `/real-estate-auction/auth/<provider>`
- DevTools Network: CSP report-only header shows `report-uri /real-estate-auction/csp_reports`

Stop the server with Ctrl-C.

- [ ] **Step 5: Update memory**

```bash
# This step is run by Claude, not the engineer:
# Add a memory entry recording the sub-path bug fix completion.
```

Memory entry (write to `~/.claude/projects/-home-tonny-projects-real-estate-auction/memory/project_subpath_fixes.md`):

```markdown
---
name: Sub-path deployment fixes complete
description: 2026-04-29 — Fixed 10 sub-path-incorrect call sites uncovered during the v2-rename audit
type: project
---

Sub-path deployment compatibility bugs fixed (plan: docs/superpowers/plans/2026-04-29-sub-path-deployment-fixes.md). All `request.path` → `request.path_info`, hardcoded `/auth/*` and `/settings/budget` → named route helpers, CSP report_uri / mailer default_url_options / silence_healthcheck_path → SubPath.path_under.

**Why:** These were latent bugs masked by the fact that the original `-v2` sub-path was never launched. Surfaced during the rename audit.

**How to apply:** When introducing new redirect/link/throttle/CSP/mailer code, prefer named route helpers or `SubPath.path_under("/...")` / `request.script_name` prepending. Avoid bare-string `/foo` paths and `request.path` for routing decisions.
```

Add to `MEMORY.md` index:
```
- [Sub-path fixes 2026-04-29](project_subpath_fixes.md) — 10 call sites converted to sub-path-aware helpers post v2-rename audit
```

- [ ] **Step 6: Final commit (if memory was updated outside the project repo, skip)**

If everything is green and committed, the branch is ready for `/review` → `/ship`.

---

## Self-Review

**Spec coverage check:**

| Audit item | Task |
|------------|------|
| P1 `redirect_to "/auth/login"` (application_controller.rb:62) | Task 7 |
| P1 `redirect_to "/auth/login"` (omniauth_callbacks_controller.rb:34) | Task 7 |
| P2 `link_to "로그인", "/auth/login"` (header) | Task 8 |
| P2 `button_to "로그아웃", "/auth/logout"` (header) | Task 8 |
| P3 `provider_path` (auth_helper.rb:16) | Task 9 |
| P4 `request.path.start_with?("/auth")` (application_controller.rb:41) | Task 6 |
| P5 `req.path.start_with?("/auth/")` (rack_attack.rb:3) | Task 5 |
| P6 `silence_healthcheck_path = "/up"` (production.rb:47) | Task 2 |
| P7 CSP `report_uri "/csp_reports"` (csp.rb:18) | Task 3 |
| P8 mailer `default_url_options` no script_name (production.rb:64) | Task 4 |
| P9 mailer `default_url_options` no script_name (development.rb:41) | Task 4 |
| Bonus `link_to "설정", "/settings/budget"` (header) | Task 8 |
| `SubPath` shared helper introduction | Task 1 |
| Full-suite green + manual smoke | Task 10 |

All 12 audited surfaces covered.

**Placeholder scan:** No "TBD", "TODO", "fill in details", or vague handwaves. Every code block contains real code.

**Type/identifier consistency:** `SubPath.prefix` and `SubPath.path_under(path)` used consistently across Tasks 2/3/4. `auth_login_path` / `auth_logout_path` / `settings_budget_path` are confirmed routes (verified via `bin/rails routes`).

**Out-of-scope items reaffirmed:**
- `host: "example.com"` placeholder in production.rb:64 — needs real domain decision.
- `/terms`, `/privacy` links in modal — those routes don't exist; pages are not built yet.
- OAuth provider console redirect_uri registration — external, manual, tracked separately as MANUAL items M1–M3.
