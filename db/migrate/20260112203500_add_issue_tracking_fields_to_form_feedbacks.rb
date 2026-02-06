# frozen_string_literal: true

class AddIssueTrackingFieldsToFormFeedbacks < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Add priority field for issue tracking
    add_column :form_feedbacks, :priority, :string, default: "medium", null: false

    # Add index for priority filtering
    add_index :form_feedbacks, :priority, algorithm: :concurrently

    # Add composite index for common filter combinations
    add_index :form_feedbacks, [ :status, :priority ], name: "index_form_feedbacks_on_status_and_priority", algorithm: :concurrently
  end
end
