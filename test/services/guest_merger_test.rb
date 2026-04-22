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
end
