require "test_helper"

class Properties::UserPropertySettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership

    @property = properties(:safe_apartment)
    @user_property = UserProperty.find_by!(user: @user, property: @property)
  end

  # Auth
  test "unauthenticated GET edit redirects to login" do
    delete auth_logout_path
    get edit_property_user_property_settings_path(@property)
    assert_redirected_to auth_login_path
  end

  test "unauthenticated PATCH update redirects to login" do
    delete auth_logout_path
    patch property_user_property_settings_path(@property), params: { user_property: { notes: "test" } }
    assert_redirected_to auth_login_path
  end

  # Authorization — non-owner gets 404
  test "non-owner GET edit returns 404" do
    other_property = properties(:risky_villa)
    UserProperty.where(user: @user, property: other_property).destroy_all
    get edit_property_user_property_settings_path(other_property)
    assert_response :not_found
  end

  # Happy path — edit
  test "GET edit returns 200 and renders the notes form" do
    get edit_property_user_property_settings_path(@property)
    assert_response :success
    assert_select "textarea[name='user_property[notes]']"
    assert_select "input[name='user_property[inspection_visited_on]']"
  end

  # Happy path — update
  test "PATCH update persists notes and inspection_visited_on" do
    patch property_user_property_settings_path(@property),
      params: { user_property: { notes: "시세 8.5억", inspection_visited_on: "2026-05-10" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    @user_property.reload
    assert_equal "시세 8.5억", @user_property.notes
    assert_equal Date.new(2026, 5, 10), @user_property.inspection_visited_on
  end

  test "PATCH update without turbo redirects to property path" do
    patch property_user_property_settings_path(@property),
      params: { user_property: { notes: "메모", inspection_visited_on: "" } }
    assert_redirected_to property_path(@property)
  end

  # Notes frame — display mode renders in turbo frame
  test "GET edit wraps form in user-property-notes-edit turbo frame" do
    get edit_property_user_property_settings_path(@property)
    assert_response :success
    assert_select "turbo-frame[id='user-property-notes-edit']"
  end
end
