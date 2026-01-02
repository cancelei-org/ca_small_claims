# frozen_string_literal: true

FactoryBot.define do
  factory :form_feedback do
    association :form_definition
    association :user
    rating { 4 }
    issue_types { [ "other" ] }
    comment { "Great experience!" }
    status { "pending" }
    session_id { SecureRandom.hex(16) }

    trait :anonymous do
      user { nil }
    end

    trait :with_issue do
      rating { 2 }
      issue_types { [ "pdf_not_filling", "elements_misaligned" ] }
      comment { "The PDF is misaligned." }
    end

    trait :resolved do
      status { "resolved" }
      association :resolved_by, factory: :user
      resolved_at { Time.current }
      admin_notes { "Fixed the alignment." }
    end
  end
end
