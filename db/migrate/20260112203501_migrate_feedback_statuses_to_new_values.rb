# frozen_string_literal: true

class MigrateFeedbackStatusesToNewValues < ActiveRecord::Migration[8.1]
  def up
    # Migrate old status values to new ones
    # pending -> open
    # acknowledged -> in_progress
    # resolved stays as resolved
    safety_assured do
      execute <<-SQL
        UPDATE form_feedbacks
        SET status = 'open'
        WHERE status = 'pending';
      SQL

      execute <<-SQL
        UPDATE form_feedbacks
        SET status = 'in_progress'
        WHERE status = 'acknowledged';
      SQL
    end
  end

  def down
    # Migrate back to old status values
    # open -> pending
    # in_progress -> acknowledged
    # closed -> resolved (closest equivalent)
    safety_assured do
      execute <<-SQL
        UPDATE form_feedbacks
        SET status = 'pending'
        WHERE status = 'open';
      SQL

      execute <<-SQL
        UPDATE form_feedbacks
        SET status = 'acknowledged'
        WHERE status = 'in_progress';
      SQL

      execute <<-SQL
        UPDATE form_feedbacks
        SET status = 'resolved'
        WHERE status = 'closed';
      SQL
    end
  end
end
