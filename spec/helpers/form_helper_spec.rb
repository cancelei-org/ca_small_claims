# frozen_string_literal: true

require "rails_helper"

RSpec.describe FormHelper, type: :helper do
  let(:field) { build(:field_definition, name: "test_field", label: "Test Label", help_text: "Help me", required: true) }

  describe "#field_help_id" do
    it { expect(helper.field_help_id(field)).to eq("test_field-help") }
  end

  describe "#field_error_id" do
    it { expect(helper.field_error_id(field)).to eq("test_field-error") }
  end

  describe "#field_aria_attributes" do
    it "includes describedby and required" do
      attrs = helper.field_aria_attributes(field)
      expect(attrs[:"aria-describedby"]).to include("test_field-help")
      expect(attrs[:"aria-describedby"]).to include("test_field-error")
      expect(attrs[:"aria-required"]).to eq("true")
    end
  end

  describe "#field_wrapper" do
    it "renders the wrapper, label, and help hints" do
      html = helper.field_wrapper(field) { "INPUT" }
      expect(html).to have_css(".form-control")
      expect(html).to have_css("label.label")
      expect(html).to have_content("Test Label")
      expect(html).to have_content("INPUT")
    end
  end

  describe "#field_help_hint" do
    it "renders hint for a field with config" do
      # Case number has config in field_help.yml
      case_field = build(:field_definition, name: "case_number", field_type: "text")
      html = helper.field_help_hint(case_field)
      expect(html).to have_css("p.text-xs")
      expect(html).to have_content("Format:")
    end
  end

  describe "#stuck_get_help_button" do
    it "renders a button for a field with FAQ mapping" do
      case_field = build(:field_definition, name: "case_number")
      html = helper.stuck_get_help_button(case_field)
      expect(html).to have_css("button[data-action='click->faq#open']")
      expect(html).to have_content("Stuck?")
    end
  end

  describe "#standard_input_class" do
    it { expect(helper.standard_input_class).to include("input input-bordered") }
  end
end
