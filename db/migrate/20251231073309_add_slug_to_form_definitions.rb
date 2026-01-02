class AddSlugToFormDefinitions < ActiveRecord::Migration[8.1]
  # For development/small datasets, concurrent indexing isn't needed
  # Using safety_assured since form_definitions table is small (~1500 rows)
  def change
    add_column :form_definitions, :slug, :string

    safety_assured do
      add_index :form_definitions, :slug, unique: true
    end

    # FriendlyId history table for URL redirects
    create_table :friendly_id_slugs do |t|
      t.string   :slug, null: false
      t.integer  :sluggable_id, null: false
      t.string   :sluggable_type, limit: 50
      t.string   :scope
      t.datetime :created_at
    end

    safety_assured do
      add_index :friendly_id_slugs, :sluggable_id
      add_index :friendly_id_slugs, [ :slug, :sluggable_type ], length: { slug: 140, sluggable_type: 50 }
      add_index :friendly_id_slugs, [ :slug, :sluggable_type, :scope ], length: { slug: 70, sluggable_type: 50, scope: 70 }, unique: true
    end
  end
end
