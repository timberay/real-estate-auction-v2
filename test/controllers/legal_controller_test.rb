require "test_helper"

class LegalControllerTest < ActionDispatch::IntegrationTest
  test "GET /terms returns 200" do
    get terms_url
    assert_response :success
  end

  test "GET /privacy returns 200" do
    get privacy_url
    assert_response :success
  end

  test "GET /terms renders Korean title" do
    get terms_url
    assert_select "h1", /이용약관/
  end

  test "GET /privacy renders Korean title" do
    get privacy_url
    assert_select "h1", /개인정보\s*처리방침/
  end

  test "GET /terms auto-creates a guest user (no auth gate)" do
    assert_difference "User.count", 1 do
      get terms_url
    end
  end

  test "GET /privacy auto-creates a guest user (no auth gate)" do
    assert_difference "User.count", 1 do
      get privacy_url
    end
  end
end
