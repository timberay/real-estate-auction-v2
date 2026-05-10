require "test_helper"

class InspectionTabsComponentTest < ViewComponent::TestCase
  setup do
    @property = properties(:safe_apartment)
    @user = users(:guest)
  end

  def render_component(active_tab: "rights_analysis")
    render_inline(InspectionTabsComponent.new(property: @property, user: @user, active_tab: active_tab))
  end

  test "renders desktop nav hidden on mobile (sm:block)" do
    render_component

    nav = page.find("#inspection-tabs-nav")
    assert_includes nav[:class], "hidden"
    assert_includes nav[:class], "sm:block"
  end

  test "renders mobile dropdown wrapper visible only on mobile (sm:hidden)" do
    render_component

    wrapper = page.find("[data-controller='tab-select']")
    assert_includes wrapper[:class], "sm:hidden"
  end

  test "mobile dropdown lists every tab in TAB_CONFIG" do
    render_component

    select = page.find("[data-controller='tab-select'] select")
    options = select.all("option")
    assert_equal InspectionTabsComponent::TAB_CONFIG.size, options.size
    InspectionTabsComponent::TAB_CONFIG.each do |tab|
      assert(options.any? { |o| o.text.include?(tab[:label]) },
        "expected mobile dropdown to include label '#{tab[:label]}'")
    end
  end

  test "mobile dropdown marks the active tab as selected" do
    render_component(active_tab: "profit_analysis")

    selected = page.find("[data-controller='tab-select'] select option[selected]")
    assert_includes selected.text, "수익분석"
  end

  test "mobile dropdown wires a change action to the Stimulus controller" do
    render_component

    select = page.find("[data-controller='tab-select'] select")
    assert_equal "change->tab-select#navigate", select["data-action"]
  end

  test "mobile dropdown carries an aria-label so screen readers announce it" do
    render_component

    select = page.find("[data-controller='tab-select'] select")
    assert select["aria-label"].present?, "expected aria-label on mobile tab select"
  end

  test "mobile dropdown shows checked/total progress when total > 0" do
    render_component

    # Fixture-driven: at least one tab in safe_apartment has results, so a
    # progress fragment like "(N/M)" should appear in some option.
    select = page.find("[data-controller='tab-select'] select")
    assert_match(/\(\d+\/\d+\)/, select.text)
  end
end
