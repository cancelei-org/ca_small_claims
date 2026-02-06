# frozen_string_literal: true

FactoryBot.define do
  factory :product_feedback do
    association :user

    category { :general }
    title { Faker::Lorem.sentence(word_count: 5) }
    description { Faker::Lorem.paragraph(sentence_count: 3) }
    status { :pending }

    trait :general do
      category { :general }
      title { "General feedback about the platform" }
    end

    trait :bug do
      category { :bug }
      title { "Bug: #{Faker::Lorem.sentence(word_count: 4)}" }
      description { "Steps to reproduce:\n1. #{Faker::Lorem.sentence}\n2. #{Faker::Lorem.sentence}\n\nExpected: #{Faker::Lorem.sentence}\nActual: #{Faker::Lorem.sentence}" }
    end

    trait :feature do
      category { :feature }
      title { "Feature Request: #{Faker::Lorem.sentence(word_count: 4)}" }
    end

    trait :partnership do
      category { :partnership }
      title { "Partnership Inquiry from #{Faker::Company.name}" }
    end

    trait :pending do
      status { :pending }
    end

    trait :under_review do
      status { :under_review }
    end

    trait :planned do
      status { :planned }
    end

    trait :in_progress do
      status { :in_progress }
    end

    trait :completed do
      status { :completed }
    end

    trait :declined do
      status { :declined }
    end

    trait :with_votes do
      transient do
        vote_count { 5 }
      end

      after(:create) do |feedback, evaluator|
        evaluator.vote_count.times do
          create(:product_feedback_vote, product_feedback: feedback)
        end
        feedback.reload
      end
    end

    trait :with_admin_notes do
      admin_notes { "Internal note: #{Faker::Lorem.sentence}" }
    end

    trait :with_attachments do
      after(:build) do |feedback|
        feedback.attachments.attach(
          io: StringIO.new("fake image content"),
          filename: "screenshot.png",
          content_type: "image/png"
        )
      end
    end
  end
end
