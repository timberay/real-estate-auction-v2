class CreateEvictionSteps < ActiveRecord::Migration[8.1]
  def change
    create_table :eviction_steps do |t|
      t.string  :code,                 null: false
      t.integer :step_type,            null: false, default: 0
      t.string  :name,                 null: false
      t.text    :description,          null: false
      t.text    :completion_condition
      t.text    :failure_condition
      t.json    :required_documents
      t.string  :estimated_duration
      t.string  :estimated_cost
      t.json    :legal_basis
      t.integer :position,             null: false, default: 0
      t.string  :next_step_code
      t.json    :branch_codes
      t.string  :trigger_step_code
      t.text    :problem_summary
      t.text    :root_cause
      t.json    :action_steps
      t.string  :return_step_code
      t.timestamps
    end

    add_index :eviction_steps, :code, unique: true
    add_index :eviction_steps, [ :step_type, :position ]
  end
end
