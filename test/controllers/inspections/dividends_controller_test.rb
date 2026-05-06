require "test_helper"

class Inspections::DividendsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @property = properties(:risky_villa)
    @report = rights_analysis_reports(:risky_villa_report)
    get start_onboarding_url
    @user = inherit_fixture_guest_ownership

    # Fixtures store json columns as strings in SQLite; normalise to Hash before each test
    @report.reload.update!(report_data: parse_data(@report.report_data))
  end

  # Helpers

  def parse_data(data)
    data.is_a?(String) ? JSON.parse(data) : (data || {})
  end

  def reloaded_data
    @report.reload
    parse_data(@report.report_data)
  end

  # Tests

  test "redirects without saving when expected_bid is zero" do
    patch property_inspections_dividend_url(@property), params: { expected_bid: "0" }
    assert_redirected_to property_inspections_grade_url(@property)

    assert_nil reloaded_data["user_simulation"]
  end

  test "redirects without saving when expected_bid is blank" do
    patch property_inspections_dividend_url(@property), params: { expected_bid: "" }
    assert_redirected_to property_inspections_grade_url(@property)

    assert_nil reloaded_data["user_simulation"]
  end

  test "saves simulation into user_simulation namespace" do
    patch property_inspections_dividend_url(@property), params: { expected_bid: "10000" }
    assert_redirected_to property_inspections_grade_url(@property)

    simulation = reloaded_data["user_simulation"]
    assert_not_nil simulation
    assert_equal 10000, simulation["expected_bid"]
    assert_not_nil simulation["simulated_at"]
  end

  test "execution cost is 1.5% of bid" do
    patch property_inspections_dividend_url(@property), params: { expected_bid: "10000" }

    simulation = reloaded_data["user_simulation"]
    expected_execution_cost = (10000 * 0.015).to_i
    assert_equal expected_execution_cost, simulation["execution_cost"]

    first_row = simulation["distribution"].first
    assert_equal "집행비용", first_row["holder"]
    assert_equal expected_execution_cost, first_row["claim"]
    assert_equal expected_execution_cost, first_row["dividend"]
  end

  test "does not overwrite LLM original tenants data" do
    original_tenants = [ { "name" => "김철수", "deposit" => 5000, "opposing_power" => false } ]
    @report.update!(report_data: parse_data(@report.report_data).merge("tenants" => original_tenants))

    patch property_inspections_dividend_url(@property), params: { expected_bid: "10000" }

    assert_equal original_tenants, reloaded_data["tenants"]
  end

  test "does not overwrite LLM original rights_timeline data" do
    original_rights = [ { "holder" => "국민은행", "type" => "근저당", "amount" => 3000, "extinguished_on_sale" => true } ]
    @report.update!(report_data: parse_data(@report.report_data).merge("rights_timeline" => original_rights))

    patch property_inspections_dividend_url(@property), params: { expected_bid: "10000" }

    assert_equal original_rights, reloaded_data["rights_timeline"]
  end

  test "distribution includes rights from rights_timeline" do
    rights = [
      { "holder" => "국민은행", "type" => "근저당", "amount" => 2000, "extinguished_on_sale" => true }
    ]
    @report.update!(report_data: parse_data(@report.report_data).merge("rights_timeline" => rights, "tenants" => []))

    patch property_inspections_dividend_url(@property), params: { expected_bid: "10000" }

    distribution = reloaded_data.dig("user_simulation", "distribution")
    bank_row = distribution.find { |r| r["holder"] == "국민은행" }
    assert_not_nil bank_row
    assert_equal 2000, bank_row["claim"]
  end

  test "tenant with opposing_power contributes to bidder_burden" do
    tenants = [ { "name" => "홍길동", "deposit" => 3000, "opposing_power" => true, "priority_rank" => 2 } ]
    @report.update!(report_data: parse_data(@report.report_data).merge("tenants" => tenants, "rights_timeline" => []))

    patch property_inspections_dividend_url(@property), params: { expected_bid: "10000" }

    simulation = reloaded_data["user_simulation"]
    assert_equal 3000, simulation["bidder_burden"]

    tenant_row = simulation["distribution"].find { |r| r["holder"] == "홍길동" }
    assert_not_nil tenant_row
    assert_equal 0, tenant_row["dividend"]
    assert tenant_row["assumed"]
  end

  test "remaining amount decreases as extinguished rights are paid" do
    rights = [
      { "holder" => "은행A", "type" => "근저당", "amount" => 5000, "extinguished_on_sale" => true }
    ]
    @report.update!(report_data: parse_data(@report.report_data).merge("rights_timeline" => rights, "tenants" => []))

    patch property_inspections_dividend_url(@property), params: { expected_bid: "10000" }

    simulation = reloaded_data["user_simulation"]
    execution_cost = simulation["execution_cost"]
    expected_remaining = 10000 - execution_cost - 5000
    assert_equal expected_remaining, simulation["remaining"]
  end
end
