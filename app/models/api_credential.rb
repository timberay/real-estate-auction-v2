class ApiCredential < ApplicationRecord
  PROVIDERS = {
    court_auction: {
      name: "Court Auction (courtauction.go.kr)",
      name_ko: "법원경매정보",
      requires_key: false,
      requires_consent: true,
      category: :auction,
      description_ko: "법원경매정보 사이트에서 경매 사건정보를 수집합니다."
    },
    data_go_kr: {
      name: "Public Data Portal (data.go.kr)",
      name_ko: "공공데이터포털 (건축물대장)",
      requires_key: true,
      requires_consent: false,
      category: :building_ledger,
      description_ko: "국토교통부 건축물대장정보 API를 조회합니다. data.go.kr에서 무료로 키를 발급받을 수 있습니다."
    },
    tilko: {
      name: "Tilko (tilko.net)",
      name_ko: "틸코블렛 (등기부등본)",
      requires_key: true,
      requires_consent: false,
      category: :registry,
      description_ko: "등기부등본을 조회합니다. 건당 과금이 발생합니다."
    },
    codef: {
      name: "Codef (codef.io)",
      name_ko: "코드에프 (등기부등본)",
      requires_key: true,
      requires_consent: false,
      category: :registry,
      description_ko: "등기부등본을 조회합니다. Tilko 대안으로 안정성이 높다는 평가가 있습니다."
    },
    iros: {
      name: "Registry Information Portal (iros.go.kr)",
      name_ko: "등기정보광장 (무료 미리보기)",
      requires_key: true,
      requires_consent: false,
      category: :registry_preview,
      description_ko: "등기 요약정보를 무료로 조회합니다 (하루 1,000건). 전문 등기부등본을 대체하지 않습니다."
    },
    hyphen: {
      name: "Hyphen (codef.io)",
      name_ko: "하이픈 (권리분석)",
      requires_key: true,
      requires_consent: false,
      category: :rights_analysis,
      description_ko: "권리분석 데이터를 조회합니다. 자체 분석 엔진의 대안으로 사용할 수 있습니다."
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
