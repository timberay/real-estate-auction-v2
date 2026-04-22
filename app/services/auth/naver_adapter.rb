module Auth
  class NaverAdapter
    PROVIDER = "naver".freeze

    def initialize(auth_hash)
      @auth_hash = auth_hash
    end

    def to_profile
      ProviderProfile.new(
        provider: PROVIDER,
        uid: @auth_hash["uid"].to_s,
        email: @auth_hash.dig("info", "email"),
        email_verified: nil,
        name: @auth_hash.dig("info", "name"),
        avatar_url: @auth_hash.dig("info", "image") ||
                    @auth_hash.dig("extra", "raw_info", "response", "profile_image")
      )
    end
  end
end
