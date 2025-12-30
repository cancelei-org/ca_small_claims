class CreateCategories < ActiveRecord::Migration[8.1]
  def change
    create_table :categories do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :icon
      t.integer :position, default: 0
      t.references :parent, foreign_key: { to_table: :categories }
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :categories, :slug, unique: true
    add_index :categories, [ :parent_id, :position ]

    # Add category reference to form_definitions and workflows
    add_reference :form_definitions, :category, foreign_key: true
    add_reference :workflows, :category, foreign_key: true
  end
end
