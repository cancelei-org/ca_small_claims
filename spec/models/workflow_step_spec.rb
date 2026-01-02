# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkflowStep, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:workflow) }
    it { is_expected.to belong_to(:form_definition) }
  end

  describe "validations" do
    subject { build(:workflow_step) }
    it { is_expected.to validate_presence_of(:position) }
    it { is_expected.to validate_uniqueness_of(:position).scoped_to(:workflow_id) }
  end

  describe "instance methods" do
    let(:form) { create(:form_definition, title: "Form Title") }
    let(:step) { build(:workflow_step, form_definition: form) }

    describe "#display_name" do
      it "returns name if present" do
        step.name = "Custom Step Name"
        expect(step.display_name).to eq("Custom Step Name")
      end

      it "returns form definition title if name is blank" do
        step.name = nil
        expect(step.display_name).to eq("Form Title")
      end
    end

    describe "#should_show?" do
      it "returns true if not conditional" do
        step.conditions = nil
        expect(step.should_show?({})).to be true
      end

      it "evaluates equals operator" do
        step.conditions = [ { "field" => "role", "operator" => "equals", "value" => "admin" } ]
        expect(step.should_show?({ "role" => "admin" })).to be true
        expect(step.should_show?({ "role" => "user" })).to be false
      end

      it "evaluates present operator" do
        step.conditions = [ { "field" => "name", "operator" => "present" } ]
        expect(step.should_show?({ "name" => "Alice" })).to be true
        expect(step.should_show?({ "name" => "" })).to be false
      end
    end

    describe "#prefill_data" do
      it "maps source data to target fields" do
        step.data_mappings = { "form_field_1" => "shared_key_1" }
        shared_data = { "shared_key_1" => "Value 1", "other" => "ignored" }
        expect(step.prefill_data(shared_data)).to eq({ "form_field_1" => "Value 1" })
      end
    end
  end
end
