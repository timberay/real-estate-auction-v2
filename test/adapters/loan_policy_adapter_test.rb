require "test_helper"

class LoanPolicyAdapterTest < ActiveSupport::TestCase
  test ".for returns MockLoanPolicyAdapter" do
    adapter = LoanPolicyAdapter.for
    assert_instance_of MockLoanPolicyAdapter, adapter
  end
end
