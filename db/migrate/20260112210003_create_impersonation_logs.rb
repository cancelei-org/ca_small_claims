class CreateImpersonationLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :impersonation_logs do |t|
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.references :target_user, null: false, foreign_key: { to_table: :users }
      t.datetime :started_at, null: false
      t.datetime :ended_at
      t.string :reason
      t.string :ip_address
      t.string :user_agent

      t.timestamps
    end

    add_index :impersonation_logs, :started_at
    add_index :impersonation_logs, [ :admin_id, :started_at ]
  end
end
