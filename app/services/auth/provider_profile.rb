module Auth
  ProviderProfile = Struct.new(
    :provider, :uid, :email, :name, :avatar_url, :raw_info,
    keyword_init: true
  )
end
