require "test_helper"

# Locale + timezone defaults that the app relies on for user-facing copy
# and date/time math (e.g., 매각기일 D-day calculation must use KST).
class ApplicationConfigTest < ActiveSupport::TestCase
  test "default locale is Korean" do
    assert_equal :ko, I18n.default_locale
  end

  test "default time zone is Asia/Seoul" do
    assert_equal "Asia/Seoul", Rails.application.config.time_zone
    assert_equal "Asia/Seoul", Time.zone.name
  end
end
