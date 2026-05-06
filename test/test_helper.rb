ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"

# Allow localhost connections for Ollama tests, block all others
WebMock.disable_net_connect!(allow_localhost: true)

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    setup do
      Rails.cache.clear if Rails.cache.respond_to?(:clear)
    end

    def mock_omniauth(provider, uid:, email: nil, name: "Test User", avatar: nil, email_verified: nil)
      info = { "email" => email, "name" => name, "image" => avatar }
      info["email_verified"] = email_verified if provider.to_sym == :google_oauth2

      raw_info =
        case provider.to_sym
        when :kakao then { "kakao_account" => { "is_email_verified" => email_verified } }
        when :naver then { "response" => { "email_verified" => email_verified } }
        else {}
        end

      OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
        "provider" => provider.to_s,
        "uid"      => uid.to_s,
        "info"     => info,
        "extra"    => { "raw_info" => raw_info }
      )
    end

    teardown do
      OmniAuth.config.mock_auth.clear
    end
  end
end

module ActionDispatch
  class IntegrationTest
    # After a session-establishing GET, move all fixture-guest-owned rows to the
    # per-session guest so fixture-based setup still reaches current_user.
    # Returns the session user.
    def inherit_fixture_guest_ownership
      fixture_guest = users(:guest)
      session_user = User.find(session[:user_id])
      return session_user if fixture_guest.id == session_user.id

      [
        UserProperty, InspectionResult, RightsAnalysisReport,
        LlmAnalysisLog, BudgetSetting, SearchResult, ApiCredential
      ].each do |model|
        model.where(user: fixture_guest).update_all(user_id: session_user.id)
      end
      session_user
    end
  end
end
