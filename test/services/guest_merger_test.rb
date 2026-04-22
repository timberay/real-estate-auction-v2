require "test_helper"

class GuestMergerTest < ActiveSupport::TestCase
  setup do
    @guest = User.create!
    @target = User.create!(guest: false, email: "target@example.com")
  end

  test "prefer_guest reassigns user_id when no collision exists" do
    prop = Property.create!(case_number: "2024-merge-1001")
    @guest.user_properties.create!(property: prop)
    assert_equal 1, @guest.user_properties.count
    assert_equal 0, @target.user_properties.count

    GuestMerger.new(from: @guest, to: @target).call

    assert_raises(ActiveRecord::RecordNotFound) { @guest.reload }
    assert_equal 1, @target.user_properties.count
    assert_equal prop.id, @target.user_properties.first.property_id
  end

  test "prefer_guest deletes target's colliding row when natural_key matches" do
    prop = Property.create!(case_number: "2024-merge-1002")
    @guest.user_properties.create!(property: prop, safety_rating: :safe)
    @target.user_properties.create!(property: prop, safety_rating: :danger)

    guest_up_id = @guest.user_properties.first.id
    target_up_id = @target.user_properties.first.id

    GuestMerger.new(from: @guest, to: @target).call

    @target.reload
    assert_equal 1, @target.user_properties.count
    assert_equal guest_up_id, @target.user_properties.first.id
    assert_equal "safe", @target.user_properties.first.safety_rating
    assert_raises(ActiveRecord::RecordNotFound) { UserProperty.find(target_up_id) }
  end

  test "prefer_guest handles composite natural_key (inspection_results)" do
    prop = Property.create!(case_number: "2024-merge-1003")
    item = InspectionItem.create!(
      code: "merge-test-item", category: "test",
      tab: :rights_analysis, question: "q"
    )
    @guest.inspection_results.create!(property: prop, inspection_item: item, has_risk: true)
    target_ir = @target.inspection_results.create!(
      property: prop, inspection_item: item, has_risk: false
    )

    GuestMerger.new(from: @guest, to: @target).call

    @target.reload
    assert_equal 1, @target.inspection_results.count
    assert_equal true, @target.inspection_results.first.has_risk
    assert_raises(ActiveRecord::RecordNotFound) { InspectionResult.find(target_ir.id) }
  end

  test "keep_target preserves target's api_credentials when collision exists" do
    @target.api_credentials.create!(provider_name: "court_auction", api_key: "REAL_KEY")
    @guest.api_credentials.create!(provider_name: "court_auction", api_key: "GUEST_KEY")

    GuestMerger.new(from: @guest, to: @target).call

    @target.reload
    assert_equal 1, @target.api_credentials.count
    assert_equal "REAL_KEY", @target.api_credentials.first.api_key
  end

  test "keep_target still migrates guest api_credentials when target has none" do
    @guest.api_credentials.create!(provider_name: "court_auction", api_key: "GUEST_ONLY")

    GuestMerger.new(from: @guest, to: @target).call

    @target.reload
    assert_equal 1, @target.api_credentials.count
    assert_equal "GUEST_ONLY", @target.api_credentials.first.api_key
  end

  test "associations without merge_policy are left untouched (safe default)" do
    prop = Property.create!(case_number: "2024-merge-1004")
    log = @guest.llm_analysis_logs.create!(
      property: prop, system_prompt: "sys", user_prompt: "u"
    )

    GuestMerger.new(from: @guest, to: @target).call

    log.reload
    assert_nil log.user_id,
      "llm_analysis_logs has dependent: :nullify — user_id is cleared on @from.destroy!"
  end
end
