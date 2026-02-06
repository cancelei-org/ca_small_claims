# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    full_name { "Test User" }
    guest { false }
    admin { false }

    trait :admin do
      admin { true }
      role { "admin" }
      full_name { "Admin User" }
    end

    trait :super_admin do
      admin { true }
      role { "super_admin" }
      full_name { "Super Admin User" }
    end

    trait :guest do
      guest { true }
      email { "guest_#{SecureRandom.hex(4)}@example.com" }
    end

    trait :with_profile do
      full_name { "Jane Doe" }
      address { "123 Main St" }
      city { "Sacramento" }
      state { "CA" }
      zip_code { "95814" }
      phone { "555-0123" }
      date_of_birth { Date.new(1990, 5, 15) }
    end
  end
end
