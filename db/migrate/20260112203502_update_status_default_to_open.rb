# frozen_string_literal: true

class UpdateStatusDefaultToOpen < ActiveRecord::Migration[8.1]
  def up
    safety_assured do
      change_column_default :form_feedbacks, :status, "open"
    end
  end

  def down
    safety_assured do
      change_column_default :form_feedbacks, :status, "pending"
    end
  end
end
