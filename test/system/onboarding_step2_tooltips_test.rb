require "application_system_test_case"

# B16 / audit B-3 — every reserve-fund cost item on step2 must carry a "?"
# tooltip explaining WHY the cost matters (not what it is — that's the hint).
class OnboardingStep2TooltipsTest < ApplicationSystemTestCase
  setup do
    visit root_path  # establish guest session
    visit start_onboarding_path
    fill_in "available_cash_display", with: "5000"
    find("button[type='submit']").click
    # Now on step2. C18 (T4.3) wraps the 5 cost inputs in a <details> closed
    # by default so the auto-summary leads. Open it so the tooltip elements
    # are visible to Capybara.
    find("summary", text: /예비비 항목 직접 조정하기/).click
  end

  EXPECTED_TOOLTIPS = {
    "수선비"     => "낙찰 후 집을 사용 가능한 상태로 만드는 데 드는 평균 비용",
    "취득세"     => "낙찰 가격의 1.1~3.5%를 등기할 때 세금으로 납부",
    "법무사비"   => "등기를 대신 처리해 주는 법무사 수수료 (선택)",
    "이사비"     => "기존 점유자가 나가는 데 드는 합의금 (명도비)",
    "미납 관리비" => "이전 소유자가 안 낸 관리비를 낙찰자가 부담하는 경우"
  }.freeze

  test "step2 renders tooltip controller for each reserve-fund cost item" do
    EXPECTED_TOOLTIPS.each_value do |copy|
      assert_selector "[data-controller='tooltip'][data-tooltip-content-value='#{copy}']"
    end
  end

  test "each reserve-fund tooltip is paired with its label" do
    EXPECTED_TOOLTIPS.each do |label, copy|
      tooltip = find("[data-tooltip-content-value='#{copy}']")
      assert_includes tooltip.text, label,
        "expected tooltip for '#{label}' to surface its label, got: #{tooltip.text.inspect}"
    end
  end
end
