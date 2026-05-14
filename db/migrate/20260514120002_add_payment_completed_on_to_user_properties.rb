class AddPaymentCompletedOnToUserProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :user_properties, :payment_completed_on, :date
  end
end
