require "test_helper"

module EvictionGuide
  class F02PrefillComponentTest < ViewComponent::TestCase
    setup do
      @simulation = EvictionSimulation.new(property_id: 1)
    end

    test "renders analyzed header when prefill_data has fields (C4)" do
      render_inline(F02PrefillComponent.new(
        prefill_data: { has_opposing_tenant: true },
        simulation: @simulation
      ))

      assert_selector "h3", text: "AI 분석 결과 확인"
      # C4: the internal module code "F02" is meaningless to users — surface
      # only that the data came from the AI analysis.
      assert_text "AI 분석 결과를 가져왔어요"
      assert_no_text "F02"
    end

    test "renders unanalyzed header and guidance when prefill_data is empty (C4)" do
      render_inline(F02PrefillComponent.new(
        prefill_data: {},
        simulation: @simulation
      ))

      assert_selector "h3", text: "점유자 유형 직접 선택"
      assert_text "AI 분석 결과가 없습니다"
      assert_no_text "F02"
    end
  end
end
