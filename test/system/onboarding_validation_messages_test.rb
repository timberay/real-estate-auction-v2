require "application_system_test_case"

# B21 / B-13: Validation errors on onboarding forms must read in Korean
# (Korean attribute name + Korean message) AND surface an actionable hint
# explaining what to do.
#
# Browser-driven coverage of the rendered error block is in the system test
# below; deeper field-level scenarios (which fight Stimulus controllers in a
# headless browser) are covered by the controller test in
# test/controllers/onboardings_validation_messages_test.rb.
class OnboardingValidationMessagesTest < ApplicationSystemTestCase
  test "step1 surfaces Korean error and hint when controller adds available_cash error" do
    # Drive a real form submission with the JS hidden field bypassed.
    visit start_onboarding_path
    page.execute_script(<<~JS)
      document.querySelector("input[name='budget_setting[available_cash]']").value = "-100";
    JS
    find("button[type='submit']").click

    # Korean error: attribute name + validator message.
    assert_text "쓸 수 있는 현금"
    assert_text "0보다 커야 합니다"

    # Actionable hint tells the user what input is acceptable.
    assert_text "만원 단위"
  end
end
