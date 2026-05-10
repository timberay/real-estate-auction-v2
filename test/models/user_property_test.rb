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

  test "favorite defaults to false" do
    up = UserProperty.new(user: users(:budget_user), property: properties(:unanalyzed_officetel))
    assert_equal false, up.favorite
  end

  test "ordered_for_list sorts favorites first, then by created_at desc" do
    user = users(:guest)
    results = user.user_properties.ordered_for_list.to_a

    favorited = results.select(&:favorite)
    non_favorited = results.reject(&:favorite)

    assert_equal results[0...favorited.size], favorited,
      "favorited items should appear first"
    assert_equal non_favorited.sort_by { |up| -up.created_at.to_i }, non_favorited,
      "non-favorited items should be ordered by created_at desc"
  end

  test "notes and inspection_visited_on persist correctly" do
    up = user_properties(:guest_safe_apartment)
    up.update!(notes: "OO부동산 010-1234-5678 시세 8.5억", inspection_visited_on: Date.new(2026, 5, 10))

    up.reload
    assert_equal "OO부동산 010-1234-5678 시세 8.5억", up.notes
    assert_equal Date.new(2026, 5, 10), up.inspection_visited_on
  end

  test "notes can be blank" do
    up = user_properties(:guest_safe_apartment)
    up.update!(notes: nil, inspection_visited_on: nil)
    assert up.valid?
  end

  test "non-image photo attachment is invalid" do
    up = user_properties(:guest_safe_apartment)
    up.photos.attach(
      io: StringIO.new("not an image"),
      filename: "bad.txt",
      content_type: "text/plain"
    )
    assert_not up.valid?
    assert_includes up.errors[:photos], "이미지 파일만 업로드할 수 있습니다."
  end

  test "image photo attachment is valid" do
    up = user_properties(:guest_safe_apartment)
    up.photos.attach(
      io: StringIO.new("fake png data"),
      filename: "photo.png",
      content_type: "image/png"
    )
    assert up.valid?
  end
end
