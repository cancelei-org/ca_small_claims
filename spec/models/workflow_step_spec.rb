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

  describe "scopes" do
    let(:workflow) { create(:workflow) }
    let!(:required_step) { create(:workflow_step, workflow: workflow, required: true, position: 2) }
    let!(:optional_step) { create(:workflow_step, workflow: workflow, required: false, position: 1) }

    describe ".required" do
      it "returns only required steps" do
        expect(WorkflowStep.required).to include(required_step)
        expect(WorkflowStep.required).not_to include(optional_step)
      end
    end

    describe ".optional" do
      it "returns only optional steps" do
        expect(WorkflowStep.optional).to include(optional_step)
        expect(WorkflowStep.optional).not_to include(required_step)
      end
    end

    describe ".ordered" do
      it "orders by position" do
        expect(WorkflowStep.ordered.to_a).to eq([ optional_step, required_step ])
      end
    end
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

      it "returns true for empty conditions array" do
        step.conditions = []
        expect(step.should_show?({})).to be true
      end

      it "evaluates equals operator" do
        step.conditions = [ { "field" => "role", "operator" => "equals", "value" => "admin" } ]
        expect(step.should_show?({ "role" => "admin" })).to be true
        expect(step.should_show?({ "role" => "user" })).to be false
      end

      it "evaluates not_equals operator" do
        step.conditions = [ { "field" => "role", "operator" => "not_equals", "value" => "admin" } ]
        expect(step.should_show?({ "role" => "user" })).to be true
        expect(step.should_show?({ "role" => "admin" })).to be false
      end

      it "evaluates present operator" do
        step.conditions = [ { "field" => "name", "operator" => "present" } ]
        expect(step.should_show?({ "name" => "Alice" })).to be true
        expect(step.should_show?({ "name" => "" })).to be false
        expect(step.should_show?({ "name" => nil })).to be false
      end

      it "evaluates blank operator" do
        step.conditions = [ { "field" => "name", "operator" => "blank" } ]
        expect(step.should_show?({ "name" => "" })).to be true
        expect(step.should_show?({ "name" => nil })).to be true
        expect(step.should_show?({ "name" => "Alice" })).to be false
      end

      it "evaluates greater_than operator" do
        step.conditions = [ { "field" => "amount", "operator" => "greater_than", "value" => "100" } ]
        expect(step.should_show?({ "amount" => "150" })).to be true
        expect(step.should_show?({ "amount" => "50" })).to be false
        expect(step.should_show?({ "amount" => "100" })).to be false
      end

      it "evaluates includes operator" do
        step.conditions = [ { "field" => "categories", "operator" => "includes", "value" => "legal" } ]
        expect(step.should_show?({ "categories" => [ "legal", "finance" ] })).to be true
        expect(step.should_show?({ "categories" => [ "finance" ] })).to be false
      end

      it "evaluates multiple conditions with AND logic" do
        step.conditions = [
          { "field" => "role", "operator" => "equals", "value" => "admin" },
          { "field" => "verified", "operator" => "present" }
        ]
        expect(step.should_show?({ "role" => "admin", "verified" => "yes" })).to be true
        expect(step.should_show?({ "role" => "admin", "verified" => "" })).to be false
        expect(step.should_show?({ "role" => "user", "verified" => "yes" })).to be false
      end

      it "defaults to equals when no operator specified" do
        step.conditions = [ { "field" => "role", "value" => "admin" } ]
        expect(step.should_show?({ "role" => "admin" })).to be true
        expect(step.should_show?({ "role" => "user" })).to be false
      end

      it "returns true for unknown operator" do
        step.conditions = [ { "field" => "role", "operator" => "unknown_op", "value" => "admin" } ]
        expect(step.should_show?({ "role" => "user" })).to be true
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
