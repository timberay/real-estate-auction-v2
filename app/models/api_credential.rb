class ApiCredential < ApplicationRecord
  PROVIDERS = {
    court_auction: {
      name: "Court Auction (courtauction.go.kr)",
      name_ko: "법원경매정보",
      requires_key: false,
      requires_consent: true,
      category: :auction,
      description_ko: "법원경매정보 사이트에서 경매 사건정보를 수집합니다."
    }
  }.freeze

  belongs_to :user

  encrypts :api_key, deterministic: false
  encrypts :api_secret, deterministic: false

  validates :provider_name, presence: true,
    inclusion: { in: PROVIDERS.keys.map(&:to_s) },
    uniqueness: { scope: :user_id }

  def self.for_provider(name)
    find_by(provider_name: name.to_s)
  end

  scope :active, -> { where(enabled: true) }

  def verified?
    last_verified_at.present?
  end

  def configured?
    provider_config = PROVIDERS[provider_name.to_sym]
    if provider_config[:requires_key]
      api_key.present? && enabled?
    else
      enabled?
    end
  end
end
