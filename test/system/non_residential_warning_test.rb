require "application_system_test_case"

# T3.1 — non-residential properties get a tax-matrix warning on the grade
# page. The acquisition/transfer tax matrices are seeded for 주거 types;
# 오피스텔/상가/토지 need user verification.
class NonResidentialWarningTest < ApplicationSystemTestCase
  setup do
    @user = users(:budget_user)
    @apt = properties(:safe_apartment)         # 아파트 → residential
    @officetel = properties(:unanalyzed_officetel)  # 오피스텔 → non-residential
    [ @apt, @officetel ].each { |p| UserProperty.find_or_create_by!(user: @user, property: p) }
    sign_in_as(@user)
  end

  test "residential property does not show the non-residential warning" do
    visit property_inspections_grade_path(@apt)
    assert_no_selector "[data-testid='non-residential-tax-warning']"
  end

  test "officetel property shows the tax matrix warning with officetel copy" do
    visit property_inspections_grade_path(@officetel)
    assert_selector "[data-testid='non-residential-tax-warning']", text: /오피스텔/
    assert_selector "[data-testid='non-residential-tax-warning']", text: /1세대 1주택 비과세/
  end
end
