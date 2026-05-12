require "test_helper"

class Api::ReserveFundDefaultsControllerTest < ActionDispatch::IntegrationTest
  setup do
    get start_onboarding_url  # create guest session via non-public action
  end

  test "GET index returns defaults for given property_type_id" do
    apt = property_types(:apartment)
    get api_reserve_fund_defaults_url(property_type_id: apt.id), as: :json
    assert_response :success

    body = JSON.parse(response.body)
    assert_kind_of Array, body
    assert body.length > 0
    assert_equal 527, body.first["repair_cost"]
  end

  # F-A: acquisition tax is now derived from bracket iteration, not from a
  # static rate on ReserveFundDefault. The serialized payload must not leak
  # the dead column back to the client.
  test "GET index payload omits acquisition_tax_rate" do
    apt = property_types(:apartment)
    get api_reserve_fund_defaults_url(property_type_id: apt.id), as: :json
    assert_response :success

    body = JSON.parse(response.body)
    assert body.length > 0
    assert_not body.first.key?("acquisition_tax_rate"),
               "acquisition_tax_rate should be dropped from API payload"
  end

  test "GET index returns empty array for unknown type" do
    get api_reserve_fund_defaults_url(property_type_id: 9999), as: :json
    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end
end
