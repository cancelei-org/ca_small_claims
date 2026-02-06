# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalTerms::Glossary do
  let(:glossary) { described_class.instance }

  before do
    # Ensure fresh instance for tests
    glossary.reload!
  end

  describe "#terms" do
    it "returns all terms from the glossary" do
      terms = glossary.terms

      expect(terms).to be_an(Array)
      expect(terms).not_to be_empty
    end

    it "includes expected term structures" do
      term = glossary.terms.first

      expect(term).to have_key(:term)
      expect(term).to have_key(:definition)
    end
  end

  describe "#find" do
    it "finds a term by key" do
      term = glossary.find("plaintiff")

      expect(term).to be_present
      expect(term[:term]).to eq("Plaintiff")
    end

    it "returns nil for unknown key" do
      expect(glossary.find("nonexistent")).to be_nil
    end
  end

  describe "#find_by_term" do
    it "finds a term by text (case-insensitive)" do
      term = glossary.find_by_term("Plaintiff")

      expect(term).to be_present
      expect(term[:term]).to eq("Plaintiff")
    end

    it "finds term with different casing" do
      term = glossary.find_by_term("DEFENDANT")

      expect(term).to be_present
      expect(term[:term]).to eq("Defendant")
    end

    it "returns nil for unknown term" do
      expect(glossary.find_by_term("unknown term")).to be_nil
    end
  end

  describe "#highlight_terms" do
    it "wraps known terms in tooltip spans" do
      text = "The plaintiff must serve the defendant."
      result = glossary.highlight_terms(text)

      expect(result).to include('class="legal-term"')
      expect(result).to include('data-controller="legal-tooltip"')
    end

    it "preserves original term casing" do
      text = "The Plaintiff filed a claim."
      result = glossary.highlight_terms(text)

      expect(result).to include(">Plaintiff</span>")
    end

    it "handles multiple terms" do
      text = "The plaintiff won a judgment against the defendant."
      result = glossary.highlight_terms(text)

      expect(result.scan('class="legal-term"').count).to be >= 2
    end

    it "returns original text when no terms found" do
      text = "This has no legal terminology."
      result = glossary.highlight_terms(text)

      expect(result).not_to include('class="legal-term"')
    end

    it "returns empty string for blank input" do
      expect(glossary.highlight_terms(nil)).to eq(nil)
      expect(glossary.highlight_terms("")).to eq("")
    end

    it "includes definition data in tooltip" do
      text = "The plaintiff filed."
      result = glossary.highlight_terms(text)

      expect(result).to include("data-legal-tooltip-definition-value")
    end

    it "includes help URL when available" do
      text = "The plaintiff filed."
      result = glossary.highlight_terms(text)

      expect(result).to include("data-legal-tooltip-url-value")
    end
  end

  describe "#all_terms" do
    it "returns hash of all terms keyed by identifier" do
      all = glossary.all_terms

      expect(all).to be_a(Hash)
      expect(all).to have_key("plaintiff")
      expect(all).to have_key("defendant")
    end
  end
end
