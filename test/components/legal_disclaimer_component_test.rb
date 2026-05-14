# frozen_string_literal: true

require "test_helper"

class LegalDisclaimerComponentTest < ViewComponent::TestCase
  test "default (full) variant renders the legal heading and full body" do
    rendered = render_inline(LegalDisclaimerComponent.new).to_s

    assert_match(/⚖️ 법적 고지/, rendered)
    assert_match(/대한민국 민사집행법의 배당 원칙/, rendered)
    assert_match(/법률 전문가의 자문/, rendered)
  end

  test "compact variant renders a short single-paragraph disclaimer" do
    rendered = render_inline(LegalDisclaimerComponent.new(compact: true)).to_s

    assert_match(/추정치/, rendered)
    assert_match(/투자 결정의 (최종 )?책임은 사용자에게/, rendered)
  end

  test "compact variant does NOT render the full legal body" do
    rendered = render_inline(LegalDisclaimerComponent.new(compact: true)).to_s

    refute_match(/⚖️ 법적 고지/, rendered)
    refute_match(/대한민국 민사집행법의 배당 원칙/, rendered)
  end

  test "default variant defaults to full (not compact)" do
    rendered = render_inline(LegalDisclaimerComponent.new).to_s

    # Full body markers
    assert_match(/⚖️ 법적 고지/, rendered)
  end

  test "default variant exposes role=note for assistive tech" do
    rendered = render_inline(LegalDisclaimerComponent.new).to_s

    assert_match(/role="note"/, rendered)
  end

  test "compact variant exposes role=note for assistive tech" do
    rendered = render_inline(LegalDisclaimerComponent.new(compact: true)).to_s

    assert_match(/role="note"/, rendered)
  end
end
