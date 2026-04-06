require "test_helper"

class SafetyRatingServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
    @item = checklist_items(:rights_011)
    PropertyCheckResult.where(property: @property, checklist_item: @item, user: @user).destroy_all
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "rates safe when no risks" do
    PropertyCheckResult.create!(property: @property, checklist_item: @item, user: @user, source_type: "auto", has_risk: false)

    SafetyRatingService.call(property: @property, user: @user)
    assert_equal "safe", UserProperty.find_by(user: @user, property: @property).safety_rating
  end

  test "rates caution when risks are all resolvable" do
    PropertyCheckResult.create!(property: @property, checklist_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: true)

    SafetyRatingService.call(property: @property, user: @user)
    assert_equal "caution", UserProperty.find_by(user: @user, property: @property).safety_rating
  end

  test "rates danger when any risk is unresolvable" do
    PropertyCheckResult.create!(property: @property, checklist_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)

    SafetyRatingService.call(property: @property, user: @user)
    assert_equal "danger", UserProperty.find_by(user: @user, property: @property).safety_rating
  end
end
