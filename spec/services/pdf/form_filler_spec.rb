# frozen_string_literal: true

require "rails_helper"

RSpec.describe Pdf::FormFiller do
  let(:form_definition) { create(:form_definition, fillable: true) }
  let(:submission) { create(:submission, form_definition: form_definition) }
  let(:service) { described_class.new(submission) }
  let(:strategy_double) { instance_double(Pdf::Strategies::FormFilling) }

  before do
    allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)
    allow(Pdf::Strategies::FormFilling).to receive(:new).and_return(strategy_double)
    allow(strategy_double).to receive(:generate).and_return("PDF DATA")
    allow(strategy_double).to receive(:generate_flattened).and_return("FLATTENED PDF DATA")
  end

  describe "#generate" do
    it "calls strategy.generate" do
      expect(strategy_double).to receive(:generate)
      service.generate
    end

    it "caches the result" do
      service.generate
      expect(Rails.cache.read(submission.pdf_cache_key)).to eq("PDF DATA")
    end

    it "uses cache on second call" do
      service.generate
      expect(strategy_double).to have_received(:generate).once

      service.generate
      expect(strategy_double).to have_received(:generate).once
    end

    it "regenerates if cache invalid" do
      service.generate

      allow(submission).to receive(:pdf_cache_valid?).and_return(false)
      service.generate

      expect(strategy_double).to have_received(:generate).twice
    end

    context "when form is not fillable" do
      let(:form_definition) { create(:form_definition, fillable: false) }
      let(:html_strategy) { instance_double(Pdf::Strategies::HtmlGeneration) }

      before do
        allow(Pdf::Strategies::HtmlGeneration).to receive(:new).and_return(html_strategy)
        allow(html_strategy).to receive(:generate).and_return("HTML PDF DATA")
      end

      it "uses HtmlGeneration strategy" do
        service.generate
        expect(html_strategy).to have_received(:generate)
      end
    end
  end

  describe "#generate_flattened" do
    it "calls strategy.generate_flattened" do
      expect(strategy_double).to receive(:generate_flattened)
      service.generate_flattened
    end

    it "does not cache flattened PDF" do
      service.generate_flattened
      expect(Rails.cache.exist?(submission.pdf_cache_key)).to be false
    end
  end

  describe "edge cases" do
    context "with empty form_data" do
      let(:submission) { create(:submission, form_definition: form_definition, form_data: {}) }

      it "generates PDF successfully" do
        result = service.generate
        expect(result).to eq("PDF DATA")
      end
    end

    context "with nil form_data values" do
      let(:submission) { create(:submission, form_definition: form_definition, form_data: { "field1" => nil, "field2" => "" }) }

      it "generates PDF successfully" do
        result = service.generate
        expect(result).to eq("PDF DATA")
      end
    end

    context "with special characters in form_data" do
      let(:submission) do
        create(:submission, form_definition: form_definition, form_data: {
          "name" => "John O'Connor & Co.",
          "address" => "123 Main St.\nApt #4",
          "notes" => "Special chars: <>&\"'"
        })
      end

      it "generates PDF successfully" do
        result = service.generate
        expect(result).to eq("PDF DATA")
      end
    end

    context "with very long field values" do
      let(:submission) do
        create(:submission, form_definition: form_definition, form_data: {
          "description" => "A" * 10_000
        })
      end

      it "generates PDF successfully" do
        result = service.generate
        expect(result).to eq("PDF DATA")
      end
    end

    context "with unicode characters" do
      let(:submission) do
        create(:submission, form_definition: form_definition, form_data: {
          "name" => "José García 日本語 🏛️"
        })
      end

      it "generates PDF successfully" do
        result = service.generate
        expect(result).to eq("PDF DATA")
      end
    end
  end
end
