require "test_helper"

class ManualsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url # bootstrap a guest session (lazy guest creation)
  end

  test "GET /manual returns 200 (renders successfully with @progress computed)" do
    # Sanity: the action calls Manuals::Progress.for(current_user) and assigns @progress.
    # If that call raised, the response would not be 200. Assigns introspection was
    # extracted from Rails 5+ (rails-controller-testing gem) and isn't loaded here;
    # downstream Component tasks (11-15) exercise @progress data shape directly.
    get manual_url

    assert_response :success
  end

  test "manual hero shows a '지금 시작하기' CTA leading to the onboarding wizard (C8)" do
    get manual_url
    assert_response :success

    # C8: the manual hero copy is inspirational but vague — pair it with a
    # concrete next-step CTA so first-time visitors aren't left with "what
    # do I do now?".
    assert_select "a[href=?]", start_onboarding_path, { text: /지금 시작하기/ }
  end

  test "GET /manual without session redirects to login (lazy guest creation)" do
    reset!

    assert_no_difference "User.count" do
      get manual_url
    end
    assert_redirected_to auth_login_path
  end

  test "GET /manual renders Korean copy (locale switched to :ko)" do
    get manual_url

    assert_select "h1", text: "경매 초보의 워크북"
  end
end
