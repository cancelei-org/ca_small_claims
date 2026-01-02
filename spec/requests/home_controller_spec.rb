# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Home", type: :request do
  let!(:category) { create(:category, name: "Small Claims", slug: "small-claims") }
  let!(:subcategory) { create(:category, name: "Plaintiff", slug: "plaintiff", parent: category) }
  let!(:form_def) { create(:form_definition, code: "SC-100", title: "Plaintiff's Claim", category: subcategory) }
  let!(:workflow) { create(:workflow, name: "File a Claim") }

  describe "GET /" do
    it "returns http success" do
      get root_path
      expect(response).to have_http_status(:success)
    end

    it "displays featured workflows" do
      get root_path
      expect(response.body).to include("File a Claim")
    end

    it "displays categories" do
      get root_path
      expect(response.body).to include("Plaintiff")
    end
  end

  describe "GET /home/forms_picker" do
    it "returns forms as turbo_stream" do
      get forms_picker_home_path, headers: { "Accept" => "text/vnd.turbo-stream.html" }
      expect(response).to have_http_status(:success)
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    end

    it "filters by search" do
      create(:form_definition, code: "XX-999", title: "Unrelated Form")

      get forms_picker_home_path, params: { search: "Plaintiff" }
      expect(response.body).to include("SC-100")
      expect(response.body).not_to include("XX-999")
    end

    it "filters by category" do
      other_cat = create(:category, name: "Other", slug: "other", parent: category)
      create(:form_definition, code: "OT-100", category: other_cat)

      get forms_picker_home_path, params: { category: "plaintiff" }
      expect(response.body).to include("SC-100")
      expect(response.body).not_to include("OT-100")
    end
  end

  describe "GET /about" do
    it "returns http success" do
      get about_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /help" do
    it "returns http success" do
      get help_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /accessibility" do
    it "returns http success" do
      get accessibility_path
      expect(response).to have_http_status(:success)
    end
  end
end
