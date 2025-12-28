# frozen_string_literal: true

FactoryBot.define do
  factory :form_definition do
    sequence(:code) { |n| "TEST-#{n}" }
    sequence(:title) { |n| "Test Form #{n}" }
    description { "A test form for specs" }
    pdf_filename { "#{code.downcase.gsub('-', '')}.pdf" }
    fillable { true }
    active { true }
    position { 1 }
    page_count { 1 }
    metadata { {} }
    association :category

    trait :small_claims do
      sequence(:code) { |n| "SC-#{100 + n}" }
      title { "Small Claims Form" }
      association :category, :small_claims
    end

    trait :family_law do
      sequence(:code) { |n| "FL-#{100 + n}" }
      title { "Family Law Form" }
      association :category, :family_law
    end

    trait :non_fillable do
      fillable { false }
    end

    trait :inactive do
      active { false }
    end

    trait :with_fields do
      after(:create) do |form|
        create_list(:field_definition, 5, form_definition: form)
      end
    end

    trait :with_metadata do
      metadata do
        {
          file_size: 100_000,
          total_fields: 15,
          pii_fields: 2,
          imported_at: Time.current.iso8601
        }
      end
    end
  end
end
