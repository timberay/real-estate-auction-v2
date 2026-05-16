require "test_helper"

class Settings::DataSourcesControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url # bootstrap a guest session (lazy guest creation)
  end

  test "show displays all providers" do
    get settings_data_sources_path
    assert_response :success
  end

  # F-02: API 키 입력란은 평문(text)이 아니라 password 타입이어야 한다.
  # 현재 PROVIDERS 에는 requires_key: true 항목이 없으므로 테스트 중에만
  # 임시 provider 를 끼워넣어 password 렌더링을 검증한다.
  test "show renders API key inputs as password fields (not plain text)" do
    saved = ApiCredential::PROVIDERS
    test_providers = saved.merge(
      test_key_provider: {
        name: "Test Key Provider",
        name_ko: "테스트 키 공급자",
        requires_key: true,
        requires_consent: false,
        category: :test,
        description_ko: "F-02 검증용"
      }
    ).freeze
    ApiCredential.send(:remove_const, :PROVIDERS)
    ApiCredential.const_set(:PROVIDERS, test_providers)

    begin
      get settings_data_sources_path
      assert_response :success
      assert_select 'input[name="api_credential[api_key]"][type="password"]',
        minimum: 1,
        message: "API key input must be masked (password type) to prevent shoulder-surfing"
      assert_select 'input[name="api_credential[api_key]"][type="text"]', false,
        "API key must not be rendered as plain text input"
    ensure
      ApiCredential.send(:remove_const, :PROVIDERS)
      ApiCredential.const_set(:PROVIDERS, saved)
    end
  end
end
