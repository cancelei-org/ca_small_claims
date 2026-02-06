class CreateFormDefinitions < ActiveRecord::Migration[8.0]
  def change
    create_table :form_definitions do |t|
      t.string :code, null: false
      t.string :title, null: false
      t.text :description
      t.string :category
      t.string :pdf_filename, null: false
      t.integer :page_count
      t.json :metadata, default: {}
      t.boolean :active, default: true
      t.integer :position

      t.timestamps
    end

    add_index :form_definitions, :code, unique: true
    add_index :form_definitions, :category
    add_index :form_definitions, :active
  end
end
