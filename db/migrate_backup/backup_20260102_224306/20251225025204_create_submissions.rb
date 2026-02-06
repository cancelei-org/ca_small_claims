class CreateSubmissions < ActiveRecord::Migration[8.0]
  def change
    create_table :submissions do |t|
      t.references :user, foreign_key: true
      t.references :form_definition, null: false, foreign_key: true
      t.references :workflow, foreign_key: true

      t.string :session_id
      t.string :status, default: 'draft'
      t.json :form_data, default: {}
      t.datetime :completed_at
      t.datetime :pdf_generated_at

      # For workflow context
      t.integer :workflow_step_position
      t.string :workflow_session_id

      t.timestamps
    end

    add_index :submissions, :session_id
    add_index :submissions, :status
    add_index :submissions, :workflow_session_id
    add_index :submissions, [ :user_id, :status ]
  end
end
