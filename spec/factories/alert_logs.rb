# frozen_string_literal: true

FactoryBot.define do
  factory :alert_log do
    event { "test_event" }
    severity { "info" }
    payload { {} }

    trait :error do
      severity { "error" }
      event { "error_occurred" }
    end

    trait :warning do
      severity { "warning" }
      event { "warning_detected" }
    end

    trait :debug do
      severity { "debug" }
      event { "debug_info" }
    end

    trait :with_payload do
      payload do
        {
          user_id: 123,
          action: "test_action",
          metadata: { timestamp: Time.current.iso8601 }
        }
      end
    end
  end
end
