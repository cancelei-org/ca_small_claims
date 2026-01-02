# frozen_string_literal: true

require "rails_helper"

RSpec.describe Workflows::Engine do
  let(:workflow) { create(:workflow) }
  let(:form1) { create(:form_definition, code: "F1") }
  let(:form2) { create(:form_definition, code: "F2") }
  let!(:step1) { create(:workflow_step, workflow: workflow, form_definition: form1, position: 1) }
  let!(:step2) { create(:workflow_step, workflow: workflow, form_definition: form2, position: 2) }
  let(:session_id) { "test-session" }
  let(:engine) { described_class.new(workflow, session_id: session_id) }

  describe "#start" do
    it "creates the first submission" do
      expect { engine.start }.to change(Submission, :count).by(1)
      submission = Submission.last
      expect(submission.form_definition).to eq(form1)
      expect(submission.status).to eq("draft")
    end

    it "returns nil if no steps" do
      workflow.workflow_steps.destroy_all
      expect(engine.start).to be_nil
    end
  end

  describe "#current_submission" do
    it "returns the latest draft submission" do
      engine.start
      expect(engine.current_submission.form_definition).to eq(form1)
    end
  end

  describe "#advance" do
    before { engine.start }

    it "completes current step and moves to next" do
      expect { engine.advance }.to change(Submission, :count).by(1)

      prev_sub = Submission.find_by(workflow_step_position: 1)
      expect(prev_sub.status).to eq("completed")

      new_sub = engine.current_submission
      expect(new_sub.form_definition).to eq(form2)
      expect(new_sub.workflow_step_position).to eq(2)
    end

    it "updates form data before completing" do
      engine.advance({ "field1" => "value1" })
      sub = Submission.find_by(workflow_step_position: 1)
      expect(sub.form_data["field1"]).to eq("value1")
    end

    context "with conditional steps" do
      let!(:step3) { create(:workflow_step, workflow: workflow, position: 3, conditions: { "field" => "skip", "operator" => "not_equals", "value" => "yes" }) }

      it "skips steps that don't meet conditions" do
        # Step 1 -> Step 2
        engine.advance

        # Step 2 -> Step 3 (should skip if data matches)
        # Mocking shared_data or setting data in current sub
        engine.current_submission.update!(form_data: { "skip" => "yes" })

        # In Engine#advance, shared_data includes completed submissions
        # So we need to make sure previous subs are completed
        Submission.where(workflow_step_position: [ 1, 2 ]).update_all(status: "completed")

        # Since step 3 has condition skip != yes, and we set skip = yes, it should be skipped
        expect(engine.advance).to be_nil
      end
    end
  end

  describe "#go_back" do
    it "reopens previous submission as draft" do
      engine.start
      engine.advance

      expect(engine.current_submission.workflow_step_position).to eq(2)

      engine.go_back
      expect(engine.current_submission.workflow_step_position).to eq(1)
      expect(Submission.find_by(workflow_step_position: 1).status).to eq("draft")
    end
  end

  describe "#progress" do
    it "returns progress hash" do
      engine.start
      p = engine.progress
      expect(p[:total_steps]).to eq(2)
      expect(p[:completed_steps]).to eq(0)

      engine.advance
      p = engine.progress
      expect(p[:completed_steps]).to eq(1)
      expect(p[:percentage]).to eq(50)
    end
  end

  describe "#complete?" do
    it "returns true when all required steps are completed" do
      step1.update!(required: true)
      step2.update!(required: false)

      engine.start
      expect(engine.complete?).to be false

      engine.advance
      expect(engine.complete?).to be true
    end
  end

  describe "data prefilling" do
    it "prefills data from shared field keys" do
      # Setup form1 with shared key
      create(:field_definition, form_definition: form1, name: "f1", shared_field_key: "user_name")
      # Setup form2 with same shared key
      create(:field_definition, form_definition: form2, name: "f2", shared_field_key: "user_name")

      engine.start
      engine.current_submission.update!(form_data: { "f1" => "Alice" })

      engine.advance
      expect(engine.current_submission.form_data["f2"]).to eq("Alice")
    end
  end
end
