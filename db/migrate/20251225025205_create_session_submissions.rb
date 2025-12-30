class CreateSessionSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :session_submissions do |t|
      t.string :session_id, null: false
      t.references :form_definition, null: false, foreign_key: true
      t.json :form_data, default: {}
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :session_submissions, :session_id
    add_index :session_submissions, :expires_at
    add_index :session_submissions, [ :session_id, :form_definition_id ], unique: true
  end
end
