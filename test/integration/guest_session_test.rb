require "test_helper"

class GuestSessionTest < ActionDispatch::IntegrationTest
  test "first visit creates a new guest with its own user_id" do
    get root_path
    assert_response :redirect
    assert User.exists?(session[:user_id])
    user = User.find(session[:user_id])
    assert user.guest?
  end

  test "two separate sessions get different guest user_ids" do
    session1 = open_session
    session1.get root_path
    uid1 = session1.session[:user_id]

    session2 = open_session
    session2.get root_path
    uid2 = session2.session[:user_id]

    refute_equal uid1, uid2, "two browsers must get distinct guest users"
  end

  test "GET request captures return_to_url in session" do
    get "/properties"
    assert_equal "/properties", session[:return_to_url]
  end

  test "POST request does NOT capture return_to_url" do
    get root_path
    before = session[:return_to_url]
    post "/properties", params: { case_number: "2024-test" }
    assert_equal before, session[:return_to_url], "POST must not overwrite return_to_url"
  end
end
