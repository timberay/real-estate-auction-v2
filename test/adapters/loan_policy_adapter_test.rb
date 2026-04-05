require "test_helper"

class LoanPolicyAdapterTest < ActiveSupport::TestCase
  test ".for returns MockLoanPolicyAdapter when USE_MOCK is true" do
    ENV["USE_MOCK"] = "true"
    adapter = LoanPolicyAdapter.for
    assert_instance_of MockLoanPolicyAdapter, adapter
  ensure
    ENV.delete("USE_MOCK")
  end

  test ".for returns GovernmentLoanPolicyAdapter when USE_MOCK is false" do
    ENV["USE_MOCK"] = "false"
    adapter = LoanPolicyAdapter.for
    assert_instance_of GovernmentLoanPolicyAdapter, adapter
  ensure
    ENV.delete("USE_MOCK")
  end

  test ".for defaults to MockLoanPolicyAdapter when USE_MOCK is not set" do
    ENV.delete("USE_MOCK")
    adapter = LoanPolicyAdapter.for
    assert_instance_of MockLoanPolicyAdapter, adapter
  end
end
