class RemoveUserColumnsFromProperties < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      INSERT INTO user_properties (user_id, property_id, safety_rating, created_at, updated_at)
      SELECT user_id, id, safety_rating, created_at, updated_at
      FROM properties
      WHERE user_id IS NOT NULL
      ON CONFLICT (user_id, property_id) DO NOTHING
    SQL
    remove_index :properties, :safety_rating, if_exists: true
    remove_index :properties, :user_id, if_exists: true
    remove_column :properties, :safety_rating, :integer
    remove_column :properties, :user_id, :integer
  end

  def down
    add_column :properties, :safety_rating, :integer
    add_column :properties, :user_id, :integer
    add_index :properties, :safety_rating
    add_index :properties, :user_id
  end
end
