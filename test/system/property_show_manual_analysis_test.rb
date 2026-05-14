require "application_system_test_case"

# B14 / E-43: AI 수동분석 등록 폼이 매물 상세에서 직접 사용 가능해야 한다.
# 별도 화면(/analyses/new)으로 이동하지 않고 detail page에서 프롬프트 복사 +
# JSON 결과 업로드까지 한 화면에서 끝낼 수 있는지 검증한다.
class PropertyShowManualAnalysisTest < ApplicationSystemTestCase
  setup do
    @property = properties(:safe_apartment)
    @user = users(:budget_user)
    UserProperty.find_or_create_by!(user: @user, property: @property)
    sign_in_as(@user)
  end

  test "property show page renders inline AI 수동분석 등록 form" do
    visit property_path(@property)

    # Heading hierarchy: CardComponent renders the section title as h3, so the
    # inline form sub-section title must be h4 (Follow-up #11).
    assert_selector "h4", text: "AI 수동분석 등록"
    # Disclosure component (parity with /analyses/new) is rendered above the form.
    assert_text "외부 LLM API로 전송되는 정보"
    # Disclosure heading is also bumped to h4 inside the property show CardComponent.
    assert_selector "h4", text: /외부 LLM API로 전송되는 정보/
    # Prompt copy button (analysis-tabs Stimulus target).
    assert_selector "button[data-analysis-tabs-target='copyButton']", text: "프롬프트 복사"
  end

  test "AI 분석 section does not nest CardComponent inside CardComponent (Follow-up #12)" do
    visit property_path(@property)

    # CardComponent has the signature container `rounded-lg bg-white ... border ... shadow-sm`.
    # If we ever wrap a CardComponent inside another, the inner shadow-sm container
    # would appear as a descendant of the outer one. Guard against that regression.
    nested_cards = page.evaluate_script(<<~JS)
      Array.from(document.querySelectorAll('.rounded-lg.bg-white.shadow-sm, .rounded-lg.dark\\\\:bg-slate-800.shadow-sm'))
        .filter(el => el.parentElement && el.parentElement.closest('.shadow-sm'))
        .length
    JS

    assert_equal 0, nested_cards,
      "CardComponent is rendered inside another CardComponent — restore flat layout (B20 stepper)."
  end

  test "property show page renders manual JSON upload form posting to /analyses/manual" do
    visit property_path(@property)

    # Both file and paste forms submit to manual_analyses_path.
    assert_selector "form[action='#{manual_analyses_path}']", minimum: 1
    assert_selector "input[type='file'][name='json_file']", visible: :all
    assert_selector "textarea[name='json_text']", visible: :all
  end

  test "property show page no longer shows 다시분석 button" do
    visit property_path(@property)

    # The standalone re-analysis link is replaced by the inline form.
    assert_no_link "다시분석"
    # 분석결과보기 still present.
    assert_link "분석결과보기"
  end
end
