require "test_helper"

class EvictionGuideControllerTest < ActionDispatch::IntegrationTest
  test "guide renders successfully" do
    get eviction_guide_guide_url
    assert_response :success
  end

  test "simulator renders successfully" do
    get eviction_guide_simulator_url
    assert_response :success
  end

  test "simulator with property_id pre-selects property" do
    property = properties(:safe_apartment)
    get eviction_guide_simulator_url(property_id: property.id)
    assert_response :success
  end
end
