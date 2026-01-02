# frozen_string_literal: true

require "rails_helper"

RSpec.describe Forms::FieldTypeClassifier do
  let(:classifier) { described_class.new }

  describe "#classify" do
    it "detects email from name" do
      expect(classifier.classify("UserEmail")).to eq("email")
    end

    it "detects tel from name" do
      expect(classifier.classify("Phone_Number")).to eq("tel")
    end

    it "detects currency from name" do
      expect(classifier.classify("TotalAmount")).to eq("currency")
      expect(classifier.classify("Fee_Due")).to eq("currency")
    end

    it "detects date from name" do
      expect(classifier.classify("DateOfBirth")).to eq("date")
      expect(classifier.classify("hearingDate")).to eq("date")
    end

    it "defaults to text" do
      expect(classifier.classify("SomethingRandom")).to eq("text")
    end

    it "prefers explicitly reported type" do
      expect(classifier.classify("EmailField", "checkbox")).to eq("checkbox")
    end
  end

  describe "#skip_field?" do
    it "returns true for utility buttons" do
      expect(classifier.skip_field?("Print")).to be true
      expect(classifier.skip_field?("ResetForm")).to be true
    end

    it "returns false for data fields" do
      expect(classifier.skip_field?("FirstName")).to be false
    end
  end

  describe "#pii_field?" do
    it "returns true for SSN or DOB" do
      expect(classifier.pii_field?("UserSSN")).to be true
      expect(classifier.pii_field?("Date_of_Birth")).to be true
    end
  end

  describe "#humanize_label" do
    it "cleans and titleizes field names" do
      expect(classifier.humanize_label("DV-140[0].Page1[0].Name[0]")).to eq("Name")
      expect(classifier.humanize_label("PlaintiffName")).to eq("Plaintiff Name")
      expect(classifier.humanize_label("fill_text_123")).to eq("Fill Text")
    end
  end

  describe "#sanitize_name" do
    it "creates snake_case names" do
      expect(classifier.sanitize_name("PlaintiffName")).to eq("plaintiff_name")
      expect(classifier.sanitize_name("DV-140[0].Page1[0].Name[0]")).to eq("name")
    end
  end
end
