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

  # T1.2-F-B — 거주요건 toggle is hidden unless single_home + over_2y is the
  # active selection, then unchecking it falls back to homeless's over_2y rate.
  test "residency row appears for single_home + over_2y and toggling falls back to 6%" do
    visit property_inspections_grade_path(@property)

    fill_in_sale_price("8억")
    choose "1주택"
    choose "2년 이상"

    within "[data-controller='profit-calculator']" do
      # Default state: residency met → 0%
      assert_selector "[data-profit-calculator-target='rowCgtNote']", text: "추정 ~0%"
      # Toggle should be visible (not .hidden) for this combination
      residency_row = find("[data-profit-calculator-target='residencyRow']", visible: :all)
      refute residency_row[:class].include?("hidden"),
        "residency row should be visible for single_home + over_2y"

      # Uncheck the residency checkbox → fallback to 무주택 over_2y (0.06)
      uncheck "거주요건 충족 (1주택 비과세 적용)"
      assert_selector "[data-profit-calculator-target='rowCgtNote']", text: "추정 ~6%"
    end
  end

  test "residency row stays hidden for non single_home + over_2y combinations" do
    visit property_inspections_grade_path(@property)

    fill_in_sale_price("8억")
    choose "2주택"
    choose "2년 이상"

    within "[data-controller='profit-calculator']" do
      residency_row = find("[data-profit-calculator-target='residencyRow']", visible: :all)
      assert residency_row[:class].include?("hidden"),
        "residency row should NOT be visible for multi_home_2 + over_2y"
    end
  end

  test "12억 초과 advisory banner appears for single_home + over_2y + residency met" do
    visit property_inspections_grade_path(@property)

    fill_in_sale_price("15억")
    choose "1주택"
    choose "2년 이상"

    within "[data-controller='profit-calculator']" do
      banner = find("[data-profit-calculator-target='highValueWarning']", visible: :all)
      refute banner[:class].include?("hidden"),
        "12억 초과 banner should be visible for sale > 12억 + 1주택 + 2년+"
      assert_text "양도가액 12억 초과 — 1주택 비과세 부분 적용 케이스"
    end
  end

  test "12억 초과 banner stays hidden when sale price is at or below 12억" do
    visit property_inspections_grade_path(@property)

    fill_in_sale_price("12억")
    choose "1주택"
    choose "2년 이상"

    within "[data-controller='profit-calculator']" do
      banner = find("[data-profit-calculator-target='highValueWarning']", visible: :all)
      assert banner[:class].include?("hidden"),
        "12억 초과 banner should remain hidden at exactly 12억"
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
