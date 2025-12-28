# frozen_string_literal: true

require "rails_helper"

RSpec.describe Forms::MetadataParser do
  let(:fixture_path) { Rails.root.join("spec/fixtures/files/sample_analysis_results.json") }
  subject(:parser) { described_class.new(fixture_path) }

  describe "#parse" do
    it "returns an array of normalized form hashes" do
      results = parser.parse

      expect(results).to be_an(Array)
      expect(results.length).to eq(5)
    end

    it "normalizes form data with expected keys" do
      result = parser.parse.first

      expect(result).to include(
        :form_number,
        :filename,
        :source_path,
        :file_size,
        :is_fillable,
        :num_pages,
        :total_fields,
        :field_names,
        :category_prefix
      )
    end

    it "extracts category prefix from form number" do
      results = parser.parse

      sc_form = results.find { |r| r[:form_number] == "SC-100" }
      expect(sc_form[:category_prefix]).to eq("SC")

      fl_form = results.find { |r| r[:form_number] == "FL-100" }
      expect(fl_form[:category_prefix]).to eq("FL")
    end

    it "filters out utility field names" do
      result = parser.parse.first

      expect(result[:field_names]).not_to include("Save")
      expect(result[:field_names]).not_to include("Print")
      expect(result[:field_names]).to include("PlaintiffName")
    end

    it "correctly identifies fillable forms" do
      results = parser.parse

      fillable = results.select { |r| r[:is_fillable] }
      non_fillable = results.reject { |r| r[:is_fillable] }

      expect(fillable.length).to eq(3)
      expect(non_fillable.length).to eq(2)
    end
  end

  describe "#stats" do
    it "returns statistics from the metadata" do
      stats = parser.stats

      expect(stats[:total_forms]).to eq(5)
      expect(stats[:fillable_forms]).to eq(3)
      expect(stats[:total_fields]).to eq(45)
    end
  end

  describe "#forms_by_category" do
    it "returns form counts by category" do
      by_category = parser.forms_by_category

      expect(by_category[:SC]).to eq(2)
      expect(by_category[:FL]).to eq(2)
      expect(by_category[:DV]).to eq(1)
    end
  end

  describe "#total_forms" do
    it "returns the total form count" do
      expect(parser.total_forms).to eq(5)
    end
  end

  describe "#fillable_forms" do
    it "returns the fillable form count" do
      expect(parser.fillable_forms).to eq(3)
    end
  end

  describe "form number normalization" do
    it "handles already normalized form numbers" do
      result = parser.parse.find { |r| r[:filename] == "sc100.pdf" }
      expect(result[:form_number]).to eq("SC-100")
    end

    it "preserves form numbers with suffixes" do
      result = parser.parse.find { |r| r[:filename] == "fl110info.pdf" }
      expect(result[:form_number]).to eq("FL-110-INFO")
    end
  end
end
