# frozen_string_literal: true

require "rails_helper"

RSpec.describe Users::ActivityTimeline do
  let(:user) { create(:user) }
  let(:category) { create(:category) }
  let(:form_def) { create(:form_definition, code: "SC-100", category: category) }

  describe "#activities" do
    it "includes account creation activity" do
      timeline = described_class.new(user)

      expect(timeline.activities).to include(
        hash_including(type: "account_created", title: "Account created")
      )
    end

    it "includes submission created activity" do
      create(:submission, user: user, form_definition: form_def)

      timeline = described_class.new(user)

      expect(timeline.activities).to include(
        hash_including(type: "submission_created")
      )
    end

    it "includes submission completed activity when completion differs from creation" do
      submission = create(:submission, user: user, form_definition: form_def)
      submission.update!(completed_at: 1.hour.from_now)

      timeline = described_class.new(user)

      expect(timeline.activities).to include(
        hash_including(type: "submission_completed")
      )
    end

    it "does not include submission completed when same as creation" do
      submission = create(:submission, user: user, form_definition: form_def, completed_at: nil)
      submission.update!(completed_at: submission.created_at)

      timeline = described_class.new(user)

      expect(timeline.activities).not_to include(
        hash_including(type: "submission_completed")
      )
    end

    it "includes submission updated activity for significant updates" do
      submission = create(:submission, user: user, form_definition: form_def)
      submission.update!(updated_at: submission.created_at + 2.minutes, form_data: { test: "data" })

      timeline = described_class.new(user)

      expect(timeline.activities).to include(
        hash_including(type: "submission_updated")
      )
    end

    it "does not include submission updated for minor updates within 1 minute" do
      submission = create(:submission, user: user, form_definition: form_def)
      # Updated within 1 minute should not trigger update activity
      submission.update_columns(updated_at: submission.created_at + 30.seconds)

      timeline = described_class.new(user)

      expect(timeline.activities).not_to include(
        hash_including(type: "submission_updated")
      )
    end

    it "includes feedback submitted activity" do
      create(:form_feedback, user: user, form_definition: form_def)

      timeline = described_class.new(user)

      expect(timeline.activities).to include(
        hash_including(type: "feedback_submitted")
      )
    end

    it "includes profile updated activity when profile is complete and updated" do
      user.update!(
        full_name: "John Doe",
        phone: "555-1234",
        address: "123 Main St",
        city: "Los Angeles",
        state: "CA",
        zip_code: "90001",
        updated_at: user.created_at + 2.minutes
      )

      timeline = described_class.new(user.reload)

      expect(timeline.activities).to include(
        hash_including(type: "profile_updated")
      )
    end

    it "does not include profile updated when profile is incomplete" do
      user.update!(full_name: "John", updated_at: user.created_at + 2.minutes)

      timeline = described_class.new(user.reload)

      expect(timeline.activities).not_to include(
        hash_including(type: "profile_updated")
      )
    end

    it "sorts activities by timestamp descending" do
      create(:submission, user: user, form_definition: form_def)
      create(:form_feedback, user: user, form_definition: form_def, created_at: 1.hour.ago)

      timeline = described_class.new(user)
      timestamps = timeline.activities.map { |a| a[:timestamp] }

      expect(timestamps).to eq(timestamps.sort.reverse)
    end

    it "respects limit parameter" do
      create_list(:submission, 10, user: user, form_definition: form_def)

      timeline = described_class.new(user, limit: 5)

      expect(timeline.activities.count).to eq(5)
    end

    it "respects offset parameter" do
      create_list(:submission, 5, user: user, form_definition: form_def)

      full_timeline = described_class.new(user)
      offset_timeline = described_class.new(user, offset: 2)

      expect(offset_timeline.activities.first).to eq(full_timeline.activities[2])
    end
  end

  describe "#total_count" do
    it "returns total count of all activities" do
      create_list(:submission, 3, user: user, form_definition: form_def)
      create_list(:form_feedback, 2, user: user, form_definition: form_def)

      timeline = described_class.new(user)

      # 3 submissions (created) + 2 feedbacks + 1 account_created = 6 minimum
      expect(timeline.total_count).to be >= 6
    end

    it "returns total count regardless of limit" do
      create_list(:submission, 10, user: user, form_definition: form_def)

      timeline = described_class.new(user, limit: 5)

      expect(timeline.total_count).to be >= 10
      expect(timeline.activities.count).to eq(5)
    end
  end

  describe "activity metadata" do
    it "includes submission metadata" do
      submission = create(:submission, user: user, form_definition: form_def)

      timeline = described_class.new(user)
      activity = timeline.activities.find { |a| a[:type] == "submission_created" }

      expect(activity[:metadata]).to include(
        submission_id: submission.id,
        form_code: "SC-100"
      )
    end

    it "includes feedback metadata" do
      feedback = create(:form_feedback, user: user, form_definition: form_def, rating: 4)

      timeline = described_class.new(user)
      activity = timeline.activities.find { |a| a[:type] == "feedback_submitted" }

      expect(activity[:metadata]).to include(
        feedback_id: feedback.id,
        form_code: "SC-100",
        rating: 4
      )
    end

    it "includes user metadata for account creation" do
      timeline = described_class.new(user)
      activity = timeline.activities.find { |a| a[:type] == "account_created" }

      expect(activity[:metadata]).to include(
        user_id: user.id,
        guest: user.guest?
      )
    end
  end

  describe "guest user handling" do
    let(:guest_user) { create(:user, :guest) }

    it "labels guest account correctly" do
      timeline = described_class.new(guest_user)
      activity = timeline.activities.find { |a| a[:type] == "account_created" }

      expect(activity[:description]).to eq("Guest account")
      expect(activity[:metadata][:guest]).to be true
    end
  end
end
