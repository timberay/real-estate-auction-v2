require "test_helper"

class BidOpinionComponentTest < ViewComponent::TestCase
  test "never renders 입찰 권유 phrasing" do
    rendered = render_inline(BidOpinionComponent.new(risk_count: 0, opportunity_count: 5)).to_s
    refute_match(/입찰을 권/, rendered)
    refute_match(/입찰 검토 가능/, rendered)
    refute_match(/입찰 권합니다/, rendered)
    refute_match(/추천/, rendered)
  end

  test "shows risk count and 본인 판단 필요" do
    rendered = render_inline(BidOpinionComponent.new(risk_count: 3, opportunity_count: 1)).to_s
    assert_match(/위험 항목 3건/, rendered)
    assert_match(/기회 항목 1건/, rendered)
    assert_match(/본인 판단 필요/, rendered)
  end

  test "shows disclaimer about responsibility" do
    rendered = render_inline(BidOpinionComponent.new(risk_count: 0, opportunity_count: 0)).to_s
    assert_match(/입찰 권유가 아닙니다/, rendered)
    assert_match(/투자 결정의 (최종 )?책임은 사용자에게/, rendered)
  end

  test "responsibility statement is not duplicated between inline and compact disclaimer" do
    rendered = render_inline(BidOpinionComponent.new(risk_count: 0, opportunity_count: 0)).to_s

    refute_match(/모든 투자 결정의 책임은 사용자에게/, rendered)
    assert_equal 1, rendered.scan(/투자 결정의 (?:최종 )?책임은 사용자에게/).length
  end

  test "renders zero counts gracefully" do
    rendered = render_inline(BidOpinionComponent.new(risk_count: 0, opportunity_count: 0)).to_s
    assert_match(/위험 항목 0건/, rendered)
  end

  test "B28: renders 추정치 framing alongside responsibility statement" do
    rendered = render_inline(BidOpinionComponent.new(risk_count: 2, opportunity_count: 0)).to_s

    # Both halves of the spread-disclaimer should appear on every prediction surface
    assert_match(/추정치/, rendered)
    assert_match(/투자 결정의 (최종 )?책임은 사용자에게/, rendered)
  end
end
