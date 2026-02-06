# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::Recommender do
  before do
    # Ensure templates are loaded
    Templates::Loader.instance.reload!
  end

  describe ".for_claim_basis" do
    it "returns landlord template for security_deposit" do
      templates = described_class.for_claim_basis("security_deposit")

      expect(templates.any? { |t| t[:id] == "landlord_dispute" }).to be true
    end

    it "returns auto template for auto_accident" do
      templates = described_class.for_claim_basis("auto_accident")

      expect(templates.any? { |t| t[:id] == "auto_accident" }).to be true
    end

    it "returns debt template for loan" do
      templates = described_class.for_claim_basis("loan")

      expect(templates.any? { |t| t[:id] == "unpaid_debt" }).to be true
    end

    it "returns property template for property_damage" do
      templates = described_class.for_claim_basis("property_damage")

      expect(templates.any? { |t| t[:id] == "property_damage" }).to be true
    end

    it "returns empty array for blank claim_basis" do
      expect(described_class.for_claim_basis(nil)).to eq([])
      expect(described_class.for_claim_basis("")).to eq([])
    end
  end

  describe ".for_form" do
    it "returns all templates for SC-100" do
      templates = described_class.for_form("SC-100")

      expect(templates).not_to be_empty
      expect(templates.length).to eq(Templates::Loader.instance.all.length)
    end

    it "returns empty array for other forms" do
      expect(described_class.for_form("SC-104")).to eq([])
      expect(described_class.for_form("SC-105")).to eq([])
    end
  end

  describe ".from_description" do
    it "suggests landlord template for rent-related text" do
      text = "My landlord won't return my security deposit after I moved out of my apartment."
      templates = described_class.from_description(text)

      expect(templates.first[:id]).to eq("landlord_dispute")
    end

    it "suggests auto template for car accident text" do
      text = "I was in a car accident and the other driver rear-ended my vehicle."
      templates = described_class.from_description(text)

      expect(templates.first[:id]).to eq("auto_accident")
    end

    it "suggests debt template for loan text" do
      text = "I lent money to a friend and they won't pay me back."
      templates = described_class.from_description(text)

      expect(templates.first[:id]).to eq("unpaid_debt")
    end

    it "suggests property template for damage text" do
      text = "My neighbor's tree fell on my fence and caused damage."
      templates = described_class.from_description(text)

      expect(templates.first[:id]).to eq("property_damage")
    end

    it "returns empty array for blank text" do
      expect(described_class.from_description(nil)).to eq([])
      expect(described_class.from_description("")).to eq([])
    end

    it "returns empty array for unrelated text" do
      templates = described_class.from_description("completely unrelated text with no keywords")

      expect(templates).to eq([])
    end
  end
end
