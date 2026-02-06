# frozen_string_literal: true

require "rails_helper"

RSpec.describe Templates::Loader do
  let(:loader) { described_class.instance }

  before do
    # Reload templates before each test to ensure fresh state
    loader.reload!
  end

  describe "#all" do
    it "returns all available templates" do
      templates = loader.all

      expect(templates).to be_an(Array)
      expect(templates).not_to be_empty
    end

    it "returns template summaries with required fields" do
      templates = loader.all
      template = templates.first

      expect(template).to include(:id, :name, :description, :icon, :category, :claim_types)
    end

    it "includes the landlord dispute template" do
      templates = loader.all
      landlord = templates.find { |t| t[:id] == "landlord_dispute" }

      expect(landlord).not_to be_nil
      expect(landlord[:name]).to eq("Landlord/Tenant Dispute")
      expect(landlord[:category]).to eq("housing")
    end

    it "includes the auto accident template" do
      templates = loader.all
      auto = templates.find { |t| t[:id] == "auto_accident" }

      expect(auto).not_to be_nil
      expect(auto[:name]).to eq("Auto Accident")
      expect(auto[:category]).to eq("vehicle")
    end

    it "includes the unpaid debt template" do
      templates = loader.all
      debt = templates.find { |t| t[:id] == "unpaid_debt" }

      expect(debt).not_to be_nil
      expect(debt[:name]).to eq("Unpaid Debt or Loan")
      expect(debt[:category]).to eq("financial")
    end

    it "includes the property damage template" do
      templates = loader.all
      property = templates.find { |t| t[:id] == "property_damage" }

      expect(property).not_to be_nil
      expect(property[:name]).to eq("Property Damage")
      expect(property[:category]).to eq("property")
    end
  end

  describe "#find" do
    it "returns the full template for a valid ID" do
      template = loader.find("landlord_dispute")

      expect(template).not_to be_nil
      expect(template).to include(:scenario, :prefills, :tips, :related_forms)
    end

    it "returns nil for an invalid ID" do
      template = loader.find("nonexistent_template")

      expect(template).to be_nil
    end

    it "includes prefill data for forms" do
      template = loader.find("auto_accident")

      expect(template[:prefills]).to be_a(Hash)
      expect(template[:prefills][:default]).to include(:"SC-100")
    end

    it "includes tips for the template" do
      template = loader.find("landlord_dispute")

      expect(template[:tips]).to be_an(Array)
      expect(template[:tips].first).to include(:title, :content)
    end
  end

  describe "#by_category" do
    it "returns templates for a specific category" do
      housing_templates = loader.by_category("housing")

      expect(housing_templates).to be_an(Array)
      expect(housing_templates.all? { |t| t[:category] == "housing" }).to be true
    end

    it "returns empty array for unknown category" do
      templates = loader.by_category("unknown_category")

      expect(templates).to eq([])
    end
  end

  describe "#for_claim_basis" do
    it "returns templates matching security_deposit claim basis" do
      templates = loader.for_claim_basis("security_deposit")

      expect(templates).to be_an(Array)
      expect(templates.any? { |t| t[:id] == "landlord_dispute" }).to be true
    end

    it "returns templates matching auto_accident claim basis" do
      templates = loader.for_claim_basis("auto_accident")

      expect(templates).to be_an(Array)
      expect(templates.any? { |t| t[:id] == "auto_accident" }).to be true
    end

    it "returns templates matching loan claim basis" do
      templates = loader.for_claim_basis("loan")

      expect(templates).to be_an(Array)
      expect(templates.any? { |t| t[:id] == "unpaid_debt" }).to be true
    end

    it "returns empty array for unknown claim basis" do
      templates = loader.for_claim_basis("unknown_claim")

      expect(templates).to eq([])
    end
  end

  describe "#reload!" do
    it "clears and reloads templates" do
      initial_templates = loader.all

      loader.reload!
      reloaded_templates = loader.all

      expect(reloaded_templates).to eq(initial_templates)
    end
  end
end
