# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pdf::Strategies::HtmlGeneration do
  let(:form) { create(:form_definition, code: "INT-200") }
  let(:submission) { create(:submission, form_definition: form) }
  let(:strategy) { described_class.new(submission) }

  before do
    allow(FileUtils).to receive(:mkdir_p)
    allow(File).to receive(:exist?).and_return(true)
  end

  describe "#generate" do
    context "when HTML template exists" do
      before do
        allow(form).to receive(:html_template_exists?).and_return(true)
        allow(ApplicationController).to receive(:render).and_return("<html>PDF Content</html>")

        grover_double = instance_double(Grover, to_pdf: "PDF DATA")
        allow(Grover).to receive(:new).and_return(grover_double)
      end

      it "renders template and calls Grover" do
        expect(ApplicationController).to receive(:render)
        expect(Grover).to receive(:new)

        path = strategy.generate
        expect(path).to include("tmp/generated_pdfs")
      end
    end

    context "when HTML template does not exist" do
      before do
        allow(form).to receive(:html_template_exists?).and_return(false)
        allow(form).to receive(:pdf_path).and_return("/path/to/template.pdf")
        allow(FileUtils).to receive(:cp)
      end

      it "copies the original PDF" do
        expect(FileUtils).to receive(:cp).with("/path/to/template.pdf", kind_of(String))
        strategy.generate
      end
    end
  end
end
