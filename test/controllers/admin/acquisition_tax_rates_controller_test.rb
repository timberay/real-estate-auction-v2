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

  # F-D-2 — create/destroy let admins add brand-new rows (e.g. a new
  # household_tier × property_type combination) and retire stale rows
  # without seed PRs.
  test "GET new renders the create form for admin" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    get new_admin_acquisition_tax_rate_url
    assert_response :success
    assert_match(/세율/, @response.body)
  end

  test "GET new returns 404 for non-admin" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    get new_admin_acquisition_tax_rate_url
    assert_response :not_found
  end

  test "POST create persists a new rate and redirects to index" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    assert_difference -> { AcquisitionTaxRate.count }, +1 do
      post admin_acquisition_tax_rates_url, params: {
        acquisition_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          price_bucket_min_manwon: 0,
          price_bucket_max_manwon: 60_000,
          area_over_85: false,
          regulated_region: nil,
          total_rate: 0.012
        }
      }
    end
    assert_redirected_to admin_acquisition_tax_rates_url
    created = AcquisitionTaxRate.order(:id).last
    assert_in_delta 0.012, created.total_rate.to_f, 1e-6
    assert_equal "homeless", created.household_tier
  end

  test "POST create with invalid params re-renders new" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    assert_no_difference -> { AcquisitionTaxRate.count } do
      post admin_acquisition_tax_rates_url, params: {
        acquisition_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          price_bucket_min_manwon: 0,
          total_rate: 0.50  # > 0.20 cap → validation fails
        }
      }
    end
    assert_response :unprocessable_content
  end

  test "POST create from non-admin returns 404 and creates nothing" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    assert_no_difference -> { AcquisitionTaxRate.count } do
      post admin_acquisition_tax_rates_url, params: {
        acquisition_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          price_bucket_min_manwon: 0,
          total_rate: 0.012
        }
      }
    end
    assert_response :not_found
  end

  test "DELETE destroy removes the row and redirects to index" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    rate = acquisition_tax_rates(:apartment_homeless_under6_under85)
    assert_difference -> { AcquisitionTaxRate.count }, -1 do
      delete admin_acquisition_tax_rate_url(rate)
    end
    assert_redirected_to admin_acquisition_tax_rates_url
  end

  test "DELETE destroy from non-admin returns 404 and keeps the row" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    rate = acquisition_tax_rates(:apartment_homeless_under6_under85)
    assert_no_difference -> { AcquisitionTaxRate.count } do
      delete admin_acquisition_tax_rate_url(rate)
    end
    assert_response :not_found
  end

  # F-D-3 — every successful mutation records an audit row attributed to
  # the acting admin. Failed validations and non-admin requests must NOT
  # produce audit rows.
  test "POST create writes one audit row attributed to the admin" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    assert_difference -> { AcquisitionTaxRateAuditLog.count }, +1 do
      post admin_acquisition_tax_rates_url, params: {
        acquisition_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          price_bucket_min_manwon: 0,
          price_bucket_max_manwon: 60_000,
          area_over_85: false,
          regulated_region: nil,
          total_rate: 0.012
        }
      }
    end
    log = AcquisitionTaxRateAuditLog.order(:id).last
    assert_equal "created", log.action
    assert_equal @admin.id, log.user_id
    payload = JSON.parse(log.changes_json)
    assert payload.key?("after"), payload.inspect
    assert_in_delta 0.012, payload.dig("after", "total_rate").to_f, 1e-6
  end

  test "POST create with invalid params writes no audit row" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    assert_no_difference -> { AcquisitionTaxRateAuditLog.count } do
      post admin_acquisition_tax_rates_url, params: {
        acquisition_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          price_bucket_min_manwon: 0,
          total_rate: 0.50
        }
      }
    end
  end

  test "POST create from non-admin writes no audit row" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    assert_no_difference -> { AcquisitionTaxRateAuditLog.count } do
      post admin_acquisition_tax_rates_url, params: {
        acquisition_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          price_bucket_min_manwon: 0,
          total_rate: 0.012
        }
      }
    end
  end
end
