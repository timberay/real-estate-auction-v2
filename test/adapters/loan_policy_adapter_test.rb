require "test_helper"

class LoanPolicyAdapterTest < ActiveSupport::TestCase
  test ".for returns MockLoanPolicyAdapter by default" do
    adapter = LoanPolicyAdapter.for
    assert_instance_of MockLoanPolicyAdapter, adapter
  end

  test ".for returns GovernmentLoanPolicyAdapter when adapter is :real" do
    adapter = LoanPolicyAdapter.for(adapter: :real)
    assert_instance_of GovernmentLoanPolicyAdapter, adapter
  end
end
