class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :event
      t.string :target_type
      t.integer :target_id
      t.jsonb :details
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end
  end
end
