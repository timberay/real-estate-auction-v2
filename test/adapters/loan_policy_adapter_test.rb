require "test_helper"

class LoanPolicyAdapterTest < ActiveSupport::TestCase
  test ".for returns StaticLoanPolicyAdapter" do
    adapter = LoanPolicyAdapter.for
    assert_instance_of StaticLoanPolicyAdapter, adapter
  end
end
