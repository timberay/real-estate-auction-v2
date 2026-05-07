require "test_helper"

class Inspections::ResolutionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:risky_villa)
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership
    UserProperty.find_or_create_by!(user: @user, property: @property)
  end

  test "AI source updates resolvable=true and resolution_note inline" do
    result = inspection_results(:risky_villa_rights_003)
    result.update!(source_type: :ai, has_risk: true, resolvable: nil, resolution_note: nil)

    patch property_inspections_result_resolution_url(@property, result),
      params: { resolvable: "true", resolution_note: "보증금 인수 가능" },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    result.reload
    assert_equal true, result.resolvable
    assert_equal "보증금 인수 가능", result.resolution_note
    assert_equal "ai", result.source_type
  end

  test "auto source also accepts resolvable updates" do
    result = inspection_results(:risky_villa_rights_003)
    result.update!(source_type: :auto, has_risk: true, resolvable: nil)

    patch property_inspections_result_resolution_url(@property, result),
      params: { resolvable: "false", resolution_note: "처리 불가" },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    result.reload
    assert_equal false, result.resolvable
    assert_equal "처리 불가", result.resolution_note
  end

  test "responds with turbo_stream content type" do
    result = inspection_results(:risky_villa_rights_003)
    result.update!(source_type: :ai, has_risk: true, resolvable: nil)

    patch property_inspections_result_resolution_url(@property, result),
      params: { resolvable: "true" },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    assert_match(/turbo-stream/, @response.content_type)
  end

  test "rejects when result does not belong to current user" do
    other_user = users(:guest_two)
    other_result = inspection_results(:risky_villa_rights_003)
    other_result.update!(user: other_user, has_risk: true, source_type: :ai)

    patch property_inspections_result_resolution_url(@property, other_result),
      params: { resolvable: "true" }

    assert_response :not_found
  end

  test "rejects when result has no risk" do
    result = inspection_results(:safe_apartment_rights_002)
    UserProperty.find_or_create_by!(user: @user, property: result.property)

    patch property_inspections_result_resolution_url(result.property, result),
      params: { resolvable: "true" },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
  end

  test "rejects when source is manual (use unified form instead)" do
    result = inspection_results(:manual_risk)

    patch property_inspections_result_resolution_url(result.property, result),
      params: { resolvable: "true" },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :unprocessable_entity
  end
end
