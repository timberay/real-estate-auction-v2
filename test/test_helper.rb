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
