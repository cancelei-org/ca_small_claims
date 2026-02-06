# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormFeedback, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:form_definition) }
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:resolved_by).class_name("User").optional }
  end

  describe "validations" do
    subject { build(:form_feedback) }

    it { is_expected.to validate_presence_of(:rating) }
    it { is_expected.to validate_inclusion_of(:rating).in_range(1..5) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[open in_progress resolved closed]) }
    it { is_expected.to validate_presence_of(:priority) }
    it { is_expected.to validate_inclusion_of(:priority).in_array(%w[low medium high urgent]) }
    it { is_expected.to validate_presence_of(:issue_types) }

    it "validates issue_types contains only valid types" do
      feedback = build(:form_feedback, issue_types: [ "invalid_type", "other" ])
      expect(feedback).not_to be_valid
      expect(feedback.errors[:issue_types]).to include(/contains invalid types: invalid_type/)
    end
  end

  describe "scopes" do
    let!(:open_fb) { create(:form_feedback, status: "open", rating: 5) }
    let!(:in_progress_fb) { create(:form_feedback, status: "in_progress", rating: 4) }
    let!(:resolved_fb) { create(:form_feedback, status: "resolved", rating: 1) }
    let!(:closed_fb) { create(:form_feedback, status: "closed", rating: 3) }

    describe ".open" do
      it { expect(FormFeedback.open).to contain_exactly(open_fb) }
    end

    describe ".in_progress" do
      it { expect(FormFeedback.in_progress).to contain_exactly(in_progress_fb) }
    end

    describe ".resolved" do
      it { expect(FormFeedback.resolved).to contain_exactly(resolved_fb) }
    end

    describe ".closed" do
      it { expect(FormFeedback.closed).to contain_exactly(closed_fb) }
    end

    describe ".active" do
      it { expect(FormFeedback.active).to contain_exactly(open_fb, in_progress_fb) }
    end

    describe ".completed" do
      it { expect(FormFeedback.completed).to contain_exactly(resolved_fb, closed_fb) }
    end

    # Legacy scope aliases
    describe ".pending (legacy alias for .open)" do
      it { expect(FormFeedback.pending).to contain_exactly(open_fb) }
    end

    describe ".acknowledged (legacy alias for .in_progress)" do
      it { expect(FormFeedback.acknowledged).to contain_exactly(in_progress_fb) }
    end

    describe ".unresolved (legacy alias for .active)" do
      it { expect(FormFeedback.unresolved).to contain_exactly(open_fb, in_progress_fb) }
    end

    describe ".low_rated" do
      it { expect(FormFeedback.low_rated).to contain_exactly(resolved_fb) }
    end

    describe ".by_issue_type" do
      let!(:pdf_issue) { create(:form_feedback, issue_types: [ "pdf_not_filling" ]) }
      it { expect(FormFeedback.by_issue_type("pdf_not_filling")).to include(pdf_issue) }
      it { expect(FormFeedback.by_issue_type("pdf_not_filling")).not_to include(open_fb) }
    end

    describe ".by_priority" do
      let!(:urgent) { create(:form_feedback, priority: "urgent") }
      let!(:low) { create(:form_feedback, priority: "low") }

      it { expect(FormFeedback.by_priority("urgent")).to include(urgent) }
      it { expect(FormFeedback.by_priority("urgent")).not_to include(low) }
    end

    describe ".high_or_urgent" do
      let!(:urgent) { create(:form_feedback, priority: "urgent") }
      let!(:high) { create(:form_feedback, priority: "high") }
      let!(:low) { create(:form_feedback, priority: "low") }

      it { expect(FormFeedback.high_or_urgent).to include(urgent, high) }
      it { expect(FormFeedback.high_or_urgent).not_to include(low) }
    end

    describe ".recent" do
      it "orders by created_at descending" do
        old_fb = create(:form_feedback)
        old_fb.update_column(:created_at, 2.days.ago)
        new_fb = create(:form_feedback)
        new_fb.update_column(:created_at, 1.hour.ago)

        results = FormFeedback.where(id: [ old_fb.id, new_fb.id ]).recent.to_a
        expect(results).to eq([ new_fb, old_fb ])
      end
    end

    describe ".by_form" do
      let(:form_def) { create(:form_definition) }
      let(:other_form) { create(:form_definition) }
      let!(:target_feedback) { create(:form_feedback, form_definition: form_def) }
      let!(:other_feedback) { create(:form_feedback, form_definition: other_form) }

      it "filters by form_definition_id" do
        expect(FormFeedback.by_form(form_def.id)).to include(target_feedback)
        expect(FormFeedback.by_form(form_def.id)).not_to include(other_feedback)
      end
    end

    describe ".created_between" do
      let!(:old_feedback) { create(:form_feedback, created_at: 10.days.ago) }
      let!(:recent_feedback) { create(:form_feedback, created_at: 2.days.ago) }

      it "filters by date range" do
        result = FormFeedback.created_between(5.days.ago, Time.current)
        expect(result).to include(recent_feedback)
        expect(result).not_to include(old_feedback)
      end
    end
  end

  describe "instance methods" do
    let(:feedback) { create(:form_feedback) }
    let(:admin) { create(:user) }

    describe "status query methods" do
      it "#open? returns true for open status" do
        feedback.status = "open"
        expect(feedback.open?).to be true
        expect(feedback.in_progress?).to be false
        expect(feedback.resolved?).to be false
        expect(feedback.closed?).to be false
      end

      it "#in_progress? returns true for in_progress status" do
        feedback.status = "in_progress"
        expect(feedback.in_progress?).to be true
        expect(feedback.open?).to be false
        expect(feedback.resolved?).to be false
      end

      it "#resolved? returns true for resolved status" do
        feedback.status = "resolved"
        expect(feedback.resolved?).to be true
        expect(feedback.open?).to be false
        expect(feedback.in_progress?).to be false
      end

      it "#closed? returns true for closed status" do
        feedback.status = "closed"
        expect(feedback.closed?).to be true
        expect(feedback.resolved?).to be false
      end

      it "#active? returns true for open or in_progress" do
        feedback.status = "open"
        expect(feedback.active?).to be true
        feedback.status = "in_progress"
        expect(feedback.active?).to be true
        feedback.status = "resolved"
        expect(feedback.active?).to be false
      end

      # Legacy aliases
      it "#pending? is an alias for #open?" do
        feedback.status = "open"
        expect(feedback.pending?).to be true
      end

      it "#acknowledged? is an alias for #in_progress?" do
        feedback.status = "in_progress"
        expect(feedback.acknowledged?).to be true
      end
    end

    describe "priority query methods" do
      it "#high_or_urgent? returns true for high or urgent" do
        feedback.priority = "high"
        expect(feedback.high_or_urgent?).to be true
        feedback.priority = "urgent"
        expect(feedback.high_or_urgent?).to be true
        feedback.priority = "medium"
        expect(feedback.high_or_urgent?).to be false
      end
    end

    describe "#start_progress!" do
      it "updates status to in_progress" do
        feedback.start_progress!
        expect(feedback.reload.status).to eq("in_progress")
      end
    end

    describe "#acknowledge! (legacy alias)" do
      it "updates status to in_progress" do
        feedback.acknowledge!
        expect(feedback.reload.status).to eq("in_progress")
      end
    end

    describe "#resolve!" do
      it "updates status and sets resolver info" do
        feedback.resolve!(admin, notes: "All good")
        expect(feedback.reload.status).to eq("resolved")
        expect(feedback.resolved_by).to eq(admin)
        expect(feedback.admin_notes).to eq("All good")
        expect(feedback.resolved_at).not_to be_nil
      end
    end

    describe "#close!" do
      it "updates status and sets resolver info" do
        feedback.close!(admin, notes: "Won't fix")
        expect(feedback.reload.status).to eq("closed")
        expect(feedback.resolved_by).to eq(admin)
        expect(feedback.admin_notes).to eq("Won't fix")
        expect(feedback.resolved_at).not_to be_nil
      end
    end

    describe "#reopen!" do
      it "resets to open and clears resolver info" do
        feedback.resolve!(admin)
        feedback.reopen!
        expect(feedback.reload.status).to eq("open")
        expect(feedback.resolved_by).to be_nil
        expect(feedback.resolved_at).to be_nil
      end
    end

    describe "#escalate!" do
      it "increases priority" do
        feedback.update!(priority: "low")
        feedback.escalate!
        expect(feedback.reload.priority).to eq("medium")
        feedback.escalate!
        expect(feedback.reload.priority).to eq("high")
        feedback.escalate!
        expect(feedback.reload.priority).to eq("urgent")
        # Should not go higher than urgent
        feedback.escalate!
        expect(feedback.reload.priority).to eq("urgent")
      end
    end

    describe "#de_escalate!" do
      it "decreases priority" do
        feedback.update!(priority: "urgent")
        feedback.de_escalate!
        expect(feedback.reload.priority).to eq("high")
        feedback.de_escalate!
        expect(feedback.reload.priority).to eq("medium")
        feedback.de_escalate!
        expect(feedback.reload.priority).to eq("low")
        # Should not go lower than low
        feedback.de_escalate!
        expect(feedback.reload.priority).to eq("low")
      end
    end

    describe "#issue_type_labels" do
      it "returns human readable labels" do
        feedback.issue_types = [ "pdf_not_filling", "other" ]
        expect(feedback.issue_type_labels).to contain_exactly("PDF not filling out correctly", "Other issue")
      end
    end

    describe "#rating_label" do
      it "returns correct label for rating" do
        expect(build(:form_feedback, rating: 5).rating_label).to eq("Excellent")
        expect(build(:form_feedback, rating: 1).rating_label).to eq("Very Poor")
      end
    end

    describe "#priority_label" do
      it "returns titleized priority" do
        feedback.priority = "high"
        expect(feedback.priority_label).to eq("High")
      end
    end

    describe "#status_label" do
      it "returns human readable status" do
        feedback.status = "in_progress"
        expect(feedback.status_label).to eq("In Progress")
      end
    end

    describe "#submitted_by" do
      it "returns user display name if user present" do
        user = create(:user, full_name: "John Doe")
        feedback = build(:form_feedback, user: user)
        expect(feedback.submitted_by).to eq("John Doe")
      end

      it "returns anonymous with session snippet if no user" do
        feedback = build(:form_feedback, user: nil, session_id: "1234567890abcdef")
        expect(feedback.submitted_by).to include("Anonymous (12345678...)")
      end
    end
  end
end
