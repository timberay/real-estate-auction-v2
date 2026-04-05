require "test_helper"

class PropertyTypeTest < ActiveSupport::TestCase
  test "valid with name, code, and enabled" do
    pt = PropertyType.new(name: "아파트", code: "apt_test", enabled: true, sort_order: 0)
    assert pt.valid?
  end

  test "invalid without name" do
    pt = PropertyType.new(name: nil, code: "test", enabled: true)
    assert_not pt.valid?
    assert_includes pt.errors[:name], "can't be blank"
  end

  test "invalid without code" do
    pt = PropertyType.new(name: "테스트", code: nil, enabled: true)
    assert_not pt.valid?
    assert_includes pt.errors[:code], "can't be blank"
  end

  test "invalid with duplicate code" do
    PropertyType.create!(name: "아파트", code: "dup_test", enabled: true)
    pt = PropertyType.new(name: "아파트2", code: "dup_test", enabled: true)
    assert_not pt.valid?
    assert_includes pt.errors[:code], "has already been taken"
  end

  test "scope enabled returns only enabled types" do
    PropertyType.delete_all
    PropertyType.create!(name: "아파트", code: "apartment", enabled: true, sort_order: 0)
    PropertyType.create!(name: "단독주택", code: "house", enabled: false, sort_order: 3)
    enabled = PropertyType.enabled
    assert_equal 1, enabled.count
    assert_equal "apartment", enabled.first.code
  end

  test "scope ordered sorts by sort_order" do
    PropertyType.delete_all
    PropertyType.create!(name: "오피스텔", code: "officetel", enabled: true, sort_order: 2)
    PropertyType.create!(name: "아파트", code: "apartment", enabled: true, sort_order: 0)
    ordered = PropertyType.ordered
    assert_equal "apartment", ordered.first.code
    assert_equal "officetel", ordered.last.code
  end
end
