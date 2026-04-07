require "test_helper"

class Inspections::TabsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: users(:guest), property: @property)
    PropertyInspectionService.call(property: @property, user: users(:guest))
  end

  test "edit renders tab items" do
    get edit_property_inspections_tab_url(@property, tab_key: "sale_document")
    assert_response :success
  end

  test "edit returns 404 for invalid tab" do
    get edit_property_inspections_tab_url(@property, tab_key: "invalid")
    assert_response :not_found
  end
end
