# frozen_string_literal: true

class CreateProductFeedbackVotes < ActiveRecord::Migration[8.1]
  def change
    create_table :product_feedback_votes do |t|
      t.references :user, null: false, foreign_key: true
      t.references :product_feedback, null: false, foreign_key: true

      t.timestamps
    end

    add_index :product_feedback_votes, %i[user_id product_feedback_id], unique: true
  end
end
