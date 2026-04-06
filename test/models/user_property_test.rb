require "test_helper"

class UserPropertyTest < ActiveSupport::TestCase
  test "valid with user and property" do
    up = UserProperty.new(user: users(:budget_user), property: properties(:safe_apartment))
    assert up.valid?
  end

  test "requires user" do
    up = UserProperty.new(property: properties(:safe_apartment))
    assert_not up.valid?
  end

  test "requires property" do
    up = UserProperty.new(user: users(:guest))
    assert_not up.valid?
  end

  test "user and property combination must be unique" do
    # Fixture already created guest_safe_apartment
    duplicate = UserProperty.new(user: users(:guest), property: properties(:safe_apartment))
    assert_not duplicate.valid?
  end

  test "safety_rating enum values" do
    up = UserProperty.new(user: users(:budget_user), property: properties(:unanalyzed_officetel))
    up.safety_rating = :safe
    assert up.safe?
    up.safety_rating = :caution
    assert up.caution?
    up.safety_rating = :danger
    assert up.danger?
  end

  test "safety_rating defaults to nil" do
    up = UserProperty.new(user: users(:budget_user), property: properties(:unanalyzed_officetel))
    assert_nil up.safety_rating
  end
end
