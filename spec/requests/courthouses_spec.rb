# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Courthouses", type: :request do
  let!(:la_court) do
    Courthouse.create!(
      name: "LA Superior Court",
      address: "111 N Hill St",
      city: "Los Angeles",
      county: "Los Angeles",
      zip: "90012",
      phone: "(213) 830-0803",
      hours: "8:30 AM - 4:30 PM",
      website_url: "https://www.lacourt.org",
      latitude: 34.0549,
      longitude: -118.2445,
      active: true
    )
  end

  let!(:sf_court) do
    Courthouse.create!(
      name: "SF Superior Court",
      address: "400 McAllister St",
      city: "San Francisco",
      county: "San Francisco",
      zip: "94102",
      phone: "(415) 551-3800",
      hours: "8:30 AM - 4:30 PM",
      website_url: "https://sfsuperiorcourt.org",
      latitude: 37.7805,
      longitude: -122.4168,
      active: true
    )
  end

  let!(:inactive_court) do
    Courthouse.create!(
      name: "Inactive Court",
      address: "123 Test St",
      city: "Test City",
      county: "Test",
      zip: "90001",
      active: false
    )
  end

  describe "GET /courthouses" do
    it "returns success" do
      get courthouses_path
      expect(response).to have_http_status(:success)
    end

    it "displays active courthouses" do
      get courthouses_path
      expect(response.body).to include("LA Superior Court")
      expect(response.body).to include("SF Superior Court")
      expect(response.body).not_to include("Inactive Court")
    end

    context "with search parameter" do
      it "filters by search term" do
        get courthouses_path, params: { search: "Los Angeles" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("LA Superior Court")
        expect(response.body).not_to include("SF Superior Court")
      end

      it "filters by ZIP code" do
        get courthouses_path, params: { search: "90012" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("LA Superior Court")
      end
    end

    context "with county parameter" do
      it "filters by county" do
        get courthouses_path, params: { county: "San Francisco" }
        expect(response).to have_http_status(:success)
        expect(response.body).to include("SF Superior Court")
        expect(response.body).not_to include("LA Superior Court")
      end
    end

    context "with JSON format" do
      it "returns courthouse data as JSON" do
        get courthouses_path, as: :json
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("application/json")

        json = JSON.parse(response.body)
        expect(json["courthouses"]).to be_an(Array)
        expect(json["total"]).to eq(2) # only active courthouses with coordinates
      end
    end

    context "with Turbo Stream format" do
      it "returns Turbo Stream response" do
        get courthouses_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("text/vnd.turbo-stream.html")
      end
    end
  end

  describe "GET /courthouses/:id" do
    it "returns success" do
      get courthouse_path(la_court)
      expect(response).to have_http_status(:success)
    end

    it "displays courthouse details" do
      get courthouse_path(la_court)
      expect(response.body).to include("LA Superior Court")
      expect(response.body).to include("111 N Hill St")
      expect(response.body).to include("(213) 830-0803")
    end

    it "shows nearby courthouses" do
      get courthouse_path(la_court)
      expect(response).to have_http_status(:success)
      # SF Court is not nearby, so it shouldn't be in nearby section
    end

    context "with JSON format" do
      it "returns courthouse as JSON" do
        get courthouse_path(la_court), as: :json
        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("application/json")

        json = JSON.parse(response.body)
        expect(json["name"]).to eq("LA Superior Court")
        expect(json["latitude"]).to eq(34.0549)
      end
    end
  end

  describe "GET /courthouses/markers" do
    it "returns JSON array of courthouse markers" do
      get markers_courthouses_path, as: :json
      expect(response).to have_http_status(:success)

      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.length).to eq(2) # only courthouses with coordinates

      marker = json.first
      expect(marker).to include("id", "name", "latitude", "longitude")
    end

    context "with county filter" do
      it "filters markers by county" do
        get markers_courthouses_path, params: { county: "Los Angeles" }, as: :json
        json = JSON.parse(response.body)
        expect(json.length).to eq(1)
        expect(json.first["name"]).to eq("LA Superior Court")
      end
    end
  end
end
