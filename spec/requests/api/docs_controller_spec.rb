# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Docs", type: :request do
  describe "GET /api/docs" do
    let(:openapi_path) { Rails.root.join("docs", "api", "openapi.yml") }

    before do
      FileUtils.mkdir_p(Rails.root.join("docs", "api"))
      File.write(openapi_path, "openapi: 3.0.0\ninfo:\n  title: Test API\n  version: 1.0.0\n")
    end

    after do
      File.delete(openapi_path) if File.exist?(openapi_path)
    end

    it "returns the OpenAPI specification" do
      get "/api/docs"

      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq("text/yaml")
    end

    it "does not require authentication" do
      # Even if API_TOKEN is set, docs endpoint should be accessible
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("API_TOKEN").and_return("some_token")

      get "/api/docs"

      expect(response).to have_http_status(:success)
    end

    it "serves the correct file content" do
      get "/api/docs"

      expect(response.body).to include("openapi: 3.0.0")
      expect(response.body).to include("title: Test API")
    end

    context "when OpenAPI file does not exist" do
      before do
        File.delete(openapi_path) if File.exist?(openapi_path)
      end

      it "returns not found error" do
        expect {
          get "/api/docs"
        }.to raise_error(ActionController::MissingFile)
      end
    end
  end
end
