class AddCourtToProperties < ActiveRecord::Migration[8.0]
  def up
    add_column :properties, :court_code, :string
    add_column :properties, :court_name, :string

    # One-time backfill: properties imported via search_results have
    # court info on the SearchResult row but not on Property. Join by
    # case_number and copy. SearchResult is per-user; pick any row.
    execute <<~SQL
      UPDATE properties
         SET court_code = (
               SELECT court_code FROM search_results
                WHERE search_results.case_number = properties.case_number
                  AND search_results.court_code IS NOT NULL
                LIMIT 1
             ),
             court_name = (
               SELECT court_name FROM search_results
                WHERE search_results.case_number = properties.case_number
                  AND search_results.court_name IS NOT NULL
                LIMIT 1
             )
       WHERE properties.court_code IS NULL
    SQL
  end

  def down
    remove_column :properties, :court_name
    remove_column :properties, :court_code
  end
end
