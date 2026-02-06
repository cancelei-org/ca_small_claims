# frozen_string_literal: true

require "rails_helper"

RSpec.describe Forms::SchemaGenerator do
  let(:form_code) { "SC-100" }
  let(:generator) { described_class.new(form_code) }

  describe "#initialize" do
    it "normalizes the form code" do
      generator = described_class.new("sc100")
      expect(generator.form_code).to eq("SC-100")
    end

    it "initializes empty errors and warnings" do
      expect(generator.errors).to eq([])
      expect(generator.warnings).to eq([])
    end
  end

  describe "#generate" do
    context "when PDF file is not found" do
      before do
        allow_any_instance_of(described_class).to receive(:find_pdf_path).and_return(nil)
      end

      it "returns nil" do
        expect(generator.generate).to be_nil
      end

      it "adds an error" do
        generator.generate
        expect(generator.errors).to include(match(/PDF file not found/))
      end
    end

    context "when PDF has no fillable fields" do
      let(:pdf_path) { "/path/to/sc100.pdf" }

      before do
        allow_any_instance_of(described_class).to receive(:find_pdf_path).and_return(pdf_path)
        allow_any_instance_of(described_class).to receive(:extract_fields).and_return([])
      end

      it "returns non-fillable schema" do
        schema = generator.generate
        expect(schema[:form][:fillable]).to be false
      end

      it "adds a warning" do
        generator.generate
        expect(generator.warnings).to include(match(/may be non-fillable/))
      end
    end

    context "when PDF has fillable fields" do
      let(:pdf_path) { "/path/to/sc100.pdf" }
      let(:fields) do
        [
          { name: "PlaintiffName", type: "Text", page: 1 },
          { name: "DefendantName", type: "Text", page: 1 },
          { name: "ClaimAmount", type: "Text", page: 2 }
        ]
      end

      before do
        allow_any_instance_of(described_class).to receive(:find_pdf_path).and_return(pdf_path)
        allow_any_instance_of(described_class).to receive(:extract_fields).and_return(fields)
        allow(File).to receive(:basename).and_return("sc100.pdf")
      end

      it "returns a schema with form metadata" do
        schema = generator.generate
        expect(schema[:form][:code]).to eq("SC-100")
        expect(schema[:form][:fillable]).to be true
        expect(schema[:form][:pdf_filename]).to eq("sc100.pdf")
      end

      it "includes sections with fields" do
        schema = generator.generate
        expect(schema[:sections]).to be_a(Hash)
        expect(schema[:sections].values.flat_map { |s| s[:fields] }).not_to be_empty
      end
    end
  end

  describe "#generate_to_file" do
    let(:pdf_path) { "/path/to/sc100.pdf" }
    let(:output_path) { Rails.root.join("config", "form_schemas", "small_claims", "general", "sc100.yml") }

    before do
      allow_any_instance_of(described_class).to receive(:find_pdf_path).and_return(pdf_path)
      allow_any_instance_of(described_class).to receive(:extract_fields).and_return([])
      allow_any_instance_of(described_class).to receive(:schema_output_path).and_return(output_path)
      allow(File).to receive(:basename).and_return("sc100.pdf")
      allow(FileUtils).to receive(:mkdir_p)
      allow(File).to receive(:directory?).and_return(false)
      allow(File).to receive(:write)
    end

    it "writes schema to file" do
      expect(File).to receive(:write).with(output_path, kind_of(String))
      generator.generate_to_file
    end

    it "returns output path on success" do
      result = generator.generate_to_file
      expect(result).to eq(output_path)
    end

    context "when write fails" do
      before do
        allow(File).to receive(:write).and_raise(StandardError, "Write failed")
      end

      it "returns false" do
        expect(generator.generate_to_file).to be false
      end

      it "adds an error" do
        generator.generate_to_file
        expect(generator.errors).to include(match(/Failed to write schema/))
      end
    end
  end

  describe ".generate_batch" do
    before do
      allow(Dir).to receive(:glob).and_return([])
    end

    it "returns a results hash with success, failed, and skipped" do
      results = described_class.generate_batch("SC")
      expect(results).to have_key(:success)
      expect(results).to have_key(:failed)
      expect(results).to have_key(:skipped)
    end

    context "when schema already exists" do
      before do
        allow(Dir).to receive(:glob).with(kind_of(String)).and_return([ "/path/to/sc100.pdf" ])
        allow(described_class).to receive(:extract_form_code_from_filename).and_return("SC-100")
        allow(described_class).to receive(:schema_exists?).with("SC-100").and_return(true)
      end

      it "skips existing schemas without force option" do
        results = described_class.generate_batch("SC")
        expect(results[:skipped]).to include("SC-100")
      end
    end
  end

  describe ".analyze" do
    before do
      allow(Dir).to receive(:glob).and_return([])
    end

    it "returns an array" do
      expect(described_class.analyze("SC")).to be_an(Array)
    end
  end

  describe "CATEGORY_MAP" do
    it "maps SC prefix to small_claims/general" do
      expect(described_class::CATEGORY_MAP["SC"]).to eq("small_claims/general")
    end

    it "maps FL prefix to family_law/general" do
      expect(described_class::CATEGORY_MAP["FL"]).to eq("family_law/general")
    end

    it "maps DV prefix to family_law/domestic_violence" do
      expect(described_class::CATEGORY_MAP["DV"]).to eq("family_law/domestic_violence")
    end
  end

  describe "SHARED_KEY_PATTERNS" do
    it "detects plaintiff name pattern" do
      matched_key = nil
      described_class::SHARED_KEY_PATTERNS.each do |pattern, key|
        if "plaintiff_name".match?(pattern)
          matched_key = key
          break
        end
      end
      expect(matched_key).to eq("plaintiff:name")
    end

    it "detects case number pattern" do
      matched_key = nil
      described_class::SHARED_KEY_PATTERNS.each do |pattern, key|
        if "case_number".match?(pattern)
          matched_key = key
          break
        end
      end
      expect(matched_key).to eq("case:number")
    end
  end

  describe "VALID_FIELD_TYPES" do
    it "includes expected field types" do
      expect(described_class::VALID_FIELD_TYPES).to include("text")
      expect(described_class::VALID_FIELD_TYPES).to include("textarea")
      expect(described_class::VALID_FIELD_TYPES).to include("checkbox")
      expect(described_class::VALID_FIELD_TYPES).to include("signature")
      expect(described_class::VALID_FIELD_TYPES).to include("address")
      expect(described_class::VALID_FIELD_TYPES).to include("currency")
    end
  end

  describe "private methods" do
    describe "#infer_title" do
      it "generates a title from form code" do
        title = generator.send(:infer_title)
        expect(title).to eq("SC 100 Form")
      end
    end

    describe "#infer_category_slug" do
      it "returns category slug based on form prefix" do
        expect(generator.send(:infer_category_slug)).to eq("small_claims/general")
      end

      context "with unknown prefix" do
        let(:form_code) { "XX-999" }

        it "returns general" do
          expect(generator.send(:infer_category_slug)).to eq("general")
        end
      end
    end

    describe "#infer_width" do
      it "returns full for textarea" do
        expect(generator.send(:infer_width, "textarea")).to eq("full")
      end

      it "returns half for date fields" do
        expect(generator.send(:infer_width, "date")).to eq("half")
      end

      it "returns third for currency" do
        expect(generator.send(:infer_width, "currency")).to eq("third")
      end
    end

    describe "#detect_shared_key" do
      it "detects plaintiff name shared key" do
        key = generator.send(:detect_shared_key, "plaintiff_name", "PlaintiffName")
        expect(key).to eq("plaintiff:name")
      end

      it "returns nil for non-matching fields" do
        key = generator.send(:detect_shared_key, "custom_field", "CustomField")
        expect(key).to be_nil
      end
    end
  end
end
