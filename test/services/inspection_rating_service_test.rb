require "test_helper"

class InspectionRatingServiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
    @property = properties(:safe_apartment)
    @item = inspection_items(:rights_003)
    InspectionResult.where(property: @property, user: @user).destroy_all
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "rates safe when no risks" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :safe, rating
    assert_equal "safe", UserProperty.find_by(user: @user, property: @property).safety_rating
  end

  test "rates caution when risks are all resolvable" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: true)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :caution, rating
  end

  test "rates danger when any risk is unresolvable" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :danger, rating
  end

  test "returns incomplete when unanswered items exist" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :incomplete, rating
  end

  test "tab_rating returns nil when no results for tab" do
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_nil service.tab_rating("rights_analysis")
  end

  test "tab_rating returns incomplete when unanswered items exist in tab" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :incomplete, service.tab_rating("rights_analysis")
  end

  test "tab_rating returns safe when all items in tab have no risk" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :safe, service.tab_rating("rights_analysis")
  end

  test "tab_rating returns caution when risks are resolvable in tab" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: true)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :caution, service.tab_rating("rights_analysis")
  end

  test "tab_rating returns danger when unresolvable risk in tab" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :danger, service.tab_rating("rights_analysis")
  end

  test "tab_rating scopes to specific tab only" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :danger, service.tab_rating("rights_analysis")
    assert_nil service.tab_rating("property_analysis")
  end

  # Partial evaluation: call method (Tasks 1)
  test "rates safe when some items answered safe and others unanswered" do
    item2 = inspection_items(:rights_002)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :safe, rating
  end

  test "rates danger when answered item has unresolvable risk despite unanswered items" do
    item2 = inspection_items(:rights_002)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: true, resolvable: false)
    InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
    rating = InspectionRatingService.call(property: @property, user: @user)
    assert_equal :danger, rating
  end

  # Partial evaluation: tab_rating method (Task 2)
  test "tab_rating rates safe when some tab items answered and others unanswered" do
    item2 = inspection_items(:rights_002)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_equal :safe, service.tab_rating("rights_analysis")
  end

  # fully_evaluated? (Task 3)
  test "fully_evaluated? returns false when no results exist" do
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_not service.fully_evaluated?
  end

  test "fully_evaluated? returns false when unanswered items exist" do
    item2 = inspection_items(:rights_002)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    InspectionResult.create!(property: @property, inspection_item: item2, user: @user)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert_not service.fully_evaluated?
  end

  test "fully_evaluated? returns true when all items answered" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    service = InspectionRatingService.new(property: @property, user: @user)
    assert service.fully_evaluated?
  end

  # tabs_evaluated_count (Task 4)
  test "tabs_evaluated_count returns counts of evaluated and total tabs" do
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    service = InspectionRatingService.new(property: @property, user: @user)
    evaluated, total = service.tabs_evaluated_count
    assert_equal 1, evaluated
    assert_equal 5, total
  end

  test "tabs_evaluated_count counts tab as evaluated when at least one item answered" do
    item_prop = inspection_items(:property_001)
    InspectionResult.create!(property: @property, inspection_item: @item, user: @user, source_type: "auto", has_risk: false)
    InspectionResult.create!(property: @property, inspection_item: item_prop, user: @user, source_type: "auto", has_risk: true, resolvable: true)
    service = InspectionRatingService.new(property: @property, user: @user)
    evaluated, total = service.tabs_evaluated_count
    assert_equal 2, evaluated
    assert_equal 5, total
  end
end
