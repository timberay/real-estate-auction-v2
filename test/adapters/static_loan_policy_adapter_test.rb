require "test_helper"

class StaticLoanPolicyAdapterTest < ActiveSupport::TestCase
  setup do
    @adapter = StaticLoanPolicyAdapter.new
  end

  test "fetch_policies returns array of policy hashes" do
    policies = @adapter.fetch_policies(property_type_code: "apartment")
    assert_kind_of Array, policies
    assert policies.length > 0
  end

  test "each policy has required keys" do
    policies = @adapter.fetch_policies(property_type_code: "apartment")
    policy = policies.first

    assert policy.key?(:policy_name)
    assert policy.key?(:loan_ratio)
    assert policy.key?(:description)
    assert policy.key?(:effective_date)
  end

  test "loan_ratio is a numeric between 0 and 1" do
    policies = @adapter.fetch_policies(property_type_code: "apartment")
    policies.each do |policy|
      assert policy[:loan_ratio].is_a?(Numeric)
      assert policy[:loan_ratio] > 0
      assert policy[:loan_ratio] <= 1
    end
  end

  test "fetch_policies for unknown type returns empty array" do
    policies = @adapter.fetch_policies(property_type_code: "spaceship")
    assert_equal [], policies
  end
end
