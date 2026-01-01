# frozen_string_literal: true

require "rails_helper"

RSpec.describe ConditionalSupport do
  # Create a test class that includes the concern
  let(:test_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Attributes
      include ConditionalSupport

      attribute :conditions, default: -> { [] }
    end
  end

  let(:model) { test_class.new }

  describe "#conditional?" do
    it "returns false when conditions is nil" do
      model.conditions = nil
      expect(model.conditional?).to be false
    end

    it "returns false when conditions is empty" do
      model.conditions = []
      expect(model.conditional?).to be false
    end

    it "returns true when conditions has entries" do
      model.conditions = [ { "field" => "status", "operator" => "equals", "value" => "active" } ]
      expect(model.conditional?).to be true
    end
  end

  describe "#should_show?" do
    context "with no conditions" do
      it "returns true" do
        model.conditions = []
        expect(model.should_show?({})).to be true
      end
    end

    context "with equals operator" do
      before do
        model.conditions = [ { "field" => "status", "operator" => "equals", "value" => "active" } ]
      end

      it "returns true when value matches" do
        expect(model.should_show?({ "status" => "active" })).to be true
      end

      it "returns false when value does not match" do
        expect(model.should_show?({ "status" => "inactive" })).to be false
      end

      it "handles symbol keys in data" do
        expect(model.should_show?({ status: "active" })).to be true
      end
    end

    context "with not_equals operator" do
      before do
        model.conditions = [ { "field" => "status", "operator" => "not_equals", "value" => "deleted" } ]
      end

      it "returns true when value is different" do
        expect(model.should_show?({ "status" => "active" })).to be true
      end

      it "returns false when value matches" do
        expect(model.should_show?({ "status" => "deleted" })).to be false
      end
    end

    context "with present operator" do
      before do
        model.conditions = [ { "field" => "email", "operator" => "present" } ]
      end

      it "returns true when field has a value" do
        expect(model.should_show?({ "email" => "test@example.com" })).to be true
      end

      it "returns false when field is blank" do
        expect(model.should_show?({ "email" => "" })).to be false
      end

      it "returns false when field is nil" do
        expect(model.should_show?({ "email" => nil })).to be false
      end
    end

    context "with blank operator" do
      before do
        model.conditions = [ { "field" => "optional", "operator" => "blank" } ]
      end

      it "returns true when field is blank" do
        expect(model.should_show?({ "optional" => "" })).to be true
      end

      it "returns true when field is missing" do
        expect(model.should_show?({})).to be true
      end

      it "returns false when field has a value" do
        expect(model.should_show?({ "optional" => "value" })).to be false
      end
    end

    context "with greater_than operator" do
      before do
        model.conditions = [ { "field" => "age", "operator" => "greater_than", "value" => "18" } ]
      end

      it "returns true when value is greater" do
        expect(model.should_show?({ "age" => "21" })).to be true
      end

      it "returns false when value is less" do
        expect(model.should_show?({ "age" => "16" })).to be false
      end

      it "returns false when value equals" do
        expect(model.should_show?({ "age" => "18" })).to be false
      end
    end

    context "with less_than operator" do
      before do
        model.conditions = [ { "field" => "items", "operator" => "less_than", "value" => "10" } ]
      end

      it "returns true when value is less" do
        expect(model.should_show?({ "items" => "5" })).to be true
      end

      it "returns false when value is greater" do
        expect(model.should_show?({ "items" => "15" })).to be false
      end
    end

    context "with includes operator" do
      before do
        model.conditions = [ { "field" => "roles", "operator" => "includes", "value" => "admin" } ]
      end

      it "returns true when array includes value" do
        expect(model.should_show?({ "roles" => %w[user admin] })).to be true
      end

      it "returns false when array does not include value" do
        expect(model.should_show?({ "roles" => %w[user guest] })).to be false
      end

      it "works with single value converted to array" do
        expect(model.should_show?({ "roles" => "admin" })).to be true
      end
    end

    context "with not_includes operator" do
      before do
        model.conditions = [ { "field" => "tags", "operator" => "not_includes", "value" => "blocked" } ]
      end

      it "returns true when array does not include value" do
        expect(model.should_show?({ "tags" => %w[active verified] })).to be true
      end

      it "returns false when array includes value" do
        expect(model.should_show?({ "tags" => %w[active blocked] })).to be false
      end
    end

    context "with matches operator" do
      before do
        model.conditions = [ { "field" => "email", "operator" => "matches", "value" => "@company.com$" } ]
      end

      it "returns true when value matches pattern" do
        expect(model.should_show?({ "email" => "user@company.com" })).to be true
      end

      it "returns false when value does not match pattern" do
        expect(model.should_show?({ "email" => "user@gmail.com" })).to be false
      end

      it "performs case-insensitive matching" do
        expect(model.should_show?({ "email" => "USER@COMPANY.COM" })).to be true
      end
    end

    context "with multiple conditions" do
      before do
        model.conditions = [
          { "field" => "status", "operator" => "equals", "value" => "active" },
          { "field" => "verified", "operator" => "equals", "value" => "true" }
        ]
      end

      it "returns true when all conditions pass" do
        expect(model.should_show?({ "status" => "active", "verified" => "true" })).to be true
      end

      it "returns false when any condition fails" do
        expect(model.should_show?({ "status" => "active", "verified" => "false" })).to be false
      end
    end

    context "with symbol keys in conditions" do
      before do
        model.conditions = [ { field: "status", operator: "equals", value: "active" } ]
      end

      it "handles symbol keys" do
        expect(model.should_show?({ "status" => "active" })).to be true
      end
    end

    context "with unknown operator" do
      before do
        model.conditions = [ { "field" => "status", "operator" => "unknown_op", "value" => "x" } ]
      end

      it "returns true (permissive default)" do
        expect(model.should_show?({ "status" => "whatever" })).to be true
      end
    end

    context "with default operator (equals)" do
      before do
        model.conditions = [ { "field" => "status", "value" => "active" } ]
      end

      it "uses equals when operator is not specified" do
        expect(model.should_show?({ "status" => "active" })).to be true
        expect(model.should_show?({ "status" => "inactive" })).to be false
      end
    end
  end

  describe "#should_show_any?" do
    context "with no conditions" do
      it "returns true" do
        model.conditions = []
        expect(model.should_show_any?({})).to be true
      end
    end

    context "with multiple conditions" do
      before do
        model.conditions = [
          { "field" => "role", "operator" => "equals", "value" => "admin" },
          { "field" => "role", "operator" => "equals", "value" => "superuser" }
        ]
      end

      it "returns true when any condition passes" do
        expect(model.should_show_any?({ "role" => "admin" })).to be true
        expect(model.should_show_any?({ "role" => "superuser" })).to be true
      end

      it "returns false when no conditions pass" do
        expect(model.should_show_any?({ "role" => "user" })).to be false
      end
    end
  end

  describe "OPERATORS constant" do
    it "includes all supported operators" do
      expect(described_class::OPERATORS).to include(
        "equals", "not_equals", "present", "blank",
        "greater_than", "less_than", "includes", "not_includes", "matches"
      )
    end
  end
end
