class CreateWorkflows < ActiveRecord::Migration[8.0]
  def change
    create_table :workflows do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.text :description
      t.string :category
      t.boolean :active, default: true
      t.integer :position

      t.timestamps
    end

    add_index :workflows, :slug, unique: true
    add_index :workflows, :category
    add_index :workflows, :active
  end
end
