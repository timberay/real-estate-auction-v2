require "application_system_test_case"

# T3.5 #22 — sortable rows on the compare board. Each numeric row exposes
# a sort button; clicking it reorders the property columns by that row's
# values, toggling asc/desc/none.
class PropertyComparisonSortTest < ApplicationSystemTestCase
  setup do
    @user = users(:budget_user)
    @apt   = properties(:safe_apartment)         # appraisal 8억
    @villa = properties(:risky_villa)            # appraisal 3억
    @office = properties(:unanalyzed_officetel)  # appraisal 2.5억

    [ @apt, @villa, @office ].each do |p|
      UserProperty.find_or_create_by!(user: @user, property: p)
    end
    sign_in_as(@user)
  end

  test "clicking the 감정가 row sort button orders columns ascending then descending" do
    visit compare_properties_path(ids: [ @apt.id, @villa.id, @office.id ].join(","))

    # Initial order matches the URL: apt, villa, office
    assert_column_order [ @apt, @villa, @office ]

    within "tr[data-sort-key='appraisal_price']" do
      click_button "정렬"
    end
    # Ascending: office (2.5억), villa (3억), apt (8억)
    assert_column_order [ @office, @villa, @apt ]

    within "tr[data-sort-key='appraisal_price']" do
      click_button "정렬"
    end
    # Descending: apt, villa, office
    assert_column_order [ @apt, @villa, @office ]
  end

  test "clicking a different row's sort button switches the sort and resets others" do
    visit compare_properties_path(ids: [ @apt.id, @villa.id, @office.id ].join(","))

    within "tr[data-sort-key='appraisal_price']" do
      click_button "정렬"
    end
    assert_column_order [ @office, @villa, @apt ]

    within "tr[data-sort-key='failed_bid_count']" do
      click_button "정렬"
    end
    # Ascending by failed_bid_count: apt (0), office (0), villa (2)
    # Among ties, original order is preserved (apt before office).
    assert_column_order [ @apt, @office, @villa ]
  end

  private

  def assert_column_order(expected_properties)
    case_numbers = page.all("thead th[scope='col'] [data-property-case-number]").map(&:text)
    assert_equal expected_properties.map(&:case_number), case_numbers,
      "expected column order #{expected_properties.map(&:case_number).inspect} but got #{case_numbers.inspect}"
  end
end
