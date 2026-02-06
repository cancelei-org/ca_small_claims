# frozen_string_literal: true

class ProductFeedbackVote < ApplicationRecord
  belongs_to :user
  belongs_to :product_feedback, counter_cache: :votes_count

  validates :user_id, uniqueness: { scope: :product_feedback_id, message: "can only vote once per feedback" }
end
