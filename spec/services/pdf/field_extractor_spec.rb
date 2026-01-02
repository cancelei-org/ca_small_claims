# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pdf::FieldExtractor do
  let(:pdf_path) { Rails.root.join("spec/fixtures/files/test.pdf") }
  let(:service) { described_class.new(pdf_path) }

  before do
    allow(File).to receive(:exist?).with(pdf_path.to_s).and_return(true)
    # Mock HexaPDF to raise error so it falls back to mocked pdftk or just return mocks
    # But let's mock the private method extract_with_hexapdf if possible, or Mock HexaPDF class.
  end

  describe "#extract" do
    context "when HexaPDF works" do
      before do
        allow(service).to receive(:extract_with_hexapdf).and_return([
          { name: "Field1", type: "text", page: 1 }
        ])
      end

      it "returns extracted fields" do
        fields = service.extract
        expect(fields.first[:name]).to eq("Field1")
      end
    end

    context "when HexaPDF fails and pdftk works" do
      before do
        allow(service).to receive(:extract_with_hexapdf).and_return([])
        allow(service).to receive(:pdftk_available?).and_return(true)
        allow(service).to receive(:extract_with_pdftk).and_return([
          { name: "Field2", type: "text", page: 1 }
        ])
      end

      it "returns pdftk fields" do
        fields = service.extract
        expect(fields.first[:name]).to eq("Field2")
      end
    end

    context "when both fail" do
      before do
        allow(service).to receive(:extract_with_hexapdf).and_return([])
        allow(service).to receive(:pdftk_available?).and_return(false)
      end

      it "returns empty array" do
        expect(service.extract).to eq([])
      end
    end
  end

  describe "#field_names" do
    before do
      allow(service).to receive(:extract).and_return([
        { name: "F1" }, { name: "F2" }
      ])
    end

    it "returns list of names" do
      expect(service.field_names).to eq([ "F1", "F2" ])
    end
  end

  describe "field type detection" do
    # Testing private method logic via public interface (if we could mock the low level object properly)
    # Since we mocked extract_with_*, we can't easily test detect_field_type unless we expose it or use send.

    it "detects types based on name" do
      # Using send to test private method logic for regex coverage
      expect(service.send(:detect_text_subtype, "phone_number")).to eq("tel")
      expect(service.send(:detect_text_subtype, "email_address")).to eq("email")
      expect(service.send(:detect_text_subtype, "total_amount")).to eq("currency")
      expect(service.send(:detect_text_subtype, "date_signed")).to eq("date")
      expect(service.send(:detect_text_subtype, "unknown")).to eq("text")
    end
  end
end
