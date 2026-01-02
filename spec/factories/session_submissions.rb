# frozen_string_literal: true

FactoryBot.define do
  factory :session_submission do
    association :form_definition
    session_id { SecureRandom.hex(16) }
    form_data { { "test_field" => "test_value" } }
    expires_at { 72.hours.from_now }

    trait :expired do
      expires_at { 1.hour.ago }
    end
  end
end
