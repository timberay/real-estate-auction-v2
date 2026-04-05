require "test_helper"

class SafetyRatingServiceTest < ActiveSupport::TestCase
  setup do
    @property = properties(:safe_apartment)
    @item = checklist_items(:rights_011)
    PropertyCheckResult.where(property: @property, checklist_item: @item).destroy_all
  end

  test "rates safe when no risks" do
    PropertyCheckResult.create!(property: @property, checklist_item: @item, source_type: "auto", has_risk: false)

    SafetyRatingService.call(property: @property)
    assert_equal "safe", @property.reload.safety_rating
  end

  test "rates caution when risks are all resolvable" do
    PropertyCheckResult.create!(property: @property, checklist_item: @item, source_type: "auto", has_risk: true, resolvable: true)

    SafetyRatingService.call(property: @property)
    assert_equal "caution", @property.reload.safety_rating
  end

  test "rates danger when any risk is unresolvable" do
    PropertyCheckResult.create!(property: @property, checklist_item: @item, source_type: "auto", has_risk: true, resolvable: false)

    SafetyRatingService.call(property: @property)
    assert_equal "danger", @property.reload.safety_rating
  end
end
