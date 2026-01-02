# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pdf::Strategies::FormFilling do
  let(:form) { create(:form_definition, pdf_filename: "test.pdf") }
  let(:submission) { create(:submission, form_definition: form) }
  let(:strategy) { described_class.new(submission) }

  before do
    allow(form).to receive(:pdf_path).and_return(Rails.root.join("tmp", "test.pdf"))
    allow(FileUtils).to receive(:mkdir_p)
    allow(File).to receive(:exist?).and_return(true)
  end

  describe "#generate" do
    context "when pdftk is available" do
      let(:pdftk_double) { double("PdfForms") }

      before do
        allow(Utilities::PdftkResolver).to receive(:available?).and_return(true)
        allow(Utilities::PdftkResolver).to receive(:path).and_return("/usr/bin/pdftk")
        allow(PdfForms).to receive(:new).and_return(pdftk_double)
      end

      it "calls pdftk.fill_form" do
        expect(pdftk_double).to receive(:fill_form).with(
          kind_of(String),
          kind_of(String),
          kind_of(Hash),
          flatten: false
        )
        strategy.generate
      end
    end

    context "when pdftk is not available" do
      before do
        allow(Utilities::PdftkResolver).to receive(:available?).and_return(false)
        # Stub HexaPDF to avoid requiring the gem if not in test env
        stub_const("HexaPDF::Document", double(open: double(acro_form: double(each_field: []), write: true)))
      end

      it "falls back to HexaPDF" do
        expect(strategy.generate).to include("tmp/generated_pdfs")
      end
    end
  end

  describe "data formatting" do
    it "formats checkboxes as Yes/Off" do
      field = create(:field_definition, form_definition: form, field_type: "checkbox", pdf_field_name: "CB1")
      submission.update!(form_data: { field.name => "1" })

      data = strategy.send(:build_pdf_data)
      expect(data["CB1"]).to eq("Yes")
    end

    it "formats currency with 2 decimal places" do
      field = create(:field_definition, form_definition: form, field_type: "currency", pdf_field_name: "Amt")
      submission.update!(form_data: { field.name => "12.5" })

      data = strategy.send(:build_pdf_data)
      expect(data["Amt"]).to eq("12.50")
    end

    it "formats dates as MM/DD/YYYY" do
      field = create(:field_definition, form_definition: form, field_type: "date", pdf_field_name: "D")
      submission.update!(form_data: { field.name => "2026-01-01" })

      data = strategy.send(:build_pdf_data)
      expect(data["D"]).to eq("01/01/2026")
    end
  end
end
