require "test_helper"

class IdentityTest < ActiveSupport::TestCase
  test "belongs to user" do
    user = User.create!(guest: false, email: "x@y.com")
    id = Identity.create!(user: user, provider: "kakao", uid: "123")
    assert_equal user, id.user
  end

  test "provider + uid pair is unique at the model layer" do
    user = User.create!(guest: false, email: "a@b.com")
    Identity.create!(user: user, provider: "kakao", uid: "123")
    assert_raises(ActiveRecord::RecordInvalid) do
      Identity.create!(user: user, provider: "kakao", uid: "123")
    end
  end

  test "provider + uid pair is unique at the DB layer (validation bypassed)" do
    user = User.create!(guest: false, email: "db@uniq.com")
    Identity.create!(user: user, provider: "kakao", uid: "456")
    dup = Identity.new(user: user, provider: "kakao", uid: "456")
    assert_raises(ActiveRecord::RecordNotUnique) do
      dup.save(validate: false)
    end
  end

  test "same uid across different providers is allowed" do
    user = User.create!(guest: false, email: "m@n.com")
    Identity.create!(user: user, provider: "kakao", uid: "123")
    assert_nothing_raised do
      Identity.create!(user: user, provider: "google", uid: "123")
    end
  end
end
