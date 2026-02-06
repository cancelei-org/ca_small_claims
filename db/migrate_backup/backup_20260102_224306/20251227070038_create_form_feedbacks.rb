class CreateFormFeedbacks < ActiveRecord::Migration[8.1]
  def change
    create_table :form_feedbacks do |t|
      t.references :form_definition, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :session_id
      t.integer :rating, null: false
      t.string :issue_types, array: true, default: []
      t.text :comment
      t.string :status, default: "pending", null: false
      t.text :admin_notes
      t.datetime :resolved_at
      t.references :resolved_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :form_feedbacks, :status
    add_index :form_feedbacks, :issue_types, using: :gin
    add_index :form_feedbacks, [ :form_definition_id, :status ]
    add_index :form_feedbacks, :rating
  end
end
