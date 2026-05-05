class BackfillPropertyCourtInfoFromSearchResults < ActiveRecord::Migration[8.1]
  # Properties created before the court_code/court_name columns existed
  # (migration 20260504121928) carry nil court info even when the originating
  # SearchResult has it. Copy the court info over so cards render consistently.
  # Idempotent — re-running is a no-op.
  def up
    execute <<~SQL
      UPDATE properties
      SET court_code = sr.court_code,
          court_name = sr.court_name
      FROM (
        SELECT DISTINCT case_number, court_code, court_name
        FROM search_results
        WHERE court_code IS NOT NULL
      ) AS sr
      WHERE properties.case_number = sr.case_number
        AND properties.court_code IS NULL
    SQL
  end

  def down
    # No-op — backfilled data is correct; reverting would only re-introduce nils.
  end
end
