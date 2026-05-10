require "test_helper"

class I18nLocaleTest < ActiveSupport::TestCase
  test "default locale is Korean" do
    assert_equal :ko, I18n.default_locale
  end

  test "Korean locale is loaded" do
    assert_includes I18n.available_locales, :ko
  end

  test "Korean error messages translate Rails defaults" do
    assert_equal "을(를) 입력해 주세요", I18n.t("errors.messages.blank", locale: :ko)
    assert_equal "은(는) 0보다 커야 합니다", I18n.t("errors.messages.greater_than", count: 0, locale: :ko)
    assert_equal "은(는) 이미 사용 중입니다", I18n.t("errors.messages.taken", locale: :ko)
  end

  test "Korean attribute names cover budget_setting fields" do
    assert_equal "쓸 수 있는 현금",
                 I18n.t("activerecord.attributes.budget_setting.available_cash", locale: :ko)
    assert_equal "대출 비율",
                 I18n.t("activerecord.attributes.budget_setting.loan_ratio", locale: :ko)
  end
end
