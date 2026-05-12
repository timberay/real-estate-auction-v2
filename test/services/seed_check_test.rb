require "test_helper"

class SeedCheckTest < ActiveSupport::TestCase
  test "empty_critical_tables returns [] when all fixtures present" do
    assert_equal [], SeedCheck.empty_critical_tables
  end

  test "empty_critical_tables includes 'PropertyType (enabled)' when no enabled rows" do
    PropertyType.update_all(enabled: false)
    assert_includes SeedCheck.empty_critical_tables, "PropertyType (enabled)"
  end

  test "empty_critical_tables includes 'ReserveFundDefault' when empty" do
    ReserveFundDefault.delete_all
    assert_includes SeedCheck.empty_critical_tables, "ReserveFundDefault"
  end

  test "empty_critical_tables includes 'LoanPolicy' when empty" do
    BudgetSetting.update_all(loan_policy_id: nil)
    LoanPolicy.delete_all
    assert_includes SeedCheck.empty_critical_tables, "LoanPolicy"
  end

  test "empty_critical_tables includes 'InspectionItem' when empty" do
    InspectionResult.delete_all
    InspectionItem.delete_all
    assert_includes SeedCheck.empty_critical_tables, "InspectionItem"
  end

  test "empty_critical_tables includes 'EvictionStep' when empty" do
    EvictionStep.delete_all
    assert_includes SeedCheck.empty_critical_tables, "EvictionStep"
  end

  test "report! writes nothing and returns false when no empties" do
    io = StringIO.new
    assert_equal false, SeedCheck.report!(io: io)
    assert_equal "", io.string
  end

  test "report! writes warning naming the empty tables and remediation hint" do
    PropertyType.update_all(enabled: false)
    io = StringIO.new
    assert_equal true, SeedCheck.report!(io: io)
    assert_includes io.string, "PropertyType (enabled)"
    assert_includes io.string, "bin/rails db:seed"
  end
end
