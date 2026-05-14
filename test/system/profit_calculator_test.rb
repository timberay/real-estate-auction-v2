require "application_system_test_case"

# T1.2 — verify the server-driven CGT matrix flows through to the rendered
# profit calculator. Catches regressions where the Stimulus matrix lookup
# silently falls back to CGT_FALLBACK_RATE.
class ProfitCalculatorTest < ApplicationSystemTestCase
  setup do
    @property = properties(:safe_apartment)
    @user = users(:budget_user)
    UserProperty.find_or_create_by!(user: @user, property: @property)
    sign_in_as(@user)
  end

  test "single_home + over_2y shows 0% CGT (1세대1주택 비과세 가정)" do
    visit property_inspections_grade_path(@property)

    # Sale price input gates the result area.
    fill_in_sale_price("12억")
    choose "1주택"
    choose "2년 이상"

    within "[data-controller='profit-calculator']" do
      assert_selector "[data-profit-calculator-target='rowCgtNote']", text: "추정 ~0%"
    end
  end

  test "multi_home_2 + over_2y in non-regulated region shows 24% CGT (한시 유예)" do
    # @budget defaults to 제주 (non-regulated) per fixture
    visit property_inspections_grade_path(@property)

    fill_in_sale_price("12억")
    choose "2주택"
    choose "2년 이상"

    within "[data-controller='profit-calculator']" do
      assert_selector "[data-profit-calculator-target='rowCgtNote']", text: "추정 ~24%"
    end
  end

  test "under_1y shows 70% CGT regardless of tier" do
    visit property_inspections_grade_path(@property)

    fill_in_sale_price("12억")
    choose "3주택 이상"
    choose "1년 미만"

    within "[data-controller='profit-calculator']" do
      assert_selector "[data-profit-calculator-target='rowCgtNote']", text: "추정 ~70%"
    end
  end

  private

  # Triggers calculate() via input + blur events so the result area becomes
  # visible. Capybara's fill_in fires both implicitly.
  def fill_in_sale_price(text)
    find("[data-profit-calculator-target='saleDisplay']").set(text)
    find("[data-profit-calculator-target='saleDisplay']").send_keys(:tab)
  end
end
