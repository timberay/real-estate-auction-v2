class Identity < ApplicationRecord
  belongs_to :user

  # email_verified: nil means the provider did not report verification status; do not treat as false.
  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
end
