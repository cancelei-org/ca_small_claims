class CreateWorkflowSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :workflow_steps do |t|
      t.references :workflow, null: false, foreign_key: true
      t.references :form_definition, null: false, foreign_key: true

      t.integer :position, null: false
      t.string :name
      t.text :instructions
      t.boolean :required, default: true
      t.boolean :repeatable, default: false

      # Conditional inclusion
      t.json :conditions, default: {}

      # Data mapping from previous steps
      t.json :data_mappings, default: {}

      t.timestamps
    end

    add_index :workflow_steps, [ :workflow_id, :position ], unique: true
  end
end
