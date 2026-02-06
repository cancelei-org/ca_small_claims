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

    # Generate form_data based on all field definitions for the form
    # Usage: create(:submission, :with_complete_form_data)
    trait :with_complete_form_data do
      after(:build) do |submission|
        submission.form_data = submission.form_definition.field_definitions.each_with_object({}) do |field, data|
          data[field.name] = generate_test_value_for_field(field)
        end
      end
    end

    # Realistic small claims form data for common scenarios
    # Usage: create(:submission, :with_sample_claim_data)
    trait :with_sample_claim_data do
      form_data do
        {
          "plaintiff_name" => "Jane Smith",
          "plaintiff_address" => "123 Main Street",
          "plaintiff_city" => "Los Angeles",
          "plaintiff_state" => "CA",
          "plaintiff_zip" => "90001",
          "plaintiff_phone" => "(555) 123-4567",
          "plaintiff_email" => "jane.smith@example.com",
          "defendant_name" => "John Doe",
          "defendant_address" => "456 Oak Avenue",
          "defendant_city" => "San Francisco",
          "defendant_state" => "CA",
          "defendant_zip" => "94102",
          "claim_amount" => "5000.00",
          "claim_description" => "Breach of contract for services not rendered",
          "incident_date" => "2025-06-15"
        }
      end
    end

    # Ready for PDF generation - completed with form data
    # Usage: create(:submission, :ready_for_pdf)
    trait :ready_for_pdf do
      with_complete_form_data
      status { "completed" }
      completed_at { Time.current }
    end

    # For testing shared field key propagation across forms
    # Usage: create(:submission, :with_shared_fields, shared_data: { plaintiff_name: "Test" })
    trait :with_shared_fields do
      transient do
        shared_data { {} }
      end

      after(:build) do |submission, evaluator|
        submission.form_data = submission.form_data.merge(evaluator.shared_data.stringify_keys)
      end
    end
  end
end

# Helper method to generate test values based on field type
def generate_test_value_for_field(field)
  case field.field_type
  when "text", "textarea"
    "Test #{field.label}"
  when "email"
    "test@example.com"
  when "tel"
    "(555) 555-1234"
  when "date"
    Date.current.strftime("%Y-%m-%d")
  when "currency"
    "1000.00"
  when "checkbox"
    true
  when "select", "radio"
    field.options&.first&.dig("value") || "option1"
  when "signature"
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
  when "number"
    "100"
  when "address"
    { street: "123 Test St", city: "Test City", state: "CA", zip: "90001" }
  else
    "Test Value"
  end
end
