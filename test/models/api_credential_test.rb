require "test_helper"

class ApiCredentialTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
  end

  test "PROVIDERS constant contains expected providers" do
    expected_keys = %i[court_auction data_go_kr tilko codef iros hyphen]
    assert_equal expected_keys.sort, ApiCredential::PROVIDERS.keys.sort
  end

  test "each provider has required metadata" do
    ApiCredential::PROVIDERS.each do |key, config|
      assert config[:name].present?, "#{key} missing :name"
      assert config[:name_ko].present?, "#{key} missing :name_ko"
      assert_includes [ true, false ], config[:requires_key], "#{key} missing :requires_key"
      assert config[:category].present?, "#{key} missing :category"
    end
  end

  test "validates provider_name presence" do
    cred = ApiCredential.new(user: @user, provider_name: nil)
    assert_not cred.valid?
    assert_includes cred.errors[:provider_name], "can't be blank"
  end

  test "validates provider_name inclusion" do
    cred = ApiCredential.new(user: @user, provider_name: "invalid_provider")
    assert_not cred.valid?
    assert_includes cred.errors[:provider_name], "is not included in the list"
  end

  test "validates provider_name uniqueness per user" do
    ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "key-123")
    duplicate = ApiCredential.new(user: @user, provider_name: "data_go_kr", api_key: "key-456")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:provider_name], "has already been taken"
  end

  test "encrypts api_key" do
    cred = ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "my-secret-key")
    raw_value = ApiCredential.connection.select_value(
      "SELECT api_key FROM api_credentials WHERE id = #{cred.id}"
    )
    assert_not_equal "my-secret-key", raw_value
    assert_equal "my-secret-key", cred.reload.api_key
  end

  test "encrypts api_secret" do
    cred = ApiCredential.create!(user: @user, provider_name: "tilko", api_key: "key", api_secret: "secret-123")
    raw_value = ApiCredential.connection.select_value(
      "SELECT api_secret FROM api_credentials WHERE id = #{cred.id}"
    )
    assert_not_equal "secret-123", raw_value
    assert_equal "secret-123", cred.reload.api_secret
  end

  test "configured? returns true for key-based provider with key and enabled" do
    cred = ApiCredential.new(provider_name: "data_go_kr", api_key: "key-123", enabled: true)
    assert cred.configured?
  end

  test "configured? returns false for key-based provider without key" do
    cred = ApiCredential.new(provider_name: "data_go_kr", api_key: nil, enabled: true)
    assert_not cred.configured?
  end

  test "configured? returns false for disabled provider" do
    cred = ApiCredential.new(provider_name: "data_go_kr", api_key: "key-123", enabled: false)
    assert_not cred.configured?
  end

  test "configured? returns true for consent-only provider when enabled" do
    cred = ApiCredential.new(provider_name: "court_auction", api_key: nil, enabled: true)
    assert cred.configured?
  end

  test "configured? returns false for consent-only provider when disabled" do
    cred = ApiCredential.new(provider_name: "court_auction", api_key: nil, enabled: false)
    assert_not cred.configured?
  end

  test "verified? returns true when last_verified_at is present" do
    cred = ApiCredential.new(last_verified_at: 1.day.ago)
    assert cred.verified?
  end

  test "verified? returns false when last_verified_at is nil" do
    cred = ApiCredential.new(last_verified_at: nil)
    assert_not cred.verified?
  end

  test "for_provider scope returns matching credential" do
    cred = ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "key-123")
    assert_equal cred, @user.api_credentials.for_provider(:data_go_kr)
  end

  test "for_provider scope returns nil when no match" do
    assert_nil @user.api_credentials.for_provider(:tilko)
  end

  test "active scope excludes disabled credentials" do
    ApiCredential.create!(user: @user, provider_name: "data_go_kr", api_key: "key", enabled: false)
    assert_empty @user.api_credentials.active
  end
end
