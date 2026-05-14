require "test_helper"

module Export
  class ComparisonCsvExporterTest < ActiveSupport::TestCase
    setup do
      @user = users(:budget_user)
      @apt = properties(:safe_apartment)         # appraisal 8억, min_bid 5.6억
      @villa = properties(:risky_villa)          # appraisal 3억, min_bid 2.1억
    end

    test "to_csv returns a UTF-8 BOM-prefixed CSV with header row and one row per property" do
      exporter = ComparisonCsvExporter.new(
        user_properties: [
          @user.user_properties.find_or_create_by!(property: @apt),
          @user.user_properties.find_or_create_by!(property: @villa)
        ],
        user: @user
      )

      csv = exporter.to_csv
      assert csv.start_with?("\xEF\xBB\xBF".b.force_encoding("UTF-8")), "expected UTF-8 BOM prefix"

      rows = CSV.parse(csv.dup.force_encoding("UTF-8").delete_prefix("\xEF\xBB\xBF"))
      assert_equal 3, rows.size, "expected header + 2 property rows"

      header = rows.first
      assert_includes header, "사건번호"
      assert_includes header, "감정가"
      assert_includes header, "예상차익"

      apt_row = rows.find { |r| r.first == @apt.case_number }
      villa_row = rows.find { |r| r.first == @villa.case_number }
      assert apt_row, "missing apt row"
      assert villa_row, "missing villa row"

      margin_idx = header.index("예상차익")
      assert_equal "240000000", apt_row[margin_idx]    # 8억 - 5.6억
      assert_equal "90000000",  villa_row[margin_idx]  # 3억 - 2.1억
    end
  end
end
