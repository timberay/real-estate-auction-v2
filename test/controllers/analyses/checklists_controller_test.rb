require "test_helper"

class Analyses::ChecklistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @current_user = User.find_by(email: "guest@auction.local")
    @property = PropertyDataSyncService.call(case_number: "2026타경10002")
    @current_user.user_properties.find_or_create_by!(property: @property)
    PropertyAnalysisService.call(property: @property, user: @current_user)
  end

  test "GET edit shows all check results including manual items" do
    get edit_property_analyses_checklist_url(@property)
    assert_response :success
  end

  test "PATCH update saves auto item resolvable and redirects to rating" do
    auto_risk = @property.property_check_results
      .where(source_type: "auto", has_risk: true, user: @current_user).first

    # Mark all manual items as safe so form is complete
    @property.property_check_results.where(source_type: nil, user: @current_user).each do |r|
      r.update!(source_type: "manual", has_risk: false)
    end

    if auto_risk
      patch property_analyses_checklist_url(@property), params: {
        resolutions: { auto_risk.id => { resolvable: "false", resolution_note: "해결 불가" } }
      }
    else
      patch property_analyses_checklist_url(@property), params: { resolutions: {} }
    end
    assert_redirected_to property_analyses_rating_url(@property)
  end

  test "PATCH update saves manual item has_risk and resolvable" do
    manual_result = @property.property_check_results
      .where(source_type: nil, user: @current_user).first

    # Mark all other manual items as safe
    @property.property_check_results.where(source_type: nil, user: @current_user)
      .where.not(id: manual_result&.id).each { |r| r.update!(source_type: "manual", has_risk: false) }

    if manual_result
      resolutions = {
        manual_result.id => { has_risk: "true", resolvable: "true", resolution_note: "협의 완료" }
      }
      # Also include auto risk items
      @property.property_check_results
        .where(source_type: "auto", has_risk: true, user: @current_user).each do |r|
          resolutions[r.id] = { resolvable: "false", resolution_note: "" }
        end

      patch property_analyses_checklist_url(@property), params: { resolutions: resolutions }
      assert_redirected_to property_analyses_rating_url(@property)

      manual_result.reload
      assert_equal "manual", manual_result.source_type
      assert manual_result.has_risk
      assert manual_result.resolvable
      assert_equal "협의 완료", manual_result.resolution_note
    end
  end

  test "PATCH update saves manual item as safe when has_risk is false" do
    manual_result = @property.property_check_results
      .where(source_type: nil, user: @current_user).first

    # Mark all other manual items as safe
    @property.property_check_results.where(source_type: nil, user: @current_user)
      .where.not(id: manual_result&.id).each { |r| r.update!(source_type: "manual", has_risk: false) }

    if manual_result
      resolutions = {
        manual_result.id => { has_risk: "false" }
      }
      @property.property_check_results
        .where(source_type: "auto", has_risk: true, user: @current_user).each do |r|
          resolutions[r.id] = { resolvable: "false", resolution_note: "" }
        end

      patch property_analyses_checklist_url(@property), params: { resolutions: resolutions }
      assert_redirected_to property_analyses_rating_url(@property)

      manual_result.reload
      assert_equal "manual", manual_result.source_type
      assert_not manual_result.has_risk
      assert_nil manual_result.resolvable
    end
  end
end
