class AddLastSearchApiTotalCountToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_search_api_total_count, :integer
  end
end
