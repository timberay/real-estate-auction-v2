class AddCourtCodeToSearchResults < ActiveRecord::Migration[8.1]
  def change
    add_column :search_results, :court_code, :string
  end
end
