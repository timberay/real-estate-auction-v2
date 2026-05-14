require "application_system_test_case"

# T1.5 — DSR 한도 경고 배너의 노출/숨김 회귀 가드.
class ProfitCalculatorDsrWarningTest < ApplicationSystemTestCase
  setup do
    @property = properties(:safe_apartment)
    @user = users(:budget_user)
    UserProperty.find_or_create_by!(user: @user, property: @property)
    sign_in_as(@user)
  end

  test "warning banner stays hidden when DSR inputs are empty" do
    visit property_inspections_grade_path(@property)

    fill_in_sale_price("12억")
    # banner is in the DOM but always hidden
    assert_selector "[data-profit-calculator-target='dsrWarning']", visible: :hidden
  end

  test "warning banner appears when bid drives DSR above 40%" do
    # 연봉 1,200만원 (저소득) — default bid 5.6억 × 0.7 = 3.92억 대출 →
    # 월 약 198만원, 연 23.8백만 → DSR 198% → breached.
    @user.budget_setting.update!(annual_income: 1200, existing_debt_monthly: 0)
    visit property_inspections_grade_path(@property)

    # Sale price 입력으로 result area 표시 + calculate 트리거
    fill_in_sale_price("12억")

    within "[data-profit-calculator-target='dsrWarning']" do
      assert_text "한도 초과"
      assert_text "DSR"
    end
  end

  test "warning banner hides when bid keeps DSR under threshold" do
    # 연봉 1.2억, 입찰가 5,000만원 × 0.7 = 3,500만원 대출 → DSR ~1.6% → 안 breached
    @user.budget_setting.update!(annual_income: 12000, existing_debt_monthly: 0)
    visit property_inspections_grade_path(@property)

    fill_in_sale_price("12억")
    # min_bid 슬라이더는 default = min_bid_price (5,600만원). DSR <40%.
    assert_selector "[data-profit-calculator-target='dsrWarning']", visible: :hidden
  end

  private

  def fill_in_sale_price(text)
    find("[data-profit-calculator-target='saleDisplay']").set(text)
    find("[data-profit-calculator-target='saleDisplay']").send_keys(:tab)
  end
end
