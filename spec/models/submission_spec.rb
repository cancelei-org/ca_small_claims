# frozen_string_literal: true

require "rails_helper"

RSpec.describe Submission, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:user).optional }
    it { is_expected.to belong_to(:form_definition) }
    it { is_expected.to belong_to(:workflow).optional }
  end

  describe "validations" do
    it { is_expected.to validate_inclusion_of(:status).in_array(%w[draft completed submitted]) }
  end

  describe "scopes" do
    let!(:draft) { create(:submission, status: "draft") }
    let!(:completed) { create(:submission, status: "completed") }
    let!(:submitted) { create(:submission, status: "submitted") }

    it ".drafts" do
      expect(Submission.drafts).to contain_exactly(draft)
    end

    it ".completed" do
      expect(Submission.completed).to contain_exactly(completed)
    end

    it ".submitted" do
      expect(Submission.submitted).to contain_exactly(submitted)
    end
  end

  describe "instance methods" do
    let(:submission) { create(:submission) }

    describe "#anonymous?" do
      it "returns true if user_id is nil" do
        submission.user = nil
        expect(submission.anonymous?).to be true
      end

      it "returns false if user is present" do
        expect(submission.anonymous?).to be false
      end
    end

    describe "#complete!" do
      it "updates status and completed_at" do
        submission.complete!
        expect(submission.status).to eq("completed")
        expect(submission.completed_at).not_to be_nil
      end
    end

    describe "#submit!" do
      it "updates status" do
        submission.submit!
        expect(submission.status).to eq("submitted")
      end
    end

    describe "#pdf_cache_key" do
      it "generates a key based on id and form_data" do
        submission.form_data = { "a" => 1 }
        key1 = submission.pdf_cache_key
        submission.form_data = { "a" => 2 }
        key2 = submission.pdf_cache_key
        expect(key1).not_to eq(key2)
      end
    end

    describe "#completion_percentage" do
      let(:form) { create(:form_definition) }
      let!(:f1) { create(:field_definition, form_definition: form, required: true, name: "f1") }
      let!(:f2) { create(:field_definition, form_definition: form, required: true, name: "f2") }
      let(:submission) { create(:submission, form_definition: form) }

      it "returns 0 if none filled" do
        expect(submission.completion_percentage).to eq(0)
      end

      it "returns 50 if one of two filled" do
        submission.form_data = { "f1" => "val" }
        expect(submission.completion_percentage).to eq(50)
      end

      it "returns 100 if all filled" do
        submission.form_data = { "f1" => "val", "f2" => "val" }
        expect(submission.completion_percentage).to eq(100)
      end
    end
  end
end
