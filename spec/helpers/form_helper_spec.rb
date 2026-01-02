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
    it "renders the wrapper and label" do
      html = helper.field_wrapper(field) { "INPUT" }
      expect(html).to have_css(".form-control")
      expect(html).to have_css("label.label")
      expect(html).to have_content("Test Label")
      expect(html).to have_content("INPUT")
    end
  end

  describe "#standard_input_class" do
    it { expect(helper.standard_input_class).to include("input input-bordered") }
  end
end
