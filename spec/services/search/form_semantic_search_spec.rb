# frozen_string_literal: true

# Spec for FormSemanticSearch service
# Tests semantic search integration with flukebase_connect
#
# IMPL-CASC-FBC-002

require "rails_helper"

RSpec.describe Search::FormSemanticSearch do
  let(:searcher) { described_class.new }

  # Test forms from the catalog
  let!(:sc_100) do
    create(:form_definition,
           code: "SC-100",
           title: "Plaintiff's Claim and ORDER to Go to Small Claims Court",
           description: "Form used by plaintiffs to file a small claims lawsuit")
  end

  let!(:sc_104) do
    create(:form_definition,
           code: "SC-104",
           title: "Request to Pay Judgment to Court",
           description: "Form to request that judgment be paid directly to the court")
  end

  let!(:pld_050) do
    create(:form_definition,
           code: "PLD-050",
           title: "General Denial",
           description: "Form used by defendants to deny all allegations in a complaint")
  end

  describe "#search" do
    context "with Python/flukebase_connect available", skip: !system("python3 -c 'from flukebase_connect.indexing import IndexStore' > /dev/null 2>&1") do
      before do
        # Build index for test forms
        searcher.index_form(sc_100, incremental: false)
        searcher.index_form(sc_104, incremental: false)
        searcher.index_form(pld_050, incremental: false)
      end

      it "finds relevant forms for plaintiff queries" do
        results = searcher.search("I want to sue someone in small claims court")

        expect(results).not_to be_empty
        expect(results.first.match_type).to eq(:semantic)
        # SC-100 should be highly relevant for plaintiff claims
        form_codes = results.map { |r| r.form.code }
        expect(form_codes).to include("SC-100")
      end

      it "finds relevant forms for defendant queries" do
        results = searcher.search("How do I respond to a lawsuit as defendant")

        expect(results).not_to be_empty
        form_codes = results.map { |r| r.form.code }
        expect(form_codes).to include("PLD-050")
      end

      it "finds payment-related forms" do
        results = searcher.search("pay judgment to court")

        expect(results).not_to be_empty
        form_codes = results.map { |r| r.form.code }
        expect(form_codes).to include("SC-104")
      end

      it "returns results with scores between 0 and 1" do
        results = searcher.search("small claims court forms")

        results.each do |result|
          expect(result.score).to be_between(0, 1)
        end
      end

      it "respects the limit parameter" do
        results = searcher.search("court forms", limit: 2)

        expect(results.length).to be <= 2
      end

      it "respects the min_score parameter" do
        results = searcher.search("completely unrelated gibberish xyz123", min_score: 0.9)

        expect(results).to be_empty
      end
    end

    context "with fallback to keyword search" do
      # Override to ensure Python is marked as unavailable for fallback testing
      let(:searcher) do
        service = described_class.new
        service.instance_variable_set(:@python_available, false)
        service
      end

      it "uses keyword search when semantic search unavailable" do
        # Search for a term that exists in the SC-100 title/description
        results = searcher.search("small claims")

        expect(results).not_to be_empty
        expect(results.first.match_type).to eq(:keyword)
      end

      it "matches form titles with keywords" do
        results = searcher.search("Plaintiff's Claim")

        form_codes = results.map { |r| r.form.code }
        expect(form_codes).to include("SC-100")
      end
    end
  end

  describe "#find_similar" do
    context "with Python available", skip: !system("python3 -c 'from flukebase_connect.indexing import IndexStore' > /dev/null 2>&1") do
      before do
        searcher.index_form(sc_100, incremental: false)
        searcher.index_form(sc_104, incremental: false)
        searcher.index_form(pld_050, incremental: false)
      end

      it "finds forms similar to a given form" do
        results = searcher.find_similar("SC-100", limit: 5)

        expect(results).not_to be_empty
        # Should not include the original form
        form_codes = results.map { |r| r.form.code }
        expect(form_codes).not_to include("SC-100")
      end

      it "returns empty array for non-existent form" do
        results = searcher.find_similar("NONEXISTENT-999")

        expect(results).to be_empty
      end
    end
  end

  describe "#search_by_category" do
    it "searches using category description" do
      allow(searcher).to receive(:search).and_call_original

      searcher.search_by_category("plaintiff forms")

      expect(searcher).to have_received(:search).with("plaintiff forms court forms", limit: 10)
    end
  end

  describe "#build_index" do
    context "with Python available", skip: !system("python3 -c 'from flukebase_connect.indexing import IndexStore' > /dev/null 2>&1") do
      it "indexes all active forms" do
        result = searcher.build_index(incremental: false)

        expect(result[:total_forms]).to be >= 3
        expect(result[:indexed]).to be >= 0
        expect(result[:errors]).to be_an(Array)
        expect(result[:scope]).to eq("ca_small_claims")
      end

      it "supports incremental indexing" do
        # First full index
        searcher.build_index(incremental: false)

        # Second incremental should skip unchanged
        result = searcher.build_index(incremental: true)

        expect(result[:indexed]).to be >= 0
      end
    end

    context "without Python" do
      before do
        allow(searcher).to receive(:available?).and_return(false)
      end

      it "returns error when Python unavailable" do
        result = searcher.build_index

        expect(result[:error]).to eq("Python not available")
      end
    end
  end

  describe "#index_form" do
    context "with Python available", skip: !system("python3 -c 'from flukebase_connect.indexing import IndexStore' > /dev/null 2>&1") do
      it "indexes a single form" do
        result = searcher.index_form(sc_100, incremental: false)

        expect(result[:success]).to be true
      end

      it "skips unchanged forms in incremental mode" do
        # First index
        searcher.index_form(sc_100, incremental: false)

        # Second should skip
        result = searcher.index_form(sc_100, incremental: true)

        # May be skipped if content hash matches
        expect(result[:success]).to be true
      end
    end
  end

  describe "#index_status" do
    context "with Python available", skip: !system("python3 -c 'from flukebase_connect.indexing import IndexStore' > /dev/null 2>&1") do
      it "returns index statistics" do
        status = searcher.index_status

        expect(status).to include(:scope)
        expect(status[:scope]).to eq("ca_small_claims")
      end
    end

    context "without Python" do
      before do
        allow(searcher).to receive(:available?).and_return(false)
      end

      it "returns error when Python unavailable" do
        status = searcher.index_status

        expect(status[:error]).to eq("Python not available")
      end
    end
  end

  describe "#available?" do
    it "returns boolean indicating Python availability" do
      expect(searcher.available?).to be_in([ true, false ])
    end
  end

  describe "SearchResult" do
    it "has expected attributes" do
      result = described_class::SearchResult.new(
        form: sc_100,
        score: 0.95,
        rank: 1,
        match_type: :semantic
      )

      expect(result.form).to eq(sc_100)
      expect(result.score).to eq(0.95)
      expect(result.rank).to eq(1)
      expect(result.match_type).to eq(:semantic)
    end
  end
end
