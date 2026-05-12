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

  test "GET edit renders the form for admin" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    rate = acquisition_tax_rates(:apartment_homeless_under6_under85)
    get edit_admin_acquisition_tax_rate_url(rate)
    assert_response :success
    assert_match(/세율/, @response.body)
  end

  test "GET edit returns 404 for non-admin" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    rate = acquisition_tax_rates(:apartment_homeless_under6_under85)
    get edit_admin_acquisition_tax_rate_url(rate)
    assert_response :not_found
  end

  test "PATCH update persists edits and redirects to index" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    rate = acquisition_tax_rates(:apartment_homeless_under6_under85)
    patch admin_acquisition_tax_rate_url(rate), params: {
      acquisition_tax_rate: {
        total_rate: 0.015,
        price_bucket_min_manwon: 0,
        price_bucket_max_manwon: 60000,
        area_over_85: false,
        regulated_region: nil
      }
    }
    assert_redirected_to admin_acquisition_tax_rates_url
    assert_in_delta 0.015, rate.reload.total_rate.to_f, 1e-6
  end

  test "PATCH update with rate over 0.20 cap re-renders edit" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    rate = acquisition_tax_rates(:apartment_homeless_under6_under85)
    patch admin_acquisition_tax_rate_url(rate), params: {
      acquisition_tax_rate: { total_rate: 0.50 }
    }
    assert_response :unprocessable_content
    refute_in_delta 0.50, rate.reload.total_rate.to_f, 1e-6
  end

  test "PATCH update from non-admin returns 404 and leaves row unchanged" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    rate = acquisition_tax_rates(:apartment_homeless_under6_under85)
    original = rate.total_rate
    patch admin_acquisition_tax_rate_url(rate), params: {
      acquisition_tax_rate: { total_rate: 0.099 }
    }
    assert_response :not_found
    assert_equal original, rate.reload.total_rate
  end
end
