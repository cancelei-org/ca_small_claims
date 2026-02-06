class CreateAlertLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :alert_logs do |t|
      t.string :event, null: false
      t.string :severity, null: false
      t.jsonb :payload, default: {}

      t.timestamps
    end
  end
end
