require "test_helper"

class CredentialVerificationJobTest < ActiveJob::TestCase
  setup do
    @user = users(:guest)
    @credential = ApiCredential.create!(
      user: @user,
      provider_name: "data_go_kr",
      api_key: "test-key"
    )
  end

  test "updates last_verified_at on success" do
    assert_nil @credential.last_verified_at
    CredentialVerificationJob.perform_now(@credential)
    @credential.reload
    assert_not_nil @credential.last_verified_at
  end

  test "does not crash when credential is deleted before execution" do
    @credential.destroy!
    assert_nothing_raised do
      CredentialVerificationJob.perform_now(@credential)
    end
  end
end
