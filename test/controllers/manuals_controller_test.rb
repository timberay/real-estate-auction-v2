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
