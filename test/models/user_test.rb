require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "valid user with email and password" do
    user = User.new(email: "test@example.com", password: "password123")
    assert user.valid?
  end

  test "invalid without email" do
    user = User.new(email: nil, password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:email], "can't be blank"
  end

  test "invalid with duplicate email" do
    User.create!(email: "dup@example.com", password: "password123")
    user = User.new(email: "dup@example.com", password: "password456")
    assert_not user.valid?
    assert_includes user.errors[:email], "has already been taken"
  end

  test "invalid without password on create" do
    user = User.new(email: "test@example.com", password: nil)
    assert_not user.valid?
  end

  test "authenticates with correct password" do
    user = User.create!(email: "auth@example.com", password: "secret123")
    assert user.authenticate("secret123")
    assert_not user.authenticate("wrong")
  end

  # -- Search preference convenience methods --

  test "preferred_property_type_code returns property type code from budget setting" do
    user = users(:budget_user)
    assert_equal "apartment", user.preferred_property_type_code
  end

  test "preferred_property_type_code returns nil when no budget setting" do
    user = users(:guest)
    user.budget_setting&.destroy
    assert_nil user.preferred_property_type_code
  end

  test "preferred_area_range returns min/max from budget setting" do
    user = users(:budget_user)
    range = user.preferred_area_range
    assert_equal 59, range[:min]
    assert_equal 84, range[:max]
  end

  test "preferred_area_range returns nil when no budget setting" do
    user = users(:guest)
    user.budget_setting&.destroy
    assert_nil user.preferred_area_range
  end

  test "preferred_area_category returns derived category key" do
    user = users(:budget_user)
    # fixture has area_range 59-84, which doesn't exactly match any category
    # so it falls back to DEFAULT_AREA_CATEGORY ("small")
    # Update fixture to exact match for a meaningful test:
    user.budget_setting.update!(area_range_min: 60, area_range_max: 85)
    assert_equal "mid", user.preferred_area_category
  end
end
