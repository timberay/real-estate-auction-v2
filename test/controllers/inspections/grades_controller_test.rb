require "test_helper"

class Inspections::GradesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:safe_apartment)
    UserProperty.find_or_create_by!(user: users(:guest), property: @property)
    PropertyInspectionService.call(property: @property, user: users(:guest))
  end

  test "show renders grade page" do
    get property_inspections_grade_url(@property)
    assert_response :success
  end
end
