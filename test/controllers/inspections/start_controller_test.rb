require "test_helper"

class Inspections::StartControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: users(:guest), property: @property)
  end

  test "creates inspection results and redirects to first tab" do
    post property_inspections_start_url(@property)
    assert_redirected_to edit_property_inspections_tab_url(@property, tab_key: "sale_document")
    assert InspectionResult.where(property: @property, user: users(:guest)).exists?
  end
end
