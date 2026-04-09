require "test_helper"
require "test_helpers/data_provider_test_helper"

class CredentialResolverTest < ActiveSupport::TestCase
  include DataProviderTestHelper

  setup do
    @user = users(:guest)  # NOTE: fixture name is :guest, not :default
  end

  # --- Tier 1: Mock mode ---

  test "returns mock when USE_MOCK is not false" do
    with_mock_mode do
      result = CredentialResolver.new(user: @user, provider_name: :data_go_kr).resolve
      assert_equal :mock, result[:adapter]
    end
  end

  test "returns mock when USE_MOCK is unset" do
    original = ENV.delete("USE_MOCK")
    result = CredentialResolver.new(user: @user, provider_name: :data_go_kr).resolve
    assert_equal :mock, result[:adapter]
  ensure
    ENV["USE_MOCK"] = original
  end

  # --- Tier 2: Credential check ---

  test "returns real with api_key when user has configured credential" do
    with_real_mode do
      create_credential(user: @user, provider: :data_go_kr, api_key: "my-key")
      result = CredentialResolver.new(user: @user, provider_name: :data_go_kr).resolve
      assert_equal :real, result[:adapter]
      assert_equal "my-key", result[:api_key]
      assert_equal :data_go_kr, result[:provider]
    end
  end

  test "returns real for consent-only provider when enabled" do
    with_real_mode do
      ApiCredential.create!(user: @user, provider_name: "court_auction", enabled: true)
      result = CredentialResolver.new(user: @user, provider_name: :court_auction).resolve
      assert_equal :real, result[:adapter]
      assert_equal :court_auction, result[:provider]
    end
  end

  test "skips disabled credentials and falls back to mock in development" do
    with_real_mode do
      create_credential(user: @user, provider: :data_go_kr, api_key: "my-key", enabled: false)
      result = CredentialResolver.new(user: @user, provider_name: :data_go_kr).resolve
      assert_equal :mock, result[:adapter]
    end
  end

  # --- Tier 3: No credential ---

  test "raises MissingCredentialError in production when no credential" do
    with_real_mode do
      resolver = CredentialResolver.new(user: @user, provider_name: :data_go_kr)
      assert_raises(DataProvider::MissingCredentialError) do
        resolver.instance_eval { def production? = true }
        resolver.resolve
      end
    end
  end

  test "raises ConsentRequiredError in production for consent-only provider" do
    with_real_mode do
      resolver = CredentialResolver.new(user: @user, provider_name: :court_auction)
      assert_raises(DataProvider::ConsentRequiredError) do
        resolver.instance_eval { def production? = true }
        resolver.resolve
      end
    end
  end

  test "returns mock in development when no credential" do
    with_real_mode do
      result = CredentialResolver.new(user: @user, provider_name: :data_go_kr).resolve
      assert_equal :mock, result[:adapter]
    end
  end

  # --- Category-aware resolution ---

  test "resolves by category when provider_name is nil" do
    with_real_mode do
      create_credential(user: @user, provider: :codef, api_key: "codef-key")
      result = CredentialResolver.new(user: @user, category: :registry).resolve
      assert_equal :real, result[:adapter]
      assert_equal :codef, result[:provider]
      assert_equal "codef-key", result[:api_key]
    end
  end

  test "category resolution prefers first configured credential" do
    with_real_mode do
      create_credential(user: @user, provider: :tilko, api_key: "tilko-key")
      create_credential(user: @user, provider: :codef, api_key: "codef-key")
      result = CredentialResolver.new(user: @user, category: :registry).resolve
      assert_equal :tilko, result[:provider]
    end
  end

  test "category resolution skips disabled providers" do
    with_real_mode do
      create_credential(user: @user, provider: :tilko, api_key: "tilko-key", enabled: false)
      create_credential(user: @user, provider: :codef, api_key: "codef-key")
      result = CredentialResolver.new(user: @user, category: :registry).resolve
      assert_equal :codef, result[:provider]
    end
  end

  # --- Argument validation ---

  test "raises ArgumentError when neither provider_name nor category given" do
    assert_raises(ArgumentError) do
      CredentialResolver.new(user: @user).resolve
    end
  end

  # --- Nil user ---

  test "returns mock when user is nil and mock mode" do
    with_mock_mode do
      result = CredentialResolver.new(user: nil, provider_name: :data_go_kr).resolve
      assert_equal :mock, result[:adapter]
    end
  end
end
