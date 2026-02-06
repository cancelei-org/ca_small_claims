# frozen_string_literal: true

require "rails_helper"

RSpec.describe Forms::SchemaValidator do
  let(:valid_schema) do
    {
      form: {
        code: "SC-100",
        title: "Small Claims Complaint",
        pdf_filename: "sc100.pdf",
        category: "plaintiff"
      },
      sections: {
        plaintiff_info: {
          fields: [
            { name: "plaintiff_name", type: "text", label: "Plaintiff Name" },
            { name: "plaintiff_phone", type: "tel", label: "Phone Number" }
          ]
        }
      }
    }
  end

  describe "#validate" do
    subject(:validator) { described_class.new }

    context "with valid schema" do
      before do
        allow(Category).to receive(:exists?).with(slug: "plaintiff").and_return(true)
        allow(File).to receive(:exist?).and_return(true)
      end

      it "returns valid" do
        validator.validate(valid_schema)
        expect(validator).to be_valid
      end

      it "has no errors" do
        validator.validate(valid_schema)
        expect(validator.errors).to be_empty
      end
    end

    context "with missing form section" do
      let(:schema) { { sections: {} } }

      it "reports missing form section error" do
        validator.validate(schema)
        expect(validator.errors).to include("Missing 'form' section")
      end
    end

    context "with missing required form keys" do
      let(:schema) do
        {
          form: { code: "SC-100" },
          sections: {}
        }
      end

      it "reports missing required keys" do
        validator.validate(schema)
        expect(validator.errors).to include("Missing required form key: title")
        expect(validator.errors).to include("Missing required form key: pdf_filename")
        expect(validator.errors).to include("Missing required form key: category")
      end
    end

    context "with missing sections" do
      let(:schema) { { form: valid_schema[:form] } }

      before do
        allow(Category).to receive(:exists?).and_return(true)
        allow(File).to receive(:exist?).and_return(true)
      end

      it "reports missing sections" do
        validator.validate(schema)
        expect(validator.errors).to include("Missing or invalid 'sections'")
      end
    end

    context "with invalid field type" do
      let(:schema) do
        schema = valid_schema.deep_dup
        schema[:sections][:plaintiff_info][:fields][0][:type] = "invalid_type"
        schema
      end

      before do
        allow(Category).to receive(:exists?).and_return(true)
        allow(File).to receive(:exist?).and_return(true)
      end

      it "reports invalid field type" do
        validator.validate(schema)
        expect(validator.errors.join).to include("Invalid field type 'invalid_type'")
      end
    end

    context "with missing required field keys" do
      let(:schema) do
        {
          form: valid_schema[:form],
          sections: {
            test: {
              fields: [
                { name: "field1" } # Missing type and label
              ]
            }
          }
        }
      end

      before do
        allow(Category).to receive(:exists?).and_return(true)
        allow(File).to receive(:exist?).and_return(true)
      end

      it "reports missing field keys" do
        validator.validate(schema)
        expect(validator.errors.join).to include("Field missing required key 'type'")
        expect(validator.errors.join).to include("Field missing required key 'label'")
      end
    end

    context "with duplicate field names" do
      let(:schema) do
        {
          form: valid_schema[:form],
          sections: {
            section1: {
              fields: [
                { name: "duplicate_name", type: "text", label: "First" },
                { name: "duplicate_name", type: "text", label: "Second" }
              ]
            }
          }
        }
      end

      before do
        allow(Category).to receive(:exists?).and_return(true)
        allow(File).to receive(:exist?).and_return(true)
      end

      it "reports duplicate field names" do
        validator.validate(schema)
        expect(validator.errors).to include("Duplicate field name: duplicate_name")
      end
    end

    context "with unnamespaced shared_key" do
      let(:schema) do
        schema = valid_schema.deep_dup
        schema[:sections][:plaintiff_info][:fields][0][:shared_key] = "plaintiff_name"
        schema
      end

      before do
        allow(Category).to receive(:exists?).and_return(true)
        allow(File).to receive(:exist?).and_return(true)
      end

      it "warns about unnamespaced shared_key" do
        validator.validate(schema)
        expect(validator.warnings.join).to include("Unnamespaced shared_key")
      end
    end

    context "with namespaced shared_key" do
      let(:schema) do
        schema = valid_schema.deep_dup
        schema[:sections][:plaintiff_info][:fields][0][:shared_key] = "common:plaintiff_name"
        schema
      end

      before do
        allow(Category).to receive(:exists?).and_return(true)
        allow(File).to receive(:exist?).and_return(true)
      end

      it "does not warn about namespaced shared_key" do
        validator.validate(schema)
        expect(validator.warnings.join).not_to include("Unnamespaced shared_key")
      end
    end

    context "with missing PDF file" do
      before do
        allow(Category).to receive(:exists?).and_return(true)
        allow(File).to receive(:exist?).and_return(false)
      end

      it "warns about missing PDF" do
        validator.validate(valid_schema)
        expect(validator.warnings.join).to include("PDF file not found")
      end
    end

    context "with unknown category" do
      before do
        allow(Category).to receive(:exists?).with(slug: "plaintiff").and_return(false)
        allow(File).to receive(:exist?).and_return(true)
      end

      it "warns about unknown category" do
        validator.validate(valid_schema)
        expect(validator.warnings.join).to include("Category 'plaintiff' not found")
      end
    end
  end

  describe "#valid?" do
    subject(:validator) { described_class.new }

    it "returns true when no errors" do
      allow(Category).to receive(:exists?).and_return(true)
      allow(File).to receive(:exist?).and_return(true)

      validator.validate(valid_schema)
      expect(validator.valid?).to be true
    end

    it "returns false when there are errors" do
      validator.validate({ sections: {} })
      expect(validator.valid?).to be false
    end
  end

  describe "#validate!" do
    subject(:validator) { described_class.new }

    it "raises ValidationError when invalid" do
      validator.validate({ sections: {} })
      expect { validator.validate! }.to raise_error(Forms::SchemaValidator::ValidationError)
    end

    it "returns self when valid" do
      allow(Category).to receive(:exists?).and_return(true)
      allow(File).to receive(:exist?).and_return(true)

      validator.validate(valid_schema)
      expect(validator.validate!).to eq(validator)
    end
  end

  describe "#to_s" do
    subject(:validator) { described_class.new }

    it "includes file path when provided" do
      allow(Category).to receive(:exists?).and_return(true)
      allow(File).to receive(:exist?).and_return(true)

      validator.validate(valid_schema, file_path: "/path/to/schema.yml")
      expect(validator.to_s).to include("/path/to/schema.yml")
    end

    it "includes errors when present" do
      validator.validate({ sections: {} })
      expect(validator.to_s).to include("Errors:")
    end

    it "shows Valid when no errors or warnings" do
      allow(Category).to receive(:exists?).and_return(true)
      allow(File).to receive(:exist?).and_return(true)

      validator.validate(valid_schema)
      expect(validator.to_s).to include("Valid")
    end
  end

  describe ".validate_all" do
    before do
      allow(described_class).to receive(:schema_files).and_return([])
    end

    it "returns a hash with valid, invalid, and warnings arrays" do
      results = described_class.validate_all
      expect(results).to have_key(:valid)
      expect(results).to have_key(:invalid)
      expect(results).to have_key(:warnings)
    end
  end

  describe "VALID_FIELD_TYPES" do
    it "includes common field types" do
      expect(described_class::VALID_FIELD_TYPES).to include("text")
      expect(described_class::VALID_FIELD_TYPES).to include("textarea")
      expect(described_class::VALID_FIELD_TYPES).to include("date")
      expect(described_class::VALID_FIELD_TYPES).to include("checkbox")
      expect(described_class::VALID_FIELD_TYPES).to include("select")
      expect(described_class::VALID_FIELD_TYPES).to include("signature")
      expect(described_class::VALID_FIELD_TYPES).to include("address")
    end
  end
end
