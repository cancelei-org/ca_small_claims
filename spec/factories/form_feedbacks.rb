# frozen_string_literal: true

FactoryBot.define do
  factory :form_feedback do
    association :form_definition
    association :user
    rating { 4 }
    issue_types { [ "other" ] }
    comment { "Great experience!" }
    status { "open" }
    priority { "medium" }
    session_id { SecureRandom.hex(16) }

    trait :anonymous do
      user { nil }
    end

    trait :with_issue do
      rating { 2 }
      issue_types { [ "pdf_not_filling", "elements_misaligned" ] }
      comment { "The PDF is misaligned." }
    end

    # New status traits
    trait :open do
      status { "open" }
    end

    trait :in_progress do
      status { "in_progress" }
    end

    trait :resolved do
      status { "resolved" }
      association :resolved_by, factory: :user
      resolved_at { Time.current }
      admin_notes { "Fixed the alignment." }
    end

    trait :closed do
      status { "closed" }
      association :resolved_by, factory: :user
      resolved_at { Time.current }
      admin_notes { "Closed as won't fix." }
    end

    # Legacy trait aliases for backward compatibility in tests
    trait :pending do
      status { "open" }
    end

    trait :acknowledged do
      status { "in_progress" }
    end

    # Priority traits
    trait :low_priority do
      priority { "low" }
    end

    trait :medium_priority do
      priority { "medium" }
    end

    trait :high_priority do
      priority { "high" }
    end

    trait :urgent_priority do
      priority { "urgent" }
    end
  end
end
