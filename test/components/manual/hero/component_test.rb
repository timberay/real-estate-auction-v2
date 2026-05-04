# frozen_string_literal: true

require "test_helper"

module Manual
  module Hero
    class ComponentTest < ViewComponent::TestCase
      setup do
        @original_locale = I18n.locale
        I18n.locale = :ko
      end

      teardown { I18n.locale = @original_locale }

      test "renders headline, subhead, and tagline" do
        render_inline(Manual::Hero::Component.new)

        assert_text "경매 초보의 워크북"
        assert_text "낙찰 전 89개 체크리스트, 낙찰 후 명도 시뮬레이터"
        assert_text "정보를 보여드리는 게 아니라, 직접 분석하는 능력을 길러드립니다."
      end
    end
  end
end
