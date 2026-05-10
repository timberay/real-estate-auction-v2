require "application_system_test_case"

class EvictionSimulatorDefaultTabTest < ApplicationSystemTestCase
  test "defaults to manual entry tab when user has no analyzed properties" do
    sign_in_as users(:budget_user)
    visit eviction_guide_simulator_path

    manual_tab = find("button", text: "직접 입력으로 시뮬레이션")
    property_tab = find("button", text: "내 물건으로 시뮬레이션")

    # Manual tab should be active (blue underline + blue text)
    assert_includes manual_tab[:class], "border-blue-500"
    assert_includes manual_tab[:class], "text-blue-600"

    # Property tab should be inactive
    assert_not_includes property_tab[:class], "border-blue-500"
    assert_includes property_tab[:class], "border-transparent"

    # Manual panel should be visible (start the simulation button shown)
    assert_selector "button", text: "직접 입력으로 시작"

    # Property panel should be hidden on initial render
    assert_selector "[data-simulator-target='propertyPanel'].hidden", visible: :all
  end

  test "defaults to property tab when user has analyzed properties" do
    user = users(:guest)
    sign_in_as user
    visit eviction_guide_simulator_path

    property_tab = find("button", text: "내 물건으로 시뮬레이션")
    manual_tab = find("button", text: "직접 입력으로 시뮬레이션")

    # Property tab should be active
    assert_includes property_tab[:class], "border-blue-500"
    assert_includes property_tab[:class], "text-blue-600"

    # Manual tab should be inactive
    assert_not_includes manual_tab[:class], "border-blue-500"
    assert_includes manual_tab[:class], "border-transparent"

    # Manual panel should be hidden on initial render
    assert_selector "[data-simulator-target='manualPanel'].hidden", visible: :all
  end
end
