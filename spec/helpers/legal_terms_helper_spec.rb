# frozen_string_literal: true

require "rails_helper"

RSpec.describe LegalTermsHelper, type: :helper do
  describe "#highlight_legal_terms" do
    it "highlights legal terms in text" do
      result = helper.highlight_legal_terms("The plaintiff must respond.")

      expect(result).to include('class="legal-term"')
      expect(result).to be_html_safe
    end

    it "returns empty string for blank input" do
      expect(helper.highlight_legal_terms(nil)).to eq("")
      expect(helper.highlight_legal_terms("")).to eq("")
    end
  end

  describe "#legal_term" do
    it "creates a tooltip span for known term" do
      result = helper.legal_term("plaintiff")

      expect(result).to have_css("span.legal-term")
      expect(result).to include("plaintiff")
    end

    it "returns plain text for unknown term" do
      result = helper.legal_term("unknown_term_xyz")

      expect(result).to eq("unknown_term_xyz")
    end

    it "accepts display text option" do
      result = helper.legal_term("plaintiff", display: "Plaintiffs")

      expect(result).to include("Plaintiffs")
    end

    it "includes data attributes" do
      result = helper.legal_term("plaintiff")

      expect(result).to include('data-controller="legal-tooltip"')
      expect(result).to include("data-legal-tooltip-definition-value")
    end
  end

  describe "#contains_legal_terms?" do
    it "returns true when text contains legal terms" do
      expect(helper.contains_legal_terms?("The plaintiff filed.")).to be true
    end

    it "returns false when text has no legal terms" do
      expect(helper.contains_legal_terms?("Hello world")).to be false
    end

    it "returns false for blank input" do
      expect(helper.contains_legal_terms?(nil)).to be false
      expect(helper.contains_legal_terms?("")).to be false
    end
  end
end
