# frozen_string_literal: true

require "rails_helper"

RSpec.describe NextSteps::Guidance do
  subject(:guidance_service) { described_class.instance }

  before do
    # Reload config to ensure fresh state
    guidance_service.reload!
  end

  describe "#for_form" do
    context "with form-specific guidance" do
      let(:form_definition) { create(:form_definition, code: "SC-100") }

      it "returns form-specific guidance" do
        result = guidance_service.for_form(form_definition)

        expect(result[:title]).to eq("Filing Your Small Claims Case")
        expect(result[:intro]).to include("Plaintiff's Claim")
      end

      it "includes steps array" do
        result = guidance_service.for_form(form_definition)

        expect(result[:steps]).to be_an(Array)
        expect(result[:steps]).not_to be_empty
      end

      it "includes step with required attributes" do
        result = guidance_service.for_form(form_definition)
        first_step = result[:steps].first

        expect(first_step[:id]).to be_present
        expect(first_step[:title]).to be_present
        expect(first_step[:description]).to be_present
      end

      it "includes related forms" do
        result = guidance_service.for_form(form_definition)

        expect(result[:related_forms]).to be_an(Array)
      end

      it "includes resources" do
        result = guidance_service.for_form(form_definition)

        expect(result[:resources]).to be_an(Array)
      end
    end

    context "with category fallback" do
      let(:category) { create(:category, slug: "plaintiff") }
      let(:form_definition) do
        create(:form_definition, code: "SC-999", category: category)
      end

      it "returns category guidance when form-specific not found" do
        result = guidance_service.for_form(form_definition)

        expect(result[:steps]).to be_present
        # Category guidance should have filing step
        step_ids = result[:steps].pluck(:id)
        expect(step_ids).to include("file")
      end
    end

    context "with default fallback" do
      let(:form_definition) { create(:form_definition, code: "UNKNOWN-999") }

      it "returns default guidance" do
        result = guidance_service.for_form(form_definition)

        expect(result[:title]).to eq("What Happens Next?")
        expect(result[:steps]).to be_present
      end
    end

    context "with string form code" do
      it "accepts form code as string" do
        result = guidance_service.for_form("SC-100")

        expect(result[:title]).to be_present
      end
    end

    context "with submission conditionals" do
      let(:form_definition) { create(:form_definition, code: "SC-100") }
      let(:submission) { create(:submission, form_definition: form_definition) }

      before do
        allow(submission).to receive(:field_value).with("needs_fee_waiver").and_return(true)
        allow(submission).to receive(:field_value).with("!needs_fee_waiver").and_return(nil)
      end

      it "filters steps based on conditionals" do
        result = guidance_service.for_form(form_definition, submission)

        # Fee waiver step should be filtered out when needs_fee_waiver is true
        step_ids = result[:steps].pluck(:id)
        expect(step_ids).not_to include("pay_fee")
      end
    end
  end

  describe "#related_forms_for" do
    let(:form_definition) { create(:form_definition, code: "SC-100") }

    before do
      # Create related forms
      create(:form_definition, code: "SC-104", title: "Proof of Service")
      create(:form_definition, code: "SC-103", title: "Fee Waiver")
    end

    it "returns related forms with form objects" do
      result = guidance_service.related_forms_for(form_definition)

      expect(result).to be_an(Array)
      if result.any?
        expect(result.first[:form]).to be_a(FormDefinition)
        expect(result.first[:reason]).to be_present
      end
    end

    it "includes SC-104 as related form" do
      result = guidance_service.related_forms_for(form_definition)

      form_codes = result.map { |r| r[:form].code }
      expect(form_codes).to include("SC-104")
    end

    context "with conditional related forms" do
      let(:submission) { create(:submission, form_definition: form_definition) }

      before do
        allow(submission).to receive(:field_value).with("needs_fee_waiver").and_return(true)
      end

      it "includes conditional forms when condition is met" do
        result = guidance_service.related_forms_for(form_definition, submission)

        form_codes = result.map { |r| r[:form].code }
        expect(form_codes).to include("SC-103")
      end
    end

    context "without conditional field set" do
      let(:submission) { create(:submission, form_definition: form_definition) }

      before do
        allow(submission).to receive(:field_value).with("needs_fee_waiver").and_return(nil)
      end

      it "excludes conditional forms when condition is not met" do
        result = guidance_service.related_forms_for(form_definition, submission)

        form_codes = result.map { |r| r[:form].code }
        expect(form_codes).not_to include("SC-103")
      end
    end
  end

  describe "#reload!" do
    it "reloads the configuration" do
      expect { guidance_service.reload! }.not_to raise_error
    end
  end

  describe "build_step" do
    let(:form_definition) { create(:form_definition, code: "SC-100") }

    it "sets default icon when not specified" do
      result = guidance_service.for_form(form_definition)
      step_with_icon = result[:steps].find { |s| s[:icon].present? }

      expect(step_with_icon[:icon]).to be_present
    end

    it "marks steps as required by default" do
      result = guidance_service.for_form(form_definition)
      first_step = result[:steps].first

      expect(first_step[:required]).to be true
    end
  end

  describe "build_resource" do
    let(:form_definition) { create(:form_definition, code: "SC-100") }

    it "includes resource with title and url" do
      result = guidance_service.for_form(form_definition)

      if result[:resources].any?
        resource = result[:resources].first
        expect(resource[:title]).to be_present
        expect(resource[:url]).to be_present
      end
    end
  end
end
