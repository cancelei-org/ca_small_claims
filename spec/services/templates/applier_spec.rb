# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::Applier do
  let(:form_definition) { create(:form_definition, code: "SC-100") }
  let(:submission) { create(:submission, form_definition: form_definition, form_data: {}) }

  describe "#apply" do
    context "with valid template" do
      let(:applier) do
        described_class.new(
          template_id: "auto_accident",
          submission: submission
        )
      end

      it "applies template prefills to submission" do
        result = applier.apply

        expect(result[:success]).to be true
        expect(result[:applied_fields]).to include("claim_basis", "claim_description")
      end

      it "stores template metadata in form_data" do
        applier.apply
        submission.reload

        metadata = submission.form_data["_template_metadata"]
        expect(metadata).to be_present
        expect(metadata["template_id"]).to eq("auto_accident")
        expect(metadata["template_name"]).to eq("Auto Accident")
        expect(metadata["applied_at"]).to be_present
      end

      it "sets claim_basis to auto_accident" do
        applier.apply
        submission.reload

        expect(submission.form_data["claim_basis"]).to eq("auto_accident")
      end

      it "includes tips in the result" do
        result = applier.apply

        expect(result[:tips]).to be_an(Array)
        expect(result[:tips]).not_to be_empty
      end

      it "includes related forms in the result" do
        result = applier.apply

        expect(result[:related_forms]).to be_an(Array)
      end
    end

    context "with customizations" do
      let(:applier) do
        described_class.new(
          template_id: "landlord_dispute",
          submission: submission,
          customizations: { dispute_type: "security_deposit" }
        )
      end

      it "applies prefills based on customization" do
        result = applier.apply

        expect(result[:success]).to be true
        submission.reload
        expect(submission.form_data["claim_basis"]).to eq("security_deposit")
      end

      it "stores customizations in metadata" do
        applier.apply
        submission.reload

        metadata = submission.form_data["_template_metadata"]
        expect(metadata["customizations"]).to eq({ "dispute_type" => "security_deposit" })
      end
    end

    context "with existing form data" do
      let(:submission) do
        create(:submission,
               form_definition: form_definition,
               form_data: { "plaintiff_name" => "John Doe" })
      end

      let(:applier) do
        described_class.new(
          template_id: "auto_accident",
          submission: submission
        )
      end

      it "does not overwrite existing data" do
        applier.apply
        submission.reload

        expect(submission.form_data["plaintiff_name"]).to eq("John Doe")
      end

      it "still applies template fields that were empty" do
        applier.apply
        submission.reload

        expect(submission.form_data["claim_basis"]).to eq("auto_accident")
      end
    end

    context "with invalid template" do
      let(:applier) do
        described_class.new(
          template_id: "nonexistent",
          submission: submission
        )
      end

      it "returns error result" do
        result = applier.apply

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Template not found")
      end
    end

    context "without submission" do
      let(:applier) do
        described_class.new(
          template_id: "auto_accident",
          submission: nil
        )
      end

      it "returns error result" do
        result = applier.apply

        expect(result[:success]).to be false
        expect(result[:errors]).to include("Submission required")
      end
    end
  end

  describe "#tips" do
    let(:applier) do
      described_class.new(
        template_id: "landlord_dispute",
        submission: submission
      )
    end

    it "returns tips for the template" do
      tips = applier.tips

      expect(tips).to be_an(Array)
      expect(tips.first).to include(:title, :content)
    end
  end

  describe "#related_forms" do
    let(:applier) do
      described_class.new(
        template_id: "auto_accident",
        submission: submission
      )
    end

    it "returns related forms for the template" do
      forms = applier.related_forms

      expect(forms).to be_an(Array)
      expect(forms.first).to include(:code, :reason)
    end
  end

  describe "#customization_questions" do
    let(:applier) do
      described_class.new(
        template_id: "landlord_dispute",
        submission: submission
      )
    end

    it "returns customization questions" do
      questions = applier.customization_questions

      expect(questions).to be_an(Array)
      expect(questions.first).to include(:id, :question, :type, :options)
    end
  end
end
