# frozen_string_literal: true

require "rails_helper"

RSpec.describe Courthouse, type: :model do
  describe "validations" do
    subject(:courthouse) do
      described_class.new(
        name: "Test Court",
        address: "123 Main St",
        city: "Los Angeles",
        county: "Los Angeles",
        zip: "90012"
      )
    end

    it "is valid with valid attributes" do
      expect(courthouse).to be_valid
    end

    it "requires a name" do
      courthouse.name = nil
      expect(courthouse).not_to be_valid
      expect(courthouse.errors[:name]).to include("can't be blank")
    end

    it "requires an address" do
      courthouse.address = nil
      expect(courthouse).not_to be_valid
      expect(courthouse.errors[:address]).to include("can't be blank")
    end

    it "requires a city" do
      courthouse.city = nil
      expect(courthouse).not_to be_valid
      expect(courthouse.errors[:city]).to include("can't be blank")
    end

    it "requires a county" do
      courthouse.county = nil
      expect(courthouse).not_to be_valid
      expect(courthouse.errors[:county]).to include("can't be blank")
    end

    it "requires a valid ZIP code" do
      courthouse.zip = "invalid"
      expect(courthouse).not_to be_valid
      expect(courthouse.errors[:zip]).to include("must be a valid ZIP code")
    end

    it "accepts 5-digit ZIP codes" do
      courthouse.zip = "90012"
      expect(courthouse).to be_valid
    end

    it "accepts ZIP+4 format" do
      courthouse.zip = "90012-1234"
      expect(courthouse).to be_valid
    end

    it "validates latitude range" do
      courthouse.latitude = 100
      expect(courthouse).not_to be_valid
      expect(courthouse.errors[:latitude]).to be_present
    end

    it "validates longitude range" do
      courthouse.longitude = 200
      expect(courthouse).not_to be_valid
      expect(courthouse.errors[:longitude]).to be_present
    end

    it "validates website URL format" do
      courthouse.website_url = "not-a-url"
      expect(courthouse).not_to be_valid
      expect(courthouse.errors[:website_url]).to include("must be a valid URL")
    end

    it "accepts valid website URLs" do
      courthouse.website_url = "https://www.courts.ca.gov"
      expect(courthouse).to be_valid
    end
  end

  describe "scopes" do
    let!(:active_courthouse) { create_courthouse(active: true, county: "Los Angeles", city: "Los Angeles") }
    let!(:inactive_courthouse) { create_courthouse(active: false, county: "Orange", city: "Santa Ana") }
    let!(:courthouse_with_coords) { create_courthouse(latitude: 34.05, longitude: -118.25) }
    let!(:courthouse_without_coords) { create_courthouse(latitude: nil, longitude: nil) }

    describe ".active" do
      it "returns only active courthouses" do
        expect(described_class.active).to include(active_courthouse)
        expect(described_class.active).not_to include(inactive_courthouse)
      end
    end

    describe ".by_county" do
      it "filters by county (case insensitive)" do
        expect(described_class.by_county("los angeles")).to include(active_courthouse)
        expect(described_class.by_county("Los Angeles")).to include(active_courthouse)
        expect(described_class.by_county("Orange")).not_to include(active_courthouse)
      end
    end

    describe ".by_city" do
      it "filters by city (case insensitive)" do
        expect(described_class.by_city("los angeles")).to include(active_courthouse)
        expect(described_class.by_city("Santa Ana")).to include(inactive_courthouse)
      end
    end

    describe ".by_zip" do
      it "filters by ZIP prefix" do
        courthouse = create_courthouse(zip: "90210")
        expect(described_class.by_zip("902")).to include(courthouse)
        expect(described_class.by_zip("901")).not_to include(courthouse)
      end
    end

    describe ".with_coordinates" do
      it "returns only courthouses with coordinates" do
        expect(described_class.with_coordinates).to include(courthouse_with_coords)
        expect(described_class.with_coordinates).not_to include(courthouse_without_coords)
      end
    end
  end

  describe ".search" do
    let!(:la_court) { create_courthouse(name: "LA Superior Court", city: "Los Angeles", county: "Los Angeles", zip: "90012") }
    let!(:sf_court) { create_courthouse(name: "SF Superior Court", city: "San Francisco", county: "San Francisco", zip: "94102") }

    it "searches by name" do
      expect(described_class.search("LA Superior")).to include(la_court)
      expect(described_class.search("LA Superior")).not_to include(sf_court)
    end

    it "searches by city" do
      expect(described_class.search("San Francisco")).to include(sf_court)
    end

    it "searches by county" do
      expect(described_class.search("Los Angeles")).to include(la_court)
    end

    it "searches by ZIP code" do
      expect(described_class.search("90012")).to include(la_court)
      expect(described_class.search("94102")).to include(sf_court)
    end

    it "returns empty for blank queries" do
      expect(described_class.search("")).to be_empty
      expect(described_class.search(nil)).to be_empty
    end
  end

  describe ".counties" do
    before do
      create_courthouse(county: "Los Angeles", active: true)
      create_courthouse(county: "San Diego", active: true)
      create_courthouse(county: "San Diego", active: true) # duplicate
      create_courthouse(county: "Orange", active: false) # inactive
    end

    it "returns unique counties from active courthouses" do
      counties = described_class.counties
      expect(counties).to include("Los Angeles", "San Diego")
      expect(counties).not_to include("Orange")
    end

    it "returns sorted list" do
      expect(described_class.counties).to eq(described_class.counties.sort)
    end
  end

  describe "#full_address" do
    it "returns formatted address" do
      courthouse = described_class.new(
        address: "123 Main St",
        city: "Los Angeles",
        zip: "90012"
      )
      expect(courthouse.full_address).to eq("123 Main St, Los Angeles, CA 90012")
    end
  end

  describe "#has_coordinates?" do
    it "returns true when both latitude and longitude are present" do
      courthouse = described_class.new(latitude: 34.05, longitude: -118.25)
      expect(courthouse.has_coordinates?).to be true
    end

    it "returns false when latitude is missing" do
      courthouse = described_class.new(latitude: nil, longitude: -118.25)
      expect(courthouse.has_coordinates?).to be false
    end

    it "returns false when longitude is missing" do
      courthouse = described_class.new(latitude: 34.05, longitude: nil)
      expect(courthouse.has_coordinates?).to be false
    end
  end

  describe "#as_map_marker" do
    let(:courthouse) do
      described_class.new(
        id: 1,
        name: "Test Court",
        address: "123 Main St",
        city: "Los Angeles",
        county: "Los Angeles",
        zip: "90012",
        phone: "(213) 555-1234",
        hours: "8 AM - 5 PM",
        website_url: "https://example.com",
        latitude: 34.05,
        longitude: -118.25
      )
    end

    it "returns hash with map marker data" do
      marker = courthouse.as_map_marker
      expect(marker[:id]).to eq(1)
      expect(marker[:name]).to eq("Test Court")
      expect(marker[:address]).to eq("123 Main St, Los Angeles, CA 90012")
      expect(marker[:city]).to eq("Los Angeles")
      expect(marker[:county]).to eq("Los Angeles")
      expect(marker[:phone]).to eq("(213) 555-1234")
      expect(marker[:hours]).to eq("8 AM - 5 PM")
      expect(marker[:website_url]).to eq("https://example.com")
      expect(marker[:latitude]).to eq(34.05)
      expect(marker[:longitude]).to eq(-118.25)
    end
  end

  private

  def create_courthouse(attrs = {})
    defaults = {
      name: "Test Court #{rand(1000)}",
      address: "123 Main St",
      city: "Test City",
      county: "Test County",
      zip: "90001",
      active: true
    }
    described_class.create!(defaults.merge(attrs))
  end
end
