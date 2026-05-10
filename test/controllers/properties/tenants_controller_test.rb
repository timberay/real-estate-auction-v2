require "test_helper"

class Properties::TenantsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership

    @property = properties(:risky_villa)
    UserProperty.find_or_create_by!(user: @user, property: @property)

    @report = RightsAnalysisReport.find_by!(user: @user, property: @property)
    @report.update!(report_data: {
      "calculated" => {
        "tenants" => [
          {
            "name" => "홍길동", "deposit" => 30_000_000,
            "move_in_date" => "2023-01-01", "confirmed_date" => "2023-01-05",
            "opposing_power" => true
          }
        ]
      }
    }.to_json)
  end

  # Auth
  test "unauthenticated GET edit redirects to login" do
    delete auth_logout_path
    get edit_property_report_tenant_path(@property, 0)
    assert_redirected_to auth_login_path
  end

  test "unauthenticated PATCH update redirects to login" do
    delete auth_logout_path
    patch property_report_tenant_path(@property, 0), params: { tenant: { deposit: 10_000_000 } }
    assert_redirected_to auth_login_path
  end

  # Authorization — non-owner gets 404
  test "non-owner GET edit returns 404" do
    other_property = properties(:safe_apartment)
    UserProperty.where(user: @user, property: other_property).destroy_all
    get edit_property_report_tenant_path(other_property, 0)
    assert_response :not_found
  end

  # Happy path — edit
  test "GET edit returns 200 and renders the tenant form" do
    get edit_property_report_tenant_path(@property, 0)
    assert_response :success
    assert_select "input[name='tenant[deposit]']"
    assert_select "input[name='tenant[move_in_date]']"
    assert_select "input[name='tenant[confirmed_date]']"
  end

  test "GET edit populates form with current tenant values" do
    get edit_property_report_tenant_path(@property, 0)
    assert_response :success
    assert_select "input[name='tenant[deposit]'][value='30000000']"
    assert_select "input[name='tenant[move_in_date]'][value='2023-01-01']"
  end

  # Happy path — update
  test "PATCH update persists changes and re-renders the tenant row" do
    patch property_report_tenant_path(@property, 0),
      params: { tenant: { deposit: 25_000_000, move_in_date: "2023-02-01", confirmed_date: "2023-02-05" } },
      headers: { "Accept" => "text/vnd.turbo-stream.html" }

    assert_response :success
    @report.reload
    tenant = @report.effective_tenants.first
    assert_equal 25_000_000, tenant["deposit"]
    assert_equal "2023-02-01", tenant["move_in_date"]
    assert_equal true, tenant["user_edited"]
  end

  test "PATCH update without turbo redirects to property path" do
    patch property_report_tenant_path(@property, 0),
      params: { tenant: { deposit: 20_000_000, move_in_date: "2023-03-01", confirmed_date: "" } }
    assert_redirected_to property_path(@property)
  end

  # Out-of-bounds index
  test "GET edit with out-of-bounds index returns 404" do
    get edit_property_report_tenant_path(@property, 99)
    assert_response :not_found
  end

  test "PATCH update with out-of-bounds index returns 404" do
    patch property_report_tenant_path(@property, 99),
      params: { tenant: { deposit: 1_000_000 } }
    assert_response :not_found
  end

  # Show — cancel restores display row inside turbo frame
  test "GET show returns 200 and wraps row in tenant-row-N turbo frame" do
    get property_report_tenant_path(@property, 0)
    assert_response :success
    assert_select "turbo-frame[id='tenant-row-0']"
    assert_select "turbo-frame[id='tenant-row-0'] .rounded-lg"
  end

  test "unauthenticated GET show redirects to login" do
    delete auth_logout_path
    get property_report_tenant_path(@property, 0)
    assert_redirected_to auth_login_path
  end

  test "GET show with out-of-bounds index returns 404" do
    get property_report_tenant_path(@property, 99)
    assert_response :not_found
  end
end
