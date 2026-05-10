# frozen_string_literal: true

require "test_helper"

module Properties
  class ComparisonsControllerTest < ActionDispatch::IntegrationTest
    setup do
      get start_onboarding_url
      @user = inherit_fixture_guest_ownership
      @prop1 = properties(:safe_apartment)
      @prop2 = properties(:risky_villa)
      @prop3 = properties(:unanalyzed_officetel)
    end

    test "GET /properties/compare requires auth — logged-out redirects to login" do
      delete auth_logout_url
      get compare_properties_url
      assert_redirected_to auth_login_url
    end

    test "GET /properties/compare with 0 ids redirects with alert" do
      get compare_properties_url
      assert_redirected_to properties_url
      assert_equal "비교하려면 2개 이상의 물건을 선택해주세요.", flash[:alert]
    end

    test "GET /properties/compare with 1 id redirects with alert" do
      get compare_properties_url, params: { ids: @prop1.id.to_s }
      assert_redirected_to properties_url
      assert_equal "비교하려면 2개 이상의 물건을 선택해주세요.", flash[:alert]
    end

    test "GET /properties/compare with 2 valid owned ids renders compare page" do
      get compare_properties_url, params: { ids: "#{@prop1.id},#{@prop2.id}" }
      assert_response :success
      assert_includes response.body, @prop1.case_number
      assert_includes response.body, @prop2.case_number
    end

    test "GET /properties/compare with 11 ids only loads first 10" do
      # Create 11 extra properties and user_properties for the session user
      extra_props = (1..11).map do |i|
        Property.create!(
          case_number: "2099타경9#{i.to_s.rjust(4, '0')}",
          court_name: "테스트법원",
          address: "테스트주소 #{i}",
          appraisal_price: 100_000_000,
          min_bid_price: 70_000_000,
          status: "진행중"
        ).tap { |p| @user.user_properties.create!(property: p) }
      end
      ids = extra_props.map(&:id).join(",")
      get compare_properties_url, params: { ids: ids }
      assert_response :success
      assert_equal 10, assigns(:user_properties).size
    end

    test "GET /properties/compare with an id the user does not own silently filters it out" do
      other_user = users(:budget_user)
      other_prop = properties(:high_view_apartment)
      # Ensure other_prop is owned by other_user but NOT @user
      other_user.user_properties.find_or_create_by!(property: other_prop)
      @user.user_properties.where(property: other_prop).delete_all

      get compare_properties_url, params: { ids: "#{@prop1.id},#{@prop2.id},#{other_prop.id}" }
      assert_response :success
      assert_includes response.body, @prop1.case_number
      assert_includes response.body, @prop2.case_number
      assert_not_includes response.body, other_prop.case_number
    end
  end
end
