# frozen_string_literal: true

FactoryBot.define do
  factory :field_definition do
    association :form_definition
    sequence(:name) { |n| "field_#{n}" }
    sequence(:pdf_field_name) { |n| "FillText#{n}" }
    field_type { "text" }
    label { "Test Field" }
    position { 1 }
    required { false }
    width { "full" }

    trait :required do
      required { true }
    end

    trait :text do
      field_type { "text" }
      pdf_field_name { "FillText1" }
    end

    trait :checkbox do
      field_type { "checkbox" }
      pdf_field_name { "CheckBox1" }
    end

    trait :date do
      field_type { "date" }
      pdf_field_name { "DateField" }
    end

    trait :email do
      field_type { "email" }
      pdf_field_name { "EmailField" }
    end

    trait :tel do
      field_type { "tel" }
      pdf_field_name { "PhoneField" }
    end

    trait :currency do
      field_type { "currency" }
      pdf_field_name { "AmountField" }
    end

    trait :signature do
      field_type { "signature" }
      pdf_field_name { "SignatureField" }
    end

    trait :with_options do
      field_type { "select" }
      options { [ { value: "opt1", label: "Option 1" }, { value: "opt2", label: "Option 2" } ] }
    end

    trait :with_validation do
      validation_pattern { "^[A-Z]{2}-\\d{6}$" }
      max_length { 9 }
    end

    trait :conditional do
      conditions do
        {
          field: "other_field",
          operator: "equals",
          value: "yes"
        }
      end
    end
  end
end
