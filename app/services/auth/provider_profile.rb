module Auth
  ProviderProfile = Struct.new(
    :provider, :uid, :email, :email_verified, :name, :avatar_url,
    keyword_init: true
  )
end
