class CreateNotificationPreferences < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.boolean :email_form_submission, default: true, null: false
      t.boolean :email_form_download, default: true, null: false
      t.boolean :email_deadline_reminders, default: true, null: false
      t.boolean :email_fee_waiver_status, default: true, null: false
      t.boolean :email_marketing, default: false, null: false

      t.timestamps
    end
  end
end
