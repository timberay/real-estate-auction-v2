class CreateEvictionSimulatorQuestions < ActiveRecord::Migration[8.1]
  def change
    create_table :eviction_simulator_questions do |t|
      t.string  :code,             null: false
      t.integer :phase,            null: false, default: 0
      t.string  :step_code,        null: false
      t.text    :question,         null: false
      t.text    :help_text
      t.string  :yes_next_code
      t.string  :no_next_code
      t.string  :f02_field_mapping
      t.string  :difficulty_impact
      t.timestamps
    end

    add_index :eviction_simulator_questions, :code, unique: true
    add_index :eviction_simulator_questions, :step_code
  end
end
