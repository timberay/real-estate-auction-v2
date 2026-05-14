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
  KNOWN_VIOLATIONS = [].freeze

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
