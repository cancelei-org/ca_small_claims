# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V1::Forms", type: :request do
  let(:api_token) { "test_api_token_123" }
  let(:auth_headers) { { "Authorization" => "Bearer #{api_token}" } }

  before do
    # Stub environment variable and authentication
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("API_TOKEN").and_return(nil) # Disable auth for tests
  end

  describe "GET /api/v1/forms" do
    let!(:category) { create(:category, name: "Small Claims", slug: "small-claims") }
    let!(:form1) { create(:form_definition, code: "SC-100", title: "Plaintiff's Claim", category: category) }
    let!(:form2) { create(:form_definition, code: "SC-105", title: "Notice of Motion", category: category) }

    it "returns all forms successfully" do
      get "/api/v1/forms"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["data"]).to be_an(Array)
      expect(json["data"].length).to be >= 2
    end

    it "returns forms with correct structure" do
      get "/api/v1/forms"

      json = JSON.parse(response.body)
      form = json["data"].find { |f| f["code"] == "SC-100" }

      expect(form).to include("code" => "SC-100", "title" => "Plaintiff's Claim")
      expect(form).to have_key("category_id")
    end

    it "returns JSON content type" do
      get "/api/v1/forms"

      expect(response.content_type).to include("application/json")
    end
  end

  describe "GET /api/v1/forms/:id" do
    let!(:category) { create(:category, name: "Small Claims", slug: "small-claims") }
    let!(:form_def) do
      form = create(:form_definition, code: "SC-100", title: "Plaintiff's Claim",
                    description: "Test description", category: category, fillable: true)
      create(:field_definition, form_definition: form, name: "plaintiff_name",
             field_type: "text", required: true, position: 1)
      create(:field_definition, form_definition: form, name: "case_number",
             field_type: "text", required: false, position: 2)
      form
    end

    it "returns form details successfully" do
      get "/api/v1/forms/SC-100"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)

      expect(json["data"]["code"]).to eq("SC-100")
      expect(json["data"]["title"]).to eq("Plaintiff's Claim")
      expect(json["data"]["description"]).to eq("Test description")
      expect(json["data"]["category_id"]).to eq(category.id)
      expect(json["data"]["fillable"]).to be true
    end

    it "returns field definitions" do
      get "/api/v1/forms/SC-100"

      json = JSON.parse(response.body)
      fields = json["data"]["fields"]

      expect(fields).to be_an(Array)
      expect(fields.length).to eq(2)
      expect(fields.first).to eq([ "plaintiff_name", "text", true ])
      expect(fields.second).to eq([ "case_number", "text", false ])
    end

    it "accepts lowercase form codes" do
      get "/api/v1/forms/sc-100"

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["data"]["code"]).to eq("SC-100")
    end

    it "returns not_found for non-existent form" do
      get "/api/v1/forms/INVALID-999"

      expect(response).to have_http_status(:not_found)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("not_found")
    end
  end
end
