require "test_helper"

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
end
