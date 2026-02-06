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

    describe ".for_session" do
      let!(:session_submission) { create(:submission, session_id: "abc123") }
      let!(:other_submission) { create(:submission, session_id: "other") }

      it "returns submissions for a specific session" do
        expect(Submission.for_session("abc123")).to contain_exactly(session_submission)
      end
    end

    describe ".in_workflow" do
      let!(:workflow_submission) { create(:submission, workflow_session_id: "wf-123") }
      let!(:other_submission) { create(:submission, workflow_session_id: nil) }

      it "returns submissions for a specific workflow session" do
        expect(Submission.in_workflow("wf-123")).to contain_exactly(workflow_submission)
      end
    end

    describe ".recent" do
      it "orders by updated_at descending" do
        old_sub = create(:submission)
        old_sub.update_column(:updated_at, 2.days.ago)
        new_sub = create(:submission)
        new_sub.update_column(:updated_at, 1.hour.ago)

        results = Submission.where(id: [ old_sub.id, new_sub.id ]).recent.to_a
        expect(results).to eq([ new_sub, old_sub ])
      end
    end
  end

  describe ".find_or_create_for" do
    let(:form_def) { create(:form_definition) }
    let(:user) { create(:user) }
    let(:workflow) { create(:workflow) }

    context "with user" do
      it "creates new submission for user" do
        expect {
          Submission.find_or_create_for(form_definition: form_def, user: user)
        }.to change(Submission, :count).by(1)
      end

      it "finds existing draft submission for user" do
        existing = create(:submission, form_definition: form_def, user: user, status: "draft")
        result = Submission.find_or_create_for(form_definition: form_def, user: user)
        expect(result).to eq(existing)
      end

      it "creates new submission if existing is completed" do
        create(:submission, form_definition: form_def, user: user, status: "completed")
        expect {
          Submission.find_or_create_for(form_definition: form_def, user: user)
        }.to change(Submission, :count).by(1)
      end
    end

    context "with session_id (anonymous)" do
      it "creates new submission with session_id" do
        result = Submission.find_or_create_for(form_definition: form_def, session_id: "anon-123")
        expect(result.session_id).to eq("anon-123")
      end

      it "finds existing draft submission by session_id" do
        existing = create(:submission, form_definition: form_def, session_id: "anon-123", status: "draft")
        result = Submission.find_or_create_for(form_definition: form_def, session_id: "anon-123")
        expect(result).to eq(existing)
      end
    end

    context "with workflow" do
      it "creates submission with workflow association" do
        result = Submission.find_or_create_for(form_definition: form_def, user: user, workflow: workflow)
        expect(result.workflow).to eq(workflow)
        expect(result.workflow_session_id).to be_present
      end
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

    describe "status query methods" do
      it "#draft? returns true for draft status" do
        submission.status = "draft"
        expect(submission.draft?).to be true
        expect(submission.completed?).to be false
      end

      it "#completed? returns true for completed status" do
        submission.status = "completed"
        expect(submission.completed?).to be true
        expect(submission.draft?).to be false
      end

      it "#submitted? returns true for submitted status" do
        submission.status = "submitted"
        expect(submission.submitted?).to be true
        expect(submission.draft?).to be false
      end
    end

    describe "#pdf_cache_valid?" do
      it "returns false if pdf_generated_at is nil" do
        submission.pdf_generated_at = nil
        expect(submission.pdf_cache_valid?).to be false
      end

      it "returns false if pdf generated before last update" do
        submission.update!(pdf_generated_at: 1.minute.ago, updated_at: 30.seconds.ago)
        expect(submission.pdf_cache_valid?).to be false
      end

      it "returns false if pdf generated too long ago" do
        submission.update!(pdf_generated_at: 20.seconds.ago, updated_at: 30.seconds.ago)
        expect(submission.pdf_cache_valid?).to be false
      end

      it "returns true if pdf recently generated after update" do
        submission.update!(updated_at: 5.seconds.ago)
        submission.update_column(:pdf_generated_at, 2.seconds.ago)
        expect(submission.pdf_cache_valid?).to be true
      end
    end

    describe "#mark_pdf_generated!" do
      it "updates pdf_generated_at timestamp" do
        expect(submission.pdf_generated_at).to be_nil
        submission.mark_pdf_generated!
        expect(submission.pdf_generated_at).to be_within(1.second).of(Time.current)
      end
    end

    describe "#shared_data" do
      let(:form) { create(:form_definition) }
      let!(:shared_field) { create(:field_definition, form_definition: form, name: "plaintiff_name", shared_field_key: "plaintiff_name") }
      let!(:non_shared_field) { create(:field_definition, form_definition: form, name: "case_notes", shared_field_key: nil) }
      let(:submission) { create(:submission, form_definition: form, form_data: { "plaintiff_name" => "John Doe", "case_notes" => "Test" }) }

      it "returns only shared fields with values" do
        shared = submission.shared_data
        expect(shared["plaintiff_name"]).to eq("John Doe")
        expect(shared).not_to have_key("case_notes")
      end

      it "excludes blank shared field values" do
        submission.form_data = { "plaintiff_name" => "", "case_notes" => "Test" }
        expect(submission.shared_data).to be_empty
      end
    end

    describe "#generate_pdf" do
      it "delegates to Pdf::FormFiller" do
        form_filler = instance_double(Pdf::FormFiller)
        allow(Pdf::FormFiller).to receive(:new).with(submission).and_return(form_filler)
        allow(form_filler).to receive(:generate).and_return("/path/to/pdf")

        expect(submission.generate_pdf).to eq("/path/to/pdf")
      end
    end

    describe "#generate_flattened_pdf" do
      it "delegates to Pdf::FormFiller" do
        form_filler = instance_double(Pdf::FormFiller)
        allow(Pdf::FormFiller).to receive(:new).with(submission).and_return(form_filler)
        allow(form_filler).to receive(:generate_flattened).and_return("/path/to/flat.pdf")

        expect(submission.generate_flattened_pdf).to eq("/path/to/flat.pdf")
      end
    end
  end

  describe "callbacks" do
    describe "before_create :set_defaults" do
      let(:workflow) { create(:workflow) }
      let(:form_def) { create(:form_definition) }

      it "sets workflow_session_id when workflow is present" do
        submission = create(:submission, form_definition: form_def, workflow: workflow)
        expect(submission.workflow_session_id).to be_present
      end

      it "does not set workflow_session_id when workflow is absent" do
        submission = create(:submission, form_definition: form_def, workflow: nil)
        expect(submission.workflow_session_id).to be_nil
      end
    end

    describe "after_commit :enqueue_webhook_events" do
      let(:form_def) { create(:form_definition, code: "SC-100") }
      let(:dispatcher) { instance_double(Webhooks::Dispatcher) }

      before do
        allow(Webhooks::Dispatcher).to receive(:new).and_return(dispatcher)
        allow(dispatcher).to receive(:deliver)
      end

      it "dispatches webhook on create" do
        submission = create(:submission, form_definition: form_def)

        expect(dispatcher).to have_received(:deliver).with(
          event: "submission.saved",
          payload: hash_including(
            id: submission.id,
            form_code: "SC-100"
          )
        )
      end

      it "dispatches webhook on update" do
        submission = create(:submission, form_definition: form_def)

        submission.update!(status: "completed")

        expect(dispatcher).to have_received(:deliver).at_least(:twice)
      end
    end
  end
end
