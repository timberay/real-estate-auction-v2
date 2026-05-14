require "test_helper"

class ApplicationControllerRescueTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership
    @property = user_properties(:guest_safe_apartment).property
  end

  test "HTML request whose action raises RecordInvalid redirects back with flash alert (no 5xx)" do
    with_user_property_update_raising("테스트 검증 실패") do
      patch toggle_favorite_property_url(@property),
            headers: { "HTTP_REFERER" => properties_url }
    end

    assert_response :redirect
    assert_redirected_to properties_url
    follow_redirect!
    assert_match "테스트 검증 실패", flash[:alert].to_s
  end

  test "HTML request without Referer falls back to root_path on RecordInvalid" do
    with_user_property_update_raising("불릿프루프 메시지") do
      patch toggle_favorite_property_url(@property)
    end

    assert_response :redirect
    assert_redirected_to root_path
    assert_match "불릿프루프 메시지", flash[:alert].to_s
  end

  test "Turbo Stream request whose action raises RecordInvalid redirects (no 5xx)" do
    with_user_property_update_raising("터보 검증 실패") do
      patch toggle_favorite_property_url(@property),
            headers: { "Accept" => "text/vnd.turbo-stream.html", "HTTP_REFERER" => properties_url }
    end

    assert_response :redirect
    assert_match "터보 검증 실패", flash[:alert].to_s
  end

  test "JSON request whose action raises RecordInvalid returns 422 with errors body" do
    with_user_property_update_raising("제이슨 검증 실패") do
      patch toggle_favorite_property_url(@property), as: :json
    end

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_includes body["errors"].join(", "), "제이슨 검증 실패"
  end

  private

  # Temporarily swap UserProperty#update! to raise RecordInvalid so we can
  # exercise ApplicationController#rescue_from without coupling to a specific
  # model validation. Cleanup restores the original method.
  def with_user_property_update_raising(message)
    bad_record = UserProperty.new
    bad_record.errors.add(:base, message)

    UserProperty.class_eval do
      alias_method :_t23_orig_update!, :update!
      define_method(:update!) { |*| raise ActiveRecord::RecordInvalid.new(bad_record) }
    end
    yield
  ensure
    UserProperty.class_eval do
      alias_method :update!, :_t23_orig_update!
      remove_method :_t23_orig_update!
    end
  end
end
