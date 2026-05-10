require "test_helper"

class ApiCredentialTest < ActiveSupport::TestCase
  setup do
    @user = users(:guest)
  end

  test "PROVIDERS constant contains expected providers" do
    expected_keys = %i[court_auction]
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
    assert_includes cred.errors[:provider_name], "을(를) 입력해 주세요"
  end

  test "validates provider_name inclusion" do
    cred = ApiCredential.new(user: @user, provider_name: "invalid_provider")
    assert_not cred.valid?
    assert_includes cred.errors[:provider_name], "은(는) 허용된 값이 아닙니다"
  end

  test "validates provider_name uniqueness per user" do
    ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: true)
    duplicate = ApiCredential.new(user: @user, provider_name: "court_auction", enabled: true)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:provider_name], "은(는) 이미 사용 중입니다"
  end

  test "encrypts api_key" do
    cred = ApiCredential.create!(user: @user, provider_name: "court_auction", api_key: "my-secret-key", enabled: true)
    raw_value = ApiCredential.connection.select_value(
      "SELECT api_key FROM api_credentials WHERE id = #{cred.id}"
    )
    assert_not_equal "my-secret-key", raw_value
    assert_equal "my-secret-key", cred.reload.api_key
  end

  test "encrypts api_secret" do
    cred = ApiCredential.create!(user: @user, provider_name: "court_auction", api_key: "key", api_secret: "secret-123", enabled: true)
    raw_value = ApiCredential.connection.select_value(
      "SELECT api_secret FROM api_credentials WHERE id = #{cred.id}"
    )
    assert_not_equal "secret-123", raw_value
    assert_equal "secret-123", cred.reload.api_secret
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
    cred = ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: true)
    assert_equal cred, @user.api_credentials.for_provider(:court_auction)
  end

  test "for_provider scope returns nil when no match" do
    assert_nil @user.api_credentials.for_provider(:court_auction)
  end

  test "active scope excludes disabled credentials" do
    ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: true)
    assert_equal 1, @user.api_credentials.active.count
  end
end
