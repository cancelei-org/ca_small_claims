# frozen_string_literal: true

require "rails_helper"

RSpec.describe FieldDefinition, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:form_definition) }
  end

  describe "validations" do
    subject { build(:field_definition) }

    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:form_definition_id) }
    it { is_expected.to validate_presence_of(:pdf_field_name) }
    it { is_expected.to validate_presence_of(:field_type) }

    it { is_expected.to validate_inclusion_of(:field_type).in_array(%w[
      text textarea tel email date currency number
      checkbox checkbox_group radio select
      signature repeating_group address hidden readonly
    ]) }
  end

  describe "scopes" do
    let(:form) { create(:form_definition) }
    let!(:required_field) { create(:field_definition, form_definition: form, required: true, section: "info", position: 2, page_number: 1) }
    let!(:optional_field) { create(:field_definition, form_definition: form, required: false, section: "other", position: 1, page_number: 2) }

    describe ".required" do
      it "returns only required fields" do
        expect(FieldDefinition.required).to include(required_field)
        expect(FieldDefinition.required).not_to include(optional_field)
      end
    end

    describe ".in_section" do
      it "returns fields in specific section" do
        expect(FieldDefinition.in_section("info")).to include(required_field)
        expect(FieldDefinition.in_section("info")).not_to include(optional_field)
      end
    end

    describe ".by_position" do
      it "orders by position" do
        expect(FieldDefinition.by_position.to_a).to eq([ optional_field, required_field ])
      end
    end

    describe ".on_page" do
      it "returns fields on specific page" do
        expect(FieldDefinition.on_page(1)).to include(required_field)
        expect(FieldDefinition.on_page(1)).not_to include(optional_field)
      end
    end
  end

  describe "instance methods" do
    describe "#repeatable?" do
      it "returns true if repeating_group is present" do
        field = build(:field_definition, repeating_group: "group1")
        expect(field.repeatable?).to be true
      end

      it "returns false if repeating_group is blank" do
        field = build(:field_definition, repeating_group: nil)
        expect(field.repeatable?).to be false
      end
    end

    describe "#has_options?" do
      it "returns true if options are present" do
        field = build(:field_definition, options: [ { value: "1", label: "One" } ])
        expect(field.has_options?).to be true
      end

      it "returns false if options are empty" do
        field = build(:field_definition, options: [])
        expect(field.has_options?).to be false
      end
    end

    describe "#width_class" do
      it "returns correct tailwind classes for different widths" do
        expect(build(:field_definition, width: "half").width_class).to eq("w-full md:w-1/2")
        expect(build(:field_definition, width: "third").width_class).to eq("w-full md:w-1/3")
        expect(build(:field_definition, width: "quarter").width_class).to eq("w-full md:w-1/4")
        expect(build(:field_definition, width: "two_thirds").width_class).to eq("w-full md:w-2/3")
        expect(build(:field_definition, width: "full").width_class).to eq("w-full")
        expect(build(:field_definition, width: nil).width_class).to eq("w-full")
      end
    end

    describe "#input_type" do
      it "returns correct HTML input type" do
        expect(build(:field_definition, field_type: "tel").input_type).to eq("tel")
        expect(build(:field_definition, field_type: "email").input_type).to eq("email")
        expect(build(:field_definition, field_type: "currency").input_type).to eq("number")
        expect(build(:field_definition, field_type: "date").input_type).to eq("date")
        expect(build(:field_definition, field_type: "text").input_type).to eq("text")
        expect(build(:field_definition, field_type: "select").input_type).to eq("text")
      end
    end

    describe "#component_name" do
      it "returns the correct component class name" do
        expect(build(:field_definition, field_type: "text").component_name).to eq("Forms::TextFieldComponent")
        expect(build(:field_definition, field_type: "checkbox_group").component_name).to eq("Forms::CheckboxGroupFieldComponent")
      end
    end

    describe "#conditions_for_js" do
      it "returns empty array when conditions is nil" do
        field = build(:field_definition, conditions: nil)
        expect(field.conditions_for_js).to eq([])
      end

      it "returns empty array when conditions is empty hash" do
        field = build(:field_definition, conditions: {})
        expect(field.conditions_for_js).to eq([])
      end

      it "transforms show_when condition with string keys" do
        field = build(:field_definition, conditions: {
          "show_when" => { "field" => "demand_made", "value" => true }
        })
        expect(field.conditions_for_js).to eq([
          { "field" => "demand_made", "operator" => "equals", "value" => true }
        ])
      end

      it "transforms show_when condition with symbol keys" do
        field = build(:field_definition, conditions: {
          show_when: { field: "demand_made", value: "yes" }
        })
        expect(field.conditions_for_js).to eq([
          { "field" => "demand_made", "operator" => "equals", "value" => "yes" }
        ])
      end

      it "transforms hide_when condition to not_equals operator" do
        field = build(:field_definition, conditions: {
          "hide_when" => { "field" => "status", "value" => "inactive" }
        })
        expect(field.conditions_for_js).to eq([
          { "field" => "status", "operator" => "not_equals", "value" => "inactive" }
        ])
      end

      it "preserves custom operator from condition" do
        field = build(:field_definition, conditions: {
          "show_when" => { "field" => "amount", "operator" => "present", "value" => nil }
        })
        expect(field.conditions_for_js).to eq([
          { "field" => "amount", "operator" => "present", "value" => nil }
        ])
      end

      it "handles both show_when and hide_when conditions" do
        field = build(:field_definition, conditions: {
          "show_when" => { "field" => "type", "value" => "other" },
          "hide_when" => { "field" => "disabled", "value" => true }
        })
        result = field.conditions_for_js
        expect(result.length).to eq(2)
        expect(result).to include({ "field" => "type", "operator" => "equals", "value" => "other" })
        expect(result).to include({ "field" => "disabled", "operator" => "not_equals", "value" => true })
      end
    end
  end
end
