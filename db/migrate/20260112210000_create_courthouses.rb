# frozen_string_literal: true

class CreateCourthouses < ActiveRecord::Migration[8.1]
  def change
    create_table :courthouses do |t|
      t.string :name, null: false
      t.string :court_type, default: "small_claims"
      t.string :address, null: false
      t.string :city, null: false
      t.string :county, null: false
      t.string :zip, null: false
      t.string :phone
      t.string :hours
      t.string :website_url
      t.decimal :latitude, precision: 10, scale: 7
      t.decimal :longitude, precision: 10, scale: 7
      t.text :notes
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :courthouses, :county
    add_index :courthouses, :city
    add_index :courthouses, :zip
    add_index :courthouses, :active
    add_index :courthouses, [ :latitude, :longitude ], name: "index_courthouses_on_coordinates"
  end
end
