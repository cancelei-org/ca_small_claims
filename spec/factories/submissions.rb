# frozen_string_literal: true

FactoryBot.define do
  factory :submission do
    association :form_definition
    association :user
    status { "draft" }
    form_data { {} }

    trait :draft do
      status { "draft" }
    end

    trait :completed do
      status { "completed" }
      completed_at { Time.current }
    end

    trait :submitted do
      status { "submitted" }
      completed_at { 1.hour.ago }
    end

    trait :anonymous do
      user { nil }
      session_id { SecureRandom.hex(16) }
    end

    trait :in_workflow do
      association :workflow
      workflow_session_id { SecureRandom.uuid }
    end
  end
end
