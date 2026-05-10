require "application_system_test_case"

class ExtractionFailureRetryTest < ApplicationSystemTestCase
  include ActiveJob::TestHelper

  setup do
    @user = users(:guest)
    @property = Property.create!(case_number: "2026타경77001", court_name: "서울중앙지방법원")
    UserProperty.find_or_create_by!(user: @user, property: @property)

    # An inspection_result is required so property.analyzed? returns true
    # and the user is not redirected away from the rights_analysis tab.
    item = InspectionItem.where(tab: "rights_analysis").first ||
           InspectionItem.create!(code: "test-rights-001", category: "권리분석",
                                  tab: "rights_analysis", question: "테스트")
    InspectionResult.create!(user: @user, property: @property,
                             inspection_item: item, has_risk: nil, source_type: nil)

    RightsAnalysisReport.create!(
      user: @user,
      property: @property,
      analyzed_at: Time.current,
      report_data: {
        "analysis_status" => "extraction_failed",
        "failed_at" => Time.current.iso8601,
        "failure_reason" => "AI 응답에서 rights_analysis 필드를 찾지 못했습니다."
      }
    )
  end

  test "rights_analysis tab shows failure_reason and retry button when extraction failed" do
    visit root_path
    sign_in_as(@user)
    visit edit_property_inspections_tab_path(@property, tab_key: "rights_analysis")

    assert_text "분석에 실패했습니다"
    assert_text "AI 응답에서 rights_analysis 필드를 찾지 못했습니다"
    assert_selector "form[action='/properties/#{@property.id}/analyses/retry']"
    assert_button "재시도"
  end

  test "retry button enqueues PdfAnalysisJob for current user" do
    visit root_path
    sign_in_as(@user)
    visit edit_property_inspections_tab_path(@property, tab_key: "rights_analysis")

    # Use the block form so Capybara waits for the Turbo Stream response
    # (toast text "분석을 다시 시작했습니다") before asserting on the job queue.
    # Without this synchronization, CI can race the button submission and
    # observe an empty queue. See Properties::AnalysisRetriesController#create.
    assert_enqueued_jobs 1, only: PdfAnalysisJob do
      click_button "재시도"
      assert_text "분석을 다시 시작했습니다", wait: 5
    end

    enqueued_args = enqueued_jobs.find { |j| j[:job] == PdfAnalysisJob }[:args].first
    assert_equal @property.id, enqueued_args["property_id"]
    assert_equal @user.id, enqueued_args["user_id"]
  end
end
