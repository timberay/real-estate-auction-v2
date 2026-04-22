require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "new user defaults to guest: true" do
    user = User.create!
    assert user.guest?
  end

  test "guest user gets a unique guest_token automatically" do
    u1 = User.create!
    u2 = User.create!
    assert u1.guest_token.present?
    assert u2.guest_token.present?
    refute_equal u1.guest_token, u2.guest_token
  end

  test "account user (guest: false) does not require guest_token" do
    account = User.create!(guest: false, email: "a@example.com")
    assert_nil account.guest_token
  end

  test "two guests with null email coexist" do
    User.create!
    assert_nothing_raised { User.create! }
  end

  test "two account users with same email are rejected at DB level" do
    User.create!(guest: false, email: "dup@example.com")
    assert_raises(ActiveRecord::RecordNotUnique) do
      User.create!(guest: false, email: "dup@example.com")
    end
  end

  test "account user and guest with same email coexist" do
    User.create!(guest: false, email: "shared@example.com")
    assert_nothing_raised { User.create!(email: "shared@example.com") }
  end
end
