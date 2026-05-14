require "application_system_test_case"

# T3.5 #21 — estimated margin row (예상 차익, 감정가 기준) added to the
# compare board. Simple formula: 감정가 - 최저가 - 인수금액. When a rights
# analysis report is missing, the risk amount is treated as 0 (i.e. the
# pessimistic side of the calc is unknown so we report the appraisal-vs-
# floor delta only). This is the minimum-viable signal — user-driven bid
# pricing for a precise net profit lives in the follow-up.
class PropertyComparisonMarginTest < ApplicationSystemTestCase
  setup do
    @user = users(:budget_user)
    @apt   = properties(:safe_apartment)         # 8억 - 5.6억 = 2.4억
    @villa = properties(:risky_villa)            # 3억 - 2.1억 = 9,000만원
    [ @apt, @villa ].each do |p|
      UserProperty.find_or_create_by!(user: @user, property: p)
    end
    sign_in_as(@user)
  end

  test "compare page includes 예상 차익 row with appraisal minus min_bid (no report)" do
    visit compare_properties_path(ids: [ @apt.id, @villa.id ].join(","))

    within "tr[data-sort-key='estimated_margin']" do
      assert_text "예상 차익"
      # apt: 8억 - 5.6억 = 2억 4,000만원
      assert_text "2억 4,000만원"
      # villa: 3억 - 2.1억 = 9,000만원
      assert_text "9,000만원"
    end
  end

  test "예상 차익 row is sortable like other numeric rows" do
    visit compare_properties_path(ids: [ @apt.id, @villa.id ].join(","))

    within "tr[data-sort-key='estimated_margin']" do
      click_button "정렬"
    end
    # Ascending by margin: villa (9,000만원) before apt (2.4억)
    case_numbers = page.all("thead th[scope='col'] [data-property-case-number]").map(&:text)
    assert_equal [ @villa.case_number, @apt.case_number ], case_numbers
  end
end
