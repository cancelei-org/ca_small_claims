# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Templates", type: :request do
  let(:sample_template_summaries) do
    [
      {
        id: "individual_plaintiff",
        name: "Individual Plaintiff",
        description: "Quick fill for an individual filing a claim",
        icon: "person",
        category: "individual",
        claim_types: [ "contract", "property" ]
      },
      {
        id: "small_business",
        name: "Small Business",
        description: "Quick fill for a small business",
        icon: "business",
        category: "business",
        claim_types: [ "contract" ]
      }
    ]
  end

  let(:sample_template_full) do
    {
      scenario: {
        id: "individual_plaintiff",
        name: "Individual Plaintiff",
        description: "Quick fill for an individual filing a claim",
        icon: "person",
        category: "individual",
        claim_types: [ "contract", "property" ]
      },
      prefills: {
        default: {
          "SC-100": {
            plaintiff_name: "John Doe",
            plaintiff_address: "123 Main St"
          }
        }
      }
    }
  end

  before do
    loader = instance_double(Templates::Loader)
    allow(Templates::Loader).to receive(:instance).and_return(loader)
    allow(loader).to receive(:all).and_return(sample_template_summaries)
    allow(loader).to receive(:find).with("individual_plaintiff").and_return(sample_template_full)
    allow(loader).to receive(:find).with("small_business").and_return(sample_template_full)
    allow(loader).to receive(:find).with("nonexistent").and_return(nil)
  end

  describe "GET /templates" do
    it "returns http success" do
      get templates_path

      expect(response).to have_http_status(:success)
    end

    it "displays all templates" do
      get templates_path

      expect(response.body).to include("Individual Plaintiff")
      expect(response.body).to include("Small Business")
      expect(assigns(:templates)).to eq(sample_template_summaries)
    end

    it "returns JSON when requested" do
      get templates_path, headers: { "Accept" => "application/json" }

      expect(response.content_type).to include("application/json")
      json = JSON.parse(response.body)
      expect(json.length).to eq(2)
      expect(json[0]["id"]).to eq("individual_plaintiff")
    end
  end

  describe "GET /templates/:id" do
    it "returns http success for valid template" do
      get template_path("individual_plaintiff")

      expect(response).to have_http_status(:success)
      expect(assigns(:template)).to eq(sample_template_full)
    end

    it "displays template details" do
      get template_path("individual_plaintiff")

      expect(response.body).to include("Individual Plaintiff")
      expect(response.body).to include("Quick fill for an individual filing a claim")
    end

    it "returns JSON when requested" do
      get template_path("individual_plaintiff"), headers: { "Accept" => "application/json" }

      expect(response.content_type).to include("application/json")
      json = JSON.parse(response.body)
      expect(json["scenario"]["id"]).to eq("individual_plaintiff")
      expect(json["scenario"]["name"]).to eq("Individual Plaintiff")
    end

    context "when template does not exist" do
      it "redirects to templates index with HTML" do
        get template_path("nonexistent")

        expect(response).to redirect_to(templates_path)
        expect(flash[:alert]).to eq("Template not found")
      end

      it "returns not_found with JSON" do
        get template_path("nonexistent"), headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("Template not found")
      end
    end
  end
end
