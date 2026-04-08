class RemoveFailedAuctionRoundsColumns < ActiveRecord::Migration[8.1]
  def change
    remove_column :budget_settings, :failed_auction_rounds, :integer, default: 0
    remove_column :budget_settings, :searchable_appraisal_limit, :integer
    remove_column :budget_snapshots, :failed_auction_rounds, :integer
    remove_column :budget_snapshots, :searchable_appraisal_limit, :integer
  end
end
