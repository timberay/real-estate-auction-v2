class CredentialVerificationJob < ApplicationJob
  queue_as :default
  limits_concurrency to: 1, key: ->(credential) { "verify_credential_#{credential.id}" }

  def perform(credential)
    return unless credential.persisted?

    # For now, mark as verified. Real verification will be added
    # when individual adapter specs are implemented.
    credential.update!(last_verified_at: Time.current)
  rescue ActiveRecord::RecordNotFound
    # Credential deleted between enqueue and execution — discard
  end
end
