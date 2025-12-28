# frozen_string_literal: true

FactoryBot.define do
  factory :category do
    sequence(:name) { |n| "Category #{n}" }
    sequence(:slug) { |n| "category-#{n}" }
    description { "Test category description" }
    position { 1 }
    active { true }

    trait :small_claims do
      name { "Small Claims" }
      slug { "sc" }
      description { "Small claims court forms" }
      position { 1 }
    end

    trait :family_law do
      name { "Family Law" }
      slug { "fl" }
      description { "Family law forms" }
      position { 10 }
    end

    trait :inactive do
      active { false }
    end

    trait :with_parent do
      association :parent, factory: :category
    end
  end
end
