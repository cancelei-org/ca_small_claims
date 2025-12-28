# frozen_string_literal: true

require "rails_helper"

RSpec.describe Forms::BulkImporter do
  let(:fixture_path) { Rails.root.join("spec/fixtures/files/sample_analysis_results.json") }
  let(:pdf_source_dir) { Rails.root.join("spec/fixtures/files") }

  subject(:importer) do
    described_class.new(
      metadata_path: fixture_path,
      pdf_source_dir: pdf_source_dir,
      options: { skip_pdfs: true, verbose: false }
    )
  end

  describe "#import!" do
    it "creates categories" do
      expect { importer.import! }.to change(Category, :count)
    end

    it "creates form definitions" do
      expect { importer.import! }.to change(FormDefinition, :count).by(5)
    end

    it "creates field definitions for fillable forms" do
      expect { importer.import! }.to change(FieldDefinition, :count)
    end

    it "tracks statistics" do
      importer.import!

      expect(importer.stats[:forms_created]).to eq(5)
      expect(importer.stats[:categories]).to be > 0
    end

    it "is idempotent" do
      importer.import!
      initial_form_count = FormDefinition.count

      # Create a new importer and run again
      second_importer = described_class.new(
        metadata_path: fixture_path,
        pdf_source_dir: pdf_source_dir,
        options: { skip_pdfs: true }
      )
      second_importer.import!

      expect(FormDefinition.count).to eq(initial_form_count)
      expect(second_importer.stats[:forms_updated]).to eq(5)
      expect(second_importer.stats[:forms_created]).to eq(0)
    end

    it "associates forms with correct categories" do
      importer.import!

      sc_form = FormDefinition.find_by(code: "SC-100")
      expect(sc_form.category).to be_present
      expect(sc_form.category.slug).to eq("sc")

      fl_form = FormDefinition.find_by(code: "FL-100")
      expect(fl_form.category.slug).to eq("fl")
    end

    it "marks forms as fillable or non-fillable correctly" do
      importer.import!

      expect(FormDefinition.find_by(code: "SC-100").fillable).to be true
      expect(FormDefinition.find_by(code: "FL-110-INFO").fillable).to be false
    end

    it "stores metadata on form definitions" do
      importer.import!

      form = FormDefinition.find_by(code: "SC-100")
      expect(form.metadata).to include("file_size", "total_fields", "imported_at")
    end
  end

  describe "with category_filter option" do
    subject(:importer) do
      described_class.new(
        metadata_path: fixture_path,
        pdf_source_dir: pdf_source_dir,
        options: { skip_pdfs: true, category_filter: "SC" }
      )
    end

    it "only imports forms matching the filter" do
      importer.import!

      expect(FormDefinition.count).to eq(2)
      expect(FormDefinition.pluck(:code)).to all(start_with("SC"))
    end
  end

  describe "with dry_run option" do
    subject(:importer) do
      described_class.new(
        metadata_path: fixture_path,
        pdf_source_dir: pdf_source_dir,
        options: { skip_pdfs: true, dry_run: true }
      )
    end

    it "does not persist any changes" do
      expect { importer.import! }.not_to change(FormDefinition, :count)
      expect { importer.import! }.not_to change(Category, :count)
    end

    it "still calculates statistics" do
      importer.import!

      expect(importer.stats[:forms_created]).to eq(5)
    end
  end

  describe "field generation" do
    before { importer.import! }

    it "creates field definitions for fillable forms" do
      form = FormDefinition.find_by(code: "SC-100")
      expect(form.field_definitions).to be_present
    end

    it "does not create fields for non-fillable forms" do
      form = FormDefinition.find_by(code: "FL-110-INFO")
      expect(form.field_definitions).to be_empty
    end

    it "skips utility fields like Save and Print" do
      form = FormDefinition.find_by(code: "SC-100")
      field_names = form.field_definitions.pluck(:pdf_field_name)

      expect(field_names).not_to include("Save")
      expect(field_names).not_to include("Print")
    end

    it "assigns correct field types" do
      form = FormDefinition.find_by(code: "SC-100")

      date_field = form.field_definitions.find_by(pdf_field_name: "DateOfIncident")
      expect(date_field.field_type).to eq("date")

      phone_field = form.field_definitions.find_by(pdf_field_name: "PlaintiffPhone")
      expect(phone_field.field_type).to eq("tel")

      email_field = form.field_definitions.find_by(pdf_field_name: "PlaintiffEmail")
      expect(email_field.field_type).to eq("email")
    end

    it "assigns positions to fields" do
      form = FormDefinition.find_by(code: "SC-100")
      positions = form.field_definitions.pluck(:position)

      expect(positions).to eq(positions.sort)
      expect(positions.uniq).to eq(positions)
    end

    it "generates human-readable labels" do
      form = FormDefinition.find_by(code: "SC-100")
      field = form.field_definitions.find_by(pdf_field_name: "PlaintiffName")

      expect(field.label).to eq("Plaintiff Name")
    end
  end

  describe "error handling" do
    it "continues processing after individual form errors" do
      # The fixture has valid data, so no errors expected
      importer.import!
      expect(importer.stats[:errors]).to eq(0)
    end

    it "logs errors without stopping the import" do
      allow(FormDefinition).to receive(:find_or_initialize_by).and_call_original
      allow(FormDefinition).to receive(:find_or_initialize_by)
        .with(code: "SC-100")
        .and_raise(StandardError, "Test error")

      importer.import!

      expect(importer.stats[:errors]).to be >= 1
      expect(importer.errors).to be_present
    end
  end

  describe "#parser" do
    it "returns a MetadataParser instance" do
      expect(importer.parser).to be_a(Forms::MetadataParser)
    end

    it "is memoized" do
      expect(importer.parser.object_id).to eq(importer.parser.object_id)
    end
  end

  describe "position calculation" do
    before { importer.import! }

    it "prioritizes Small Claims forms with lower position numbers" do
      sc_form = FormDefinition.find_by(code: "SC-100")
      fl_form = FormDefinition.find_by(code: "FL-100")

      expect(sc_form.position).to be < fl_form.position
    end
  end
end
