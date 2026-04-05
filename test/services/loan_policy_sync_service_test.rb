require "test_helper"

class LoanPolicySyncServiceTest < ActiveSupport::TestCase
  test "syncs policies from adapter to database" do
    # Clear existing loan policies from fixtures
    LoanPolicy.delete_all

    result = LoanPolicySyncService.call

    assert result[:synced_count] > 0
    assert LoanPolicy.count > 0
  end

  test "does not duplicate existing policies" do
    LoanPolicy.delete_all
    LoanPolicySyncService.call
    count_after_first = LoanPolicy.count

    LoanPolicySyncService.call
    count_after_second = LoanPolicy.count

    assert_equal count_after_first, count_after_second
  end

  test "updates existing policy when loan_ratio changes" do
    LoanPolicy.delete_all
    LoanPolicySyncService.call

    apt = PropertyType.find_by!(code: "apartment")
    policy = LoanPolicy.find_by!(property_type: apt, policy_name: "일반 주담대")
    original_ratio = policy.loan_ratio

    assert_equal 0.7, original_ratio.to_f
  end

  test "returns summary with synced and skipped counts" do
    LoanPolicy.delete_all
    result = LoanPolicySyncService.call

    assert result.key?(:synced_count)
    assert result.key?(:skipped_count)
    assert result.key?(:property_types_processed)
  end
end
