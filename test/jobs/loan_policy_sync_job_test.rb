require "test_helper"

class LoanPolicySyncJobTest < ActiveSupport::TestCase
  test "performs loan policy sync" do
    LoanPolicy.delete_all
    LoanPolicySyncJob.perform_now
    assert LoanPolicy.count > 0
  end
end
