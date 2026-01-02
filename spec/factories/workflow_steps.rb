# frozen_string_literal: true

FactoryBot.define do
  factory :workflow_step do
    association :workflow
    association :form_definition
    sequence(:position) { |n| n }
    required { true }
  end
end
