# frozen_string_literal: true

require "rails_helper"

RSpec.describe Forms::CategoryMapper do
  describe ".create_all!" do
    it "creates all defined categories" do
      expect {
        described_class.create_all!
      }.to change(Category, :count)

      sc = Category.find_by(slug: "sc")
      expect(sc.name).to eq("Small Claims")
      expect(sc.position).to eq(1)
    end
  end

  describe ".category_for_form" do
    before { described_class.create_all! }

    it "identifies Small Claims from SC-100" do
      cat = described_class.category_for_form("SC-100")
      expect(cat.name).to eq("Small Claims")
    end

    it "identifies Civil from CIV-110" do
      cat = described_class.category_for_form("CIV-110")
      expect(cat.name).to eq("Civil")
    end

    it "returns nil for unknown prefix" do
      expect(described_class.category_for_form("XYZ-999")).to be_nil
    end
  end

  describe ".category_name" do
    it "returns human name for known prefix" do
      expect(described_class.category_name("SC")).to eq("Small Claims")
    end
  end
end
