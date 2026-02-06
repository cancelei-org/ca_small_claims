# frozen_string_literal: true

FactoryBot.define do
  factory :impersonation_log do
    association :admin, factory: [ :user, :admin ]
    association :target_user, factory: :user
    started_at { Time.current }
    ended_at { nil }
    reason { "Support request investigation" }
    ip_address { "127.0.0.1" }
    user_agent { "Mozilla/5.0 (Test Browser)" }

    trait :active do
      ended_at { nil }
    end

    trait :completed do
      ended_at { Time.current }
    end

    trait :with_reason do
      reason { "Investigating support ticket ##{rand(1000..9999)}" }
    end

    trait :without_reason do
      reason { nil }
    end
  end
end
