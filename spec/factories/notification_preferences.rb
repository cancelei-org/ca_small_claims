# frozen_string_literal: true

FactoryBot.define do
  factory :notification_preference do
    user

    email_form_submission { true }
    email_form_download { true }
    email_deadline_reminders { true }
    email_fee_waiver_status { true }
    email_marketing { false }

    trait :all_disabled do
      email_form_submission { false }
      email_form_download { false }
      email_deadline_reminders { false }
      email_fee_waiver_status { false }
      email_marketing { false }
    end

    trait :marketing_enabled do
      email_marketing { true }
    end
  end
end
