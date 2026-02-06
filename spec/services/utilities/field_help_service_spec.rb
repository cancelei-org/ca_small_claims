# frozen_string_literal: true

require "rails_helper"

RSpec.describe Utilities::FieldHelpService do
  let(:service) { described_class.instance }

  describe "#help_for" do
    it "returns help info for a known field type" do
      info = service.help_for("some_field", field_type: "date")
      expect(info[:format_hint]).to include("MM/DD/YYYY")
    end

    it "returns overrides for a specific field key" do
      info = service.help_for("case_number")
      expect(info[:example]).to eq("24STSC12345")
    end
  end

  describe "#friendly_error" do
    it "returns a friendly message for a technical error" do
      expect(service.friendly_error("can't be blank")).to eq("This field is required")
    end
  end

  describe "#retry_suggestions" do
    it "returns suggestions for a field type" do
      suggestions = service.retry_suggestions("phone")
      expect(suggestions).to be_an(Array)
      expect(suggestions.first[:mistake]).to include("7 digits")
    end
  end

  describe "#faq_anchor" do
    it "returns the mapped anchor for a field key" do
      expect(service.faq_anchor("case_number")).to eq("which-form")
    end
  end
end
