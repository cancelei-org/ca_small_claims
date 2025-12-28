# frozen_string_literal: true

require "rails_helper"

RSpec.describe Forms::CategoryMapper do
  describe ".create_all!" do
    it "creates all defined categories" do
      expect { described_class.create_all! }.to change(Category, :count)
    end

    it "is idempotent" do
      described_class.create_all!
      initial_count = Category.count

      expect { described_class.create_all! }.not_to change(Category, :count)
      expect(Category.count).to eq(initial_count)
    end

    it "creates Small Claims category with highest priority" do
      described_class.create_all!

      sc_category = Category.find_by(slug: "sc")
      expect(sc_category).to be_present
      expect(sc_category.name).to eq("Small Claims")
      expect(sc_category.position).to eq(1)
    end

    it "creates categories with correct attributes" do
      described_class.create_all!

      fl_category = Category.find_by(slug: "fl")
      expect(fl_category.name).to eq("Family Law")
      expect(fl_category.description).to be_present
      expect(fl_category.active).to be true
    end
  end

  describe ".create_category" do
    it "creates a category with given attributes" do
      category = described_class.create_category("TEST", {
        name: "Test Category",
        description: "A test category",
        position: 999
      })

      expect(category).to be_persisted
      expect(category.slug).to eq("test")
      expect(category.name).to eq("Test Category")
    end

    it "returns existing category if already exists" do
      first = described_class.create_category("SC", described_class::CATEGORIES["SC"])
      second = described_class.create_category("SC", described_class::CATEGORIES["SC"])

      expect(first.id).to eq(second.id)
    end
  end

  describe ".category_for_form" do
    before { described_class.create_all! }

    it "returns the category for a form number" do
      category = described_class.category_for_form("SC-100")

      expect(category).to be_present
      expect(category.slug).to eq("sc")
    end

    it "handles form numbers without hyphen" do
      category = described_class.category_for_form("FL100")

      expect(category).to be_present
      expect(category.slug).to eq("fl")
    end

    it "returns nil for unknown prefixes" do
      category = described_class.category_for_form("UNKNOWN-123")

      expect(category).to be_nil
    end

    it "returns nil for nil input" do
      expect(described_class.category_for_form(nil)).to be_nil
    end
  end

  describe ".category_for_prefix" do
    before { described_class.create_all! }

    it "returns the category for a prefix" do
      category = described_class.category_for_prefix("SC")

      expect(category.name).to eq("Small Claims")
    end

    it "is case-insensitive" do
      category = described_class.category_for_prefix("sc")

      expect(category.name).to eq("Small Claims")
    end
  end

  describe ".known_prefix?" do
    it "returns true for known prefixes" do
      expect(described_class.known_prefix?("SC")).to be true
      expect(described_class.known_prefix?("FL")).to be true
      expect(described_class.known_prefix?("DV")).to be true
    end

    it "returns false for unknown prefixes" do
      expect(described_class.known_prefix?("UNKNOWN")).to be false
      expect(described_class.known_prefix?("XYZ")).to be false
    end

    it "is case-insensitive" do
      expect(described_class.known_prefix?("sc")).to be true
    end
  end

  describe ".all_prefixes" do
    it "returns all known category prefixes" do
      prefixes = described_class.all_prefixes

      expect(prefixes).to include("SC", "FL", "DV", "JV", "GC")
      expect(prefixes).to be_an(Array)
    end
  end

  describe ".category_name" do
    it "returns the human-readable name for a prefix" do
      expect(described_class.category_name("SC")).to eq("Small Claims")
      expect(described_class.category_name("FL")).to eq("Family Law")
    end

    it "returns nil for unknown prefixes" do
      expect(described_class.category_name("UNKNOWN")).to be_nil
    end
  end

  describe "CATEGORIES constant" do
    it "includes all major California form categories" do
      categories = described_class::CATEGORIES

      expect(categories).to include("SC", "FL", "DV", "JV", "GC", "CR", "UD")
    end

    it "has required attributes for each category" do
      described_class::CATEGORIES.each do |prefix, attrs|
        expect(attrs).to have_key(:name), "#{prefix} missing :name"
        expect(attrs).to have_key(:description), "#{prefix} missing :description"
        expect(attrs).to have_key(:position), "#{prefix} missing :position"
      end
    end

    it "has unique positions for all categories" do
      positions = described_class::CATEGORIES.values.map { |v| v[:position] }
      expect(positions.uniq.length).to eq(positions.length)
    end
  end
end
