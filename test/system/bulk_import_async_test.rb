require "application_system_test_case"

# T3.6 — verify the bulk-import POST returns immediately with a progress
# placeholder rather than blocking on synchronous case searches. The job
# itself is unit-tested in test/jobs/property_import_job_test.rb; this
# system test proves the controller no longer blocks the request.
class BulkImportAsyncTest < ApplicationSystemTestCase
  setup do
    @user = users(:guest)
    sign_in_as(@user)
  end

  test "valid input shows progress placeholder immediately after submit" do
    visit bulk_import_properties_url
    assert_no_selector "[data-testid='bulk-import-progress']"

    fill_in "bulk_input", with: "제주지방법원,2022타경564\n제주지방법원,2025타경5678"
    click_button "한 번에 추가하기"

    assert_selector "[data-testid='bulk-import-progress']", text: "처리 중"
    assert_selector "ul[id^='bulk_import_'][id$='_rows']", visible: :all
  end

  test "50-row paste returns under 5s (no synchronous block)" do
    lines = (1..50).map { |i| "제주지방법원,2026타경#{i.to_s.rjust(4, '0')}" }
    visit bulk_import_properties_url
    fill_in "bulk_input", with: lines.join("\n")

    started = Time.current
    click_button "한 번에 추가하기"
    elapsed = Time.current - started

    assert_operator elapsed, :<, 5,
      "expected sub-5s response for 50-row submission, got #{elapsed.round(2)}s"
    assert_selector "[data-testid='bulk-import-progress']", text: "처리 중"
  end

  test "empty input re-renders form without progress placeholder" do
    visit bulk_import_properties_url
    click_button "한 번에 추가하기"

    assert_no_selector "[data-testid='bulk-import-progress']"
    assert_field "bulk_input"
  end
end
