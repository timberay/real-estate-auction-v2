module Auth
  class KakaoAdapter
    PROVIDER = "kakao".freeze

    def initialize(auth_hash)
      @auth_hash = auth_hash
    end

    def to_profile
      ProviderProfile.new(
        provider: PROVIDER,
        uid: @auth_hash["uid"].to_s,
        email: @auth_hash.dig("info", "email"),
        name: @auth_hash.dig("info", "name"),
        avatar_url: @auth_hash.dig("info", "image"),
        raw_info: @auth_hash.dig("extra", "raw_info").to_h
      )
    end
  end
end
