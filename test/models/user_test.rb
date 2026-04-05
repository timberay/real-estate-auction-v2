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
end
