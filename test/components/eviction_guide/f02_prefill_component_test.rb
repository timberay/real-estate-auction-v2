require "test_helper"

module EvictionGuide
  class F02PrefillComponentTest < ViewComponent::TestCase
    setup do
      @simulation = EvictionSimulation.new(property_id: 1)
    end

    test "renders analyzed header when prefill_data has fields" do
      render_inline(F02PrefillComponent.new(
        prefill_data: { has_opposing_tenant: true },
        simulation: @simulation
      ))

      assert_selector "h3", text: "AI 분석 결과 확인"
      assert_text "물건분석(F02)에서 가져온 결과"
    end

    test "renders unanalyzed header and guidance when prefill_data is empty" do
      render_inline(F02PrefillComponent.new(
        prefill_data: {},
        simulation: @simulation
      ))

      assert_selector "h3", text: "점유자 유형 직접 선택"
      assert_text "AI 분석 결과가 없습니다"
      assert_no_text "물건분석(F02)에서 가져온 결과"
    end
  end
end
