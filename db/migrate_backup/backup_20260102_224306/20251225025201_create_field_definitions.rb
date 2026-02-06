class CreateFieldDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :field_definitions do |t|
      t.references :form_definition, null: false, foreign_key: true

      t.string :name, null: false
      t.string :pdf_field_name, null: false
      t.string :field_type, null: false
      t.string :label
      t.text :help_text
      t.string :placeholder

      # Validation
      t.boolean :required, default: false
      t.string :validation_pattern
      t.integer :max_length
      t.integer :min_length

      # UI Layout
      t.string :section
      t.integer :position
      t.integer :page_number
      t.string :width, default: 'full'

      # Conditional logic
      t.json :conditions, default: {}

      # Repeating sections
      t.string :repeating_group
      t.integer :max_repetitions

      # Options for select/checkbox groups
      t.json :options, default: []

      # Data sharing between forms
      t.string :shared_field_key

      t.timestamps
    end

    add_index :field_definitions, [ :form_definition_id, :name ], unique: true
    add_index :field_definitions, :pdf_field_name
    add_index :field_definitions, :shared_field_key
  end
end
