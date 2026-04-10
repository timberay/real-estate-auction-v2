require "test_helper"

class Inspection::PropertyDataAssemblerTest < ActiveSupport::TestCase
  test "assembles basic property info" do
    property = properties(:risky_villa)
    text = Inspection::PropertyDataAssembler.call(property)
    assert_includes text, "2026타경10002"
    assert_includes text, "빌라"
    assert_includes text, "경기도 수원시 영통구 200-2"
    assert_includes text, "300,000,000"
  end

  test "includes sale detail fields" do
    property = properties(:risky_villa)
    text = Inspection::PropertyDataAssembler.call(property)
    assert_includes text, "을구 1번 주택임차권등기"
    assert_includes text, "유치권 신고 있음"
  end

  test "marks missing fields as 정보 없음" do
    property = properties(:unanalyzed_officetel)
    text = Inspection::PropertyDataAssembler.call(property)
    assert_includes text, "(정보 없음)"
  end

  test "includes appraisal points when present" do
    property = properties(:safe_apartment)
    property.appraisal_points.create!(item_code: "00083001", content: "본건은 테스트 아파트입니다.")
    text = Inspection::PropertyDataAssembler.call(property)
    assert_includes text, "본건은 테스트 아파트입니다."
  end

  test "includes auction schedules when present" do
    property = properties(:safe_apartment)
    property.auction_schedules.create!(
      schedule_date: "2026-05-01", schedule_type: "매각기일",
      min_price: 560000000, result_code: "유찰"
    )
    text = Inspection::PropertyDataAssembler.call(property)
    assert_includes text, "2026-05-01"
    assert_includes text, "매각기일"
  end
end
