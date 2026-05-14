require "test_helper"

class Admin::TransferTaxRatesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:admin_user)
    @non_admin = users(:budget_user)
  end

  test "GET index renders for admin" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    get admin_transfer_tax_rates_url
    assert_response :success
    assert_match(/양도세율/, @response.body)
  end

  test "GET index returns 404 for non-admin authenticated user" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    get admin_transfer_tax_rates_url
    assert_response :not_found
  end

  test "GET index redirects unauthenticated visitor to login" do
    get admin_transfer_tax_rates_url
    assert_redirected_to auth_login_url
  end

  test "GET edit renders the form for admin" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    get edit_admin_transfer_tax_rate_url(rate)
    assert_response :success
    assert_match(/세율/, @response.body)
  end

  test "GET edit returns 404 for non-admin" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    get edit_admin_transfer_tax_rate_url(rate)
    assert_response :not_found
  end

  test "PATCH update persists edits and redirects to index" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    patch admin_transfer_tax_rate_url(rate), params: {
      transfer_tax_rate: {
        total_rate: 0.65,
        regulated_region: nil
      }
    }
    assert_redirected_to admin_transfer_tax_rates_url
    assert_in_delta 0.65, rate.reload.total_rate.to_f, 1e-6
  end

  test "PATCH update with rate over 1.0 cap re-renders edit" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    patch admin_transfer_tax_rate_url(rate), params: {
      transfer_tax_rate: { total_rate: 1.5 }
    }
    assert_response :unprocessable_content
    refute_in_delta 1.5, rate.reload.total_rate.to_f, 1e-6
  end

  test "PATCH update from non-admin returns 404 and leaves row unchanged" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    original = rate.total_rate
    patch admin_transfer_tax_rate_url(rate), params: {
      transfer_tax_rate: { total_rate: 0.099 }
    }
    assert_response :not_found
    assert_equal original, rate.reload.total_rate
  end

  # T1.2-F-A — create/destroy let admins add brand-new rows (e.g. a new
  # household_tier × holding_period combination) and retire stale rows
  # without seed PRs.
  test "GET new renders the create form for admin" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    get new_admin_transfer_tax_rate_url
    assert_response :success
    assert_match(/세율/, @response.body)
  end

  test "GET new returns 404 for non-admin" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    get new_admin_transfer_tax_rate_url
    assert_response :not_found
  end

  test "POST create persists a new rate and redirects to index" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    assert_difference -> { TransferTaxRate.count }, +1 do
      post admin_transfer_tax_rates_url, params: {
        transfer_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          holding_period: "under_1y",
          regulated_region: nil,
          total_rate: 0.70
        }
      }
    end
    assert_redirected_to admin_transfer_tax_rates_url
    created = TransferTaxRate.order(:id).last
    assert_in_delta 0.70, created.total_rate.to_f, 1e-6
    assert_equal "homeless", created.household_tier
    assert_equal "under_1y", created.holding_period
  end

  test "POST create with invalid params re-renders new" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    assert_no_difference -> { TransferTaxRate.count } do
      post admin_transfer_tax_rates_url, params: {
        transfer_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          holding_period: "under_1y",
          total_rate: 1.5  # > 1.0 cap → validation fails
        }
      }
    end
    assert_response :unprocessable_content
  end

  test "POST create from non-admin returns 404 and creates nothing" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    assert_no_difference -> { TransferTaxRate.count } do
      post admin_transfer_tax_rates_url, params: {
        transfer_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          holding_period: "under_1y",
          total_rate: 0.70
        }
      }
    end
    assert_response :not_found
  end

  test "DELETE destroy removes the row and redirects to index" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    assert_difference -> { TransferTaxRate.count }, -1 do
      delete admin_transfer_tax_rate_url(rate)
    end
    assert_redirected_to admin_transfer_tax_rates_url
  end

  test "DELETE destroy from non-admin returns 404 and keeps the row" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    assert_no_difference -> { TransferTaxRate.count } do
      delete admin_transfer_tax_rate_url(rate)
    end
    assert_response :not_found
  end

  # T1.2-F-C — every successful mutation records an audit row attributed to
  # the acting admin. Failed validations and non-admin requests must NOT
  # produce audit rows.
  test "POST create writes one audit row attributed to the admin" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    assert_difference -> { TransferTaxRateAuditLog.count }, +1 do
      post admin_transfer_tax_rates_url, params: {
        transfer_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          holding_period: "under_1y",
          regulated_region: nil,
          total_rate: 0.70
        }
      }
    end
    log = TransferTaxRateAuditLog.order(:id).last
    assert_equal "created", log.action
    assert_equal @admin.id, log.user_id
    payload = JSON.parse(log.changes_json)
    assert payload.key?("after"), payload.inspect
    assert_in_delta 0.70, payload.dig("after", "total_rate").to_f, 1e-6
  end

  test "POST create with invalid params writes no audit row" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    assert_no_difference -> { TransferTaxRateAuditLog.count } do
      post admin_transfer_tax_rates_url, params: {
        transfer_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          holding_period: "under_1y",
          total_rate: 1.5
        }
      }
    end
  end

  test "POST create from non-admin writes no audit row" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    assert_no_difference -> { TransferTaxRateAuditLog.count } do
      post admin_transfer_tax_rates_url, params: {
        transfer_tax_rate: {
          property_type_id: property_types(:villa).id,
          household_tier: "homeless",
          holding_period: "under_1y",
          total_rate: 0.70
        }
      }
    end
  end

  test "PATCH update writes an audit row with before/after for the changed field" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    before_rate = rate.total_rate
    assert_difference -> { TransferTaxRateAuditLog.count }, +1 do
      patch admin_transfer_tax_rate_url(rate), params: {
        transfer_tax_rate: {
          total_rate: 0.65,
          regulated_region: nil
        }
      }
    end
    log = TransferTaxRateAuditLog.order(:id).last
    assert_equal "updated", log.action
    assert_equal @admin.id, log.user_id
    assert_equal rate.id, log.transfer_tax_rate_id
    payload = JSON.parse(log.changes_json)
    assert payload.key?("before"), payload.inspect
    assert payload.key?("after"),  payload.inspect
    assert_in_delta before_rate.to_f, payload.dig("before", "total_rate").to_f, 1e-6
    assert_in_delta 0.65,             payload.dig("after",  "total_rate").to_f, 1e-6
  end

  test "PATCH update with invalid params writes no audit row" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    assert_no_difference -> { TransferTaxRateAuditLog.count } do
      patch admin_transfer_tax_rate_url(rate), params: {
        transfer_tax_rate: { total_rate: 1.5 }
      }
    end
  end

  test "PATCH update from non-admin writes no audit row" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    assert_no_difference -> { TransferTaxRateAuditLog.count } do
      patch admin_transfer_tax_rate_url(rate), params: {
        transfer_tax_rate: { total_rate: 0.099 }
      }
    end
  end

  test "DELETE destroy writes an audit row that survives the row removal" do
    post "/testing/sign_in", params: { user_id: @admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    snapshot_rate = rate.total_rate.to_f
    assert_difference -> { TransferTaxRateAuditLog.count }, +1 do
      delete admin_transfer_tax_rate_url(rate)
    end
    log = TransferTaxRateAuditLog.order(:id).last
    assert_equal "destroyed", log.action
    assert_equal @admin.id, log.user_id
    payload = JSON.parse(log.changes_json)
    assert payload.key?("before"), payload.inspect
    assert_in_delta snapshot_rate, payload.dig("before", "total_rate").to_f, 1e-6
    refute TransferTaxRate.exists?(rate.id)
    assert_equal rate.id, log.transfer_tax_rate_id
  end

  test "DELETE destroy from non-admin writes no audit row" do
    post "/testing/sign_in", params: { user_id: @non_admin.id }
    rate = transfer_tax_rates(:apt_homeless_under1y)
    assert_no_difference -> { TransferTaxRateAuditLog.count } do
      delete admin_transfer_tax_rate_url(rate)
    end
  end
end
