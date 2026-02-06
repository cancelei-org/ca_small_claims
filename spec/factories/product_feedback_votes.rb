# frozen_string_literal: true

FactoryBot.define do
  factory :product_feedback_vote do
    association :user
    association :product_feedback
  end
end
