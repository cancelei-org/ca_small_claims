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
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[pending acknowledged resolved]) }
    it { is_expected.to validate_presence_of(:issue_types) }

    it "validates issue_types contains only valid types" do
      feedback = build(:form_feedback, issue_types: [ "invalid_type", "other" ])
      expect(feedback).not_to be_valid
      expect(feedback.errors[:issue_types]).to include(/contains invalid types: invalid_type/)
    end
  end

  describe "scopes" do
    let!(:pending) { create(:form_feedback, status: "pending", rating: 5) }
    let!(:acknowledged) { create(:form_feedback, status: "acknowledged", rating: 4) }
    let!(:resolved) { create(:form_feedback, status: "resolved", rating: 1) }

    describe ".pending" do
      it { expect(FormFeedback.pending).to contain_exactly(pending) }
    end

    describe ".acknowledged" do
      it { expect(FormFeedback.acknowledged).to contain_exactly(acknowledged) }
    end

    describe ".resolved" do
      it { expect(FormFeedback.resolved).to contain_exactly(resolved) }
    end

    describe ".unresolved" do
      it { expect(FormFeedback.unresolved).to contain_exactly(pending, acknowledged) }
    end

    describe ".low_rated" do
      it { expect(FormFeedback.low_rated).to contain_exactly(resolved) }
    end

    describe ".by_issue_type" do
      let!(:pdf_issue) { create(:form_feedback, issue_types: [ "pdf_not_filling" ]) }
      it { expect(FormFeedback.by_issue_type("pdf_not_filling")).to include(pdf_issue) }
      it { expect(FormFeedback.by_issue_type("pdf_not_filling")).not_to include(pending) }
    end
  end

  describe "instance methods" do
    let(:feedback) { create(:form_feedback) }
    let(:admin) { create(:user) }

    describe "#acknowledge!" do
      it "updates status to acknowledged" do
        feedback.acknowledge!
        expect(feedback.reload.status).to eq("acknowledged")
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
