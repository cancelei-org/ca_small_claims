# frozen_string_literal: true

FactoryBot.define do
  factory :workflow do
    sequence(:name) { |n| "Workflow #{n}" }
    sequence(:slug) { |n| "workflow-#{n}" }
    description { "Test workflow description" }
    active { true }
    position { 1 }
    association :category
  end
end
