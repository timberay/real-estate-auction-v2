require "test_helper"
require "axe-capybara"
require "axe/matchers/be_axe_clean"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 900 ]

  # Sign in as a fixture user via the test-only POST /testing/sign_in endpoint.
  # Must be called after at least one `visit` so the browser has an origin.
  def sign_in_as(user)
    visit root_path unless page.current_url.start_with?("http")
    page.execute_script(<<~JS)
      fetch('/testing/sign_in', {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: 'user_id=#{user.id}',
        credentials: 'same-origin'
      })
    JS
    sleep 0.3
  end

  # Run axe-core against the current page and assert no violations remain.
  # Pass `skip_rules: [...]` to suppress known rules tracked as a11y debt
  # (master TODO T4.6 follow-ups). Pass `within:` to scope to one element.
  def assert_axe_clean(within: nil, skip_rules: [])
    audit = Axe::Matchers::BeAxeClean.new
    audit = audit.within(within) if within
    audit = audit.skipping(*skip_rules) if skip_rules.any?
    matches = audit.matches?(page)
    assert matches, audit.failure_message
  end
end
