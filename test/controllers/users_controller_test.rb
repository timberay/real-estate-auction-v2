require "test_helper"

class UsersControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership
  end

  test "toggle_beginner_mode turns off when currently on" do
    @user.update!(beginner_mode: true)

    patch toggle_beginner_mode_path
    assert_response :redirect

    assert_equal false, @user.reload.beginner_mode
  end

  test "toggle_beginner_mode turns on when currently off" do
    @user.update!(beginner_mode: false)

    patch toggle_beginner_mode_path
    assert_response :redirect

    assert_equal true, @user.reload.beginner_mode
  end
end
