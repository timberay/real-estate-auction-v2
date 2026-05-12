require "test_helper"

class Admin::AcquisitionTaxRatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @non_admin = users(:budget_user)
  end

  test "GET index renders for admin" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    get admin_acquisition_tax_rates_url
    assert_response :success
    assert_match(/취득세율/, @response.body)
  end

  test "GET index returns 404 for non-admin authenticated user" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    get admin_acquisition_tax_rates_url
    assert_response :not_found
  end

  test "GET index redirects unauthenticated visitor to login" do
    get admin_acquisition_tax_rates_url
    assert_redirected_to auth_login_url
  end
end
