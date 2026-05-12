require "test_helper"

# F-D-3 — read-only audit log viewer. Admin-only, same 404 cloaking as
# the rest of /admin/*.
class Admin::AcquisitionTaxRateAuditLogsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @non_admin = users(:budget_user)
    @rate = acquisition_tax_rates(:apartment_homeless_under6_under85)
  end

  test "GET index renders for admin and shows recent log entries" do
    AcquisitionTaxRateAuditLog.create!(
      acquisition_tax_rate: @rate,
      user: @admin,
      action: "updated",
      changes_json: { before: { total_rate: 0.011 }, after: { total_rate: 0.015 } }.to_json
    )
    post "/testing/sign_in", params: { user_id: @admin.id }
    get admin_acquisition_tax_rate_audit_logs_url
    assert_response :success
    assert_match(/변경 이력|audit/i, @response.body)
    assert_match(/updated/, @response.body)
    assert_match(/#{@admin.email}/, @response.body)
  end

  test "GET index returns 404 for non-admin authenticated user" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    get admin_acquisition_tax_rate_audit_logs_url
    assert_response :not_found
  end

  test "GET index redirects unauthenticated visitor to login" do
    get admin_acquisition_tax_rate_audit_logs_url
    assert_redirected_to auth_login_url
  end
end
