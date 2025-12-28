# frozen_string_literal: true

require "rails_helper"

RSpec.describe Forms::FieldTypeClassifier do
  subject(:classifier) { described_class.new }

  describe "#classify" do
    context "when PDF reports checkbox type" do
      it "returns checkbox" do
        expect(classifier.classify("AnyField", "checkbox")).to eq("checkbox")
      end
    end

    context "when PDF reports select type" do
      it "returns select" do
        expect(classifier.classify("AnyField", "select")).to eq("select")
        expect(classifier.classify("AnyField", "choice")).to eq("select")
        expect(classifier.classify("AnyField", "dropdown")).to eq("select")
      end
    end

    context "when detecting from field name patterns" do
      it "classifies signature fields" do
        expect(classifier.classify("Signature")).to eq("signature")
        expect(classifier.classify("PlaintiffSignature")).to eq("signature")
        expect(classifier.classify("PetitionerSig")).to eq("signature")
      end

      it "classifies date fields" do
        expect(classifier.classify("DateOfBirth")).to eq("date")
        expect(classifier.classify("HearingDate")).to eq("date")
        expect(classifier.classify("FilingDate")).to eq("date")
        expect(classifier.classify("DOB")).to eq("date")
      end

      it "classifies email fields" do
        expect(classifier.classify("PlaintiffEmail")).to eq("email")
        expect(classifier.classify("E-mail")).to eq("email")
      end

      it "classifies phone fields" do
        expect(classifier.classify("PlaintiffPhone")).to eq("tel")
        expect(classifier.classify("TelephoneNumber")).to eq("tel")
        expect(classifier.classify("FaxNumber")).to eq("tel")
        expect(classifier.classify("MobilePhone")).to eq("tel")
      end

      it "classifies currency fields" do
        expect(classifier.classify("ClaimAmount")).to eq("currency")
        expect(classifier.classify("CourtFee")).to eq("currency")
        expect(classifier.classify("TotalCost")).to eq("currency")
        expect(classifier.classify("PaymentDue")).to eq("currency")
      end

      it "classifies address fields" do
        expect(classifier.classify("StreetAddress")).to eq("address")
        expect(classifier.classify("City")).to eq("address")
        expect(classifier.classify("State")).to eq("address")
        expect(classifier.classify("ZipCode")).to eq("address")
        expect(classifier.classify("MailingAddress")).to eq("address")
      end

      it "classifies checkbox fields by name" do
        expect(classifier.classify("CheckBox1")).to eq("checkbox")
        expect(classifier.classify("CheckBoxAgree")).to eq("checkbox")
      end

      it "defaults to text for unknown patterns" do
        expect(classifier.classify("FillText123")).to eq("text")
        expect(classifier.classify("RandomField")).to eq("text")
        expect(classifier.classify("Description")).to eq("text")
      end
    end
  end

  describe "#skip_field?" do
    it "returns true for utility fields" do
      expect(classifier.skip_field?("Save")).to be true
      expect(classifier.skip_field?("Print")).to be true
      expect(classifier.skip_field?("ResetForm")).to be true
      expect(classifier.skip_field?("Reset")).to be true
      expect(classifier.skip_field?("Clear")).to be true
      expect(classifier.skip_field?("Submit")).to be true
    end

    it "returns true for non-user fields" do
      expect(classifier.skip_field?("WhiteOut")).to be true
      expect(classifier.skip_field?("WhiteOut123")).to be true
      expect(classifier.skip_field?("NoticeHeader1")).to be true
      expect(classifier.skip_field?("NoticeFooter")).to be true
      expect(classifier.skip_field?("#pageSet[0]")).to be true
    end

    it "returns false for regular fields" do
      expect(classifier.skip_field?("PlaintiffName")).to be false
      expect(classifier.skip_field?("ClaimAmount")).to be false
      expect(classifier.skip_field?("CheckBox1")).to be false
    end
  end

  describe "#pii_field?" do
    it "returns true for known PII field names" do
      expect(classifier.pii_field?("Name", ["Name"])).to be true
    end

    it "returns true for fields matching PII patterns" do
      expect(classifier.pii_field?("SSN")).to be true
      expect(classifier.pii_field?("SocialSecurityNumber")).to be true
      expect(classifier.pii_field?("DateOfBirth")).to be true
      expect(classifier.pii_field?("DOB")).to be true
      expect(classifier.pii_field?("DriverLicenseNumber")).to be true
      expect(classifier.pii_field?("PassportNumber")).to be true
    end

    it "returns false for non-PII fields" do
      expect(classifier.pii_field?("ClaimAmount")).to be false
      expect(classifier.pii_field?("CourtName")).to be false
      expect(classifier.pii_field?("CaseNumber")).to be false
    end
  end

  describe "#humanize_label" do
    it "converts camelCase to words" do
      expect(classifier.humanize_label("PlaintiffName")).to eq("Plaintiff Name")
      expect(classifier.humanize_label("DateOfBirth")).to eq("Date Of Birth")
    end

    it "handles numeric suffixes" do
      expect(classifier.humanize_label("FillText123")).to eq("Fill Text")
      expect(classifier.humanize_label("CheckBox1")).to eq("Check Box")
    end

    it "extracts meaningful part from hierarchical names" do
      expect(classifier.humanize_label("FL-100[0].Page1[0].PetitionerName[0]")).to eq("Petitioner Name")
      expect(classifier.humanize_label("Form[0].Section[0].FieldName[0]")).to eq("Field Name")
    end
  end

  describe "#sanitize_name" do
    it "converts to snake_case" do
      expect(classifier.sanitize_name("PlaintiffName")).to eq("plaintiff_name")
      expect(classifier.sanitize_name("DateOfBirth")).to eq("date_of_birth")
    end

    it "removes array indices" do
      expect(classifier.sanitize_name("Field[0]")).to eq("field")
      expect(classifier.sanitize_name("Name[0][1]")).to eq("name")
    end

    it "extracts last segment from hierarchical names" do
      expect(classifier.sanitize_name("FL-100[0].Page1[0].Name[0]")).to eq("name")
    end

    it "replaces special characters with underscores" do
      expect(classifier.sanitize_name("Field-Name")).to eq("field_name")
      expect(classifier.sanitize_name("Field.Name")).to eq("name")
    end

    it "removes leading and trailing underscores" do
      expect(classifier.sanitize_name("_field_")).to eq("field")
    end
  end

  describe "#detect_section" do
    it "extracts section from hierarchical field names" do
      section = classifier.detect_section("FL-100[0].Page1[0].PartyInfo[0].Name[0]")
      expect(section).to eq("Party Info")
    end

    it "returns nil for simple field names" do
      expect(classifier.detect_section("PlaintiffName")).to be_nil
      expect(classifier.detect_section("FillText123")).to be_nil
    end

    it "skips page markers" do
      section = classifier.detect_section("Form[0].Page1[0].Caption[0].Field[0]")
      expect(section).to eq("Caption")
    end
  end
end
