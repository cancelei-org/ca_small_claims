# frozen_string_literal: true

class AddCompositeIndexesForPerformance < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Composite index for efficient user submissions filtering and sorting
    # Covers queries like: user.submissions.where(status: X).order(created_at: :desc)
    add_index :submissions, [ :user_id, :status, :created_at ],
              name: "index_submissions_on_user_status_created",
              if_not_exists: true,
              algorithm: :concurrently

    # Composite index for form + status filtering in admin views
    # Covers queries like: Submission.where(form_definition_id: X, status: Y)
    add_index :submissions, [ :form_definition_id, :status ],
              name: "index_submissions_on_form_definition_and_status",
              if_not_exists: true,
              algorithm: :concurrently

    # Composite index for efficient session submission cleanup queries
    # Covers queries like: SessionSubmission.where(session_id: X).expired
    add_index :session_submissions, [ :session_id, :expires_at ],
              name: "index_session_submissions_on_session_and_expires",
              if_not_exists: true,
              algorithm: :concurrently
  end
end
