# frozen_string_literal: true

require "rails_helper"

RSpec.describe NextStepsHelper, type: :helper do
  describe "#next_steps_guidance" do
    let(:form_definition) { create(:form_definition, code: "SC-100") }
    let(:submission) { create(:submission, form_definition: form_definition) }

    before do
      # Ensure related forms exist for the partial
      create(:form_definition, code: "SC-104", title: "Proof of Service")
    end

    it "renders the next steps partial" do
      result = helper.next_steps_guidance(form_definition)

      expect(result).to include("next-steps-guidance")
      # SC-100 has custom title "Filing Your Small Claims Case"
      expect(result).to include("Filing Your Small Claims Case")
    end

    it "includes steps in the output" do
      result = helper.next_steps_guidance(form_definition)

      expect(result).to include("data-next-steps-target=\"step\"")
    end

    it "includes form code data attribute" do
      result = helper.next_steps_guidance(form_definition)

      expect(result).to include("data-next-steps-form-code-value=\"SC-100\"")
    end

    it "accepts submission parameter" do
      result = helper.next_steps_guidance(form_definition, submission)

      expect(result).to be_present
    end
  end

  describe "#next_step_icon" do
    it "renders check-circle icon" do
      result = helper.next_step_icon("check-circle")

      expect(result).to include("<svg")
      expect(result).to include("M9 12.75L11.25 15 15 9.75")
    end

    it "renders printer icon" do
      result = helper.next_step_icon("printer")

      expect(result).to include("<svg")
      expect(result).to include("path")
    end

    it "renders building icon" do
      result = helper.next_step_icon("building")

      expect(result).to include("<svg")
    end

    it "renders mail icon" do
      result = helper.next_step_icon("mail")

      expect(result).to include("<svg")
    end

    it "renders calendar icon" do
      result = helper.next_step_icon("calendar")

      expect(result).to include("<svg")
    end

    it "renders credit-card icon" do
      result = helper.next_step_icon("credit-card")

      expect(result).to include("<svg")
    end

    it "renders clock icon" do
      result = helper.next_step_icon("clock")

      expect(result).to include("<svg")
    end

    it "renders copy icon" do
      result = helper.next_step_icon("copy")

      expect(result).to include("<svg")
    end

    it "renders file-check icon" do
      result = helper.next_step_icon("file-check")

      expect(result).to include("<svg")
    end

    it "renders folder icon" do
      result = helper.next_step_icon("folder")

      expect(result).to include("<svg")
    end

    it "renders x-circle icon" do
      result = helper.next_step_icon("x-circle")

      expect(result).to include("<svg")
    end

    it "renders lock icon" do
      result = helper.next_step_icon("lock")

      expect(result).to include("<svg")
    end

    it "renders dollar-sign icon" do
      result = helper.next_step_icon("dollar-sign")

      expect(result).to include("<svg")
    end

    it "renders default icon for unknown icon name" do
      result = helper.next_step_icon("unknown-icon")

      expect(result).to include("<svg")
      expect(result).to include("M4.5 12.75l6 6 9-13.5")
    end

    it "applies custom class" do
      result = helper.next_step_icon("check-circle", class: "w-10 h-10")

      expect(result).to include("w-10 h-10")
    end

    it "uses default class when not specified" do
      result = helper.next_step_icon("check-circle")

      expect(result).to include("w-6 h-6")
    end
  end
end
