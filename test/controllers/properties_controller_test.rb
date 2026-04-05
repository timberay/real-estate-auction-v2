require "test_helper"

class PropertiesControllerTest < ActionDispatch::IntegrationTest
  test "GET index returns success" do
    get properties_url
    assert_response :success
  end

  test "GET index filters by safety_rating" do
    get properties_url(safety_rating: "safe")
    assert_response :success
  end

  test "GET show returns success" do
    property = properties(:safe_apartment)
    get property_url(property)
    assert_response :success
  end
end
