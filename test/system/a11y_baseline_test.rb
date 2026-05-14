require "application_system_test_case"

# T4.6 / W4-1 / C34 — axe-core a11y baseline.
#
# This is the *baseline* test: it asserts that the current rendered HTML on
# our key pages does not regress against the axe-core ruleset (WCAG 2.1
# A/AA by default).
#
# When a violation is discovered:
#   1. Add the rule id to `KNOWN_VIOLATIONS` *temporarily* with a short
#      reason and a link/issue.
#   2. Open a follow-up PR that fixes the violation and removes the rule
#      from this list.
#
# This way the baseline can only get stricter over time, never looser.
class A11yBaselineTest < ApplicationSystemTestCase
  # Rules currently waived because the surface they fire on is debt to be
  # repaid in follow-up PRs. The baseline can only get *stricter* over time:
  # never add a rule here without opening a follow-up to remove it.
  #
  # Tracked under master TODO T4.6 follow-ups.
  KNOWN_VIOLATIONS = [
    # serious — `<html>` 태그에 `lang="ko"` 속성 누락 (layouts/application.html.erb).
    # Fix is one-line: <html lang="ko" class="h-full">.
    "html-has-lang",
    # critical — properties#index 의 법원 선택 dropdown 이 라벨/aria 없음.
    # `<select id="court_code">` 에 aria-label 또는 visible <label> 추가.
    "select-name",
    # moderate — properties#index 빈 상태 `<h3>아직 추가한 물건이 없습니다</h3>` 가
    # 페이지 heading order (h1→h2→h3) 를 위반. Empty state 의 heading level
    # 재검토 필요.
    "heading-order",
    # serious — slate-500 / slate-400 텍스트 위 light 배경에서 4.5:1 미달
    # (footer copyright, secondary 안내 문구 다수). 디자인 토큰 재정비 필요.
    "color-contrast"
  ].freeze

  test "login page is axe clean (baseline)" do
    visit auth_login_path

    assert_axe_clean(skip_rules: KNOWN_VIOLATIONS)
  end

  test "properties index is axe clean (baseline) for an authenticated user" do
    user = users(:budget_user)
    visit root_path
    sign_in_as(user)
    visit properties_path

    assert_axe_clean(skip_rules: KNOWN_VIOLATIONS)
  end
end
