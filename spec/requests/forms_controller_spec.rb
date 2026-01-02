# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Forms", type: :request do
  let!(:category) { create(:category, name: "Small Claims", slug: "small-claims") }
  let!(:form_def) { create(:form_definition, code: "SC-100", title: "Plaintiff's Claim", category: category) }
  let(:user) { create(:user) }

  describe "GET /forms" do
    it "returns http success" do
      get forms_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("SC-100")
    end

    it "filters by category" do
      other_cat = create(:category, name: "Other", slug: "other")
      create(:form_definition, code: "OT-100", category: other_cat)

      get forms_path(category: "small-claims")
      expect(response.body).to include("SC-100")
      expect(response.body).not_to include("OT-100")
    end

    it "searches by query" do
      create(:form_definition, code: "XX-999", title: "Random Form")

      get forms_path(search: "Plaintiff")
      expect(response.body).to include("SC-100")
      expect(response.body).not_to include("XX-999")
    end
  end

  describe "GET /forms/:id" do
    it "returns http success" do
      get form_path(form_def.code)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("SC-100")
    end

    it "initializes a submission" do
      expect {
        get form_path(form_def.code)
      }.to change(Submission, :count).by(1)
    end

    it "supports wizard mode toggle via param" do
      get form_path(form_def.code, wizard: "true")
      expect(response.body).to include("wizard-container")
    end
  end

  describe "PATCH /forms/:id" do
    let(:params) { { submission: { "field1" => "value1" } } }

    it "updates the submission" do
      get form_path(form_def.code) # Ensure session exists
      patch form_path(form_def.code), params: params, headers: { "HTTP_ACCEPT" => "application/json" }

      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end
  end

  describe "POST /forms/:id/toggle_wizard" do
    it "toggles session preference and redirects" do
      post toggle_wizard_form_path(form_def.code)
      expect(response).to redirect_to(form_path(form_def.code))
    end
  end

  describe "GET /forms/:id/preview" do
    let(:pdf_path) { Rails.root.join("tmp", "test.pdf") }

    before do
      File.write(pdf_path, "PDF CONTENT")
      allow_any_instance_of(Submission).to receive(:generate_pdf).and_return(pdf_path.to_s)
    end

    after do
      File.delete(pdf_path) if File.exist?(pdf_path)
    end

    it "returns PDF content" do
      get preview_form_path(form_def.code)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq("application/pdf")
    end
  end

  describe "GET /forms/:id/download" do
    let(:pdf_path) { Rails.root.join("tmp", "test_flat.pdf") }

    before do
      File.write(pdf_path, "FLATTENED PDF")
      allow_any_instance_of(Submission).to receive(:generate_flattened_pdf).and_return(pdf_path.to_s)
    end

    after do
      File.delete(pdf_path) if File.exist?(pdf_path)
    end

    it "downloads the PDF" do
      get download_form_path(form_def.code)
      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to include('attachment; filename="SC-100_')
    end
  end
end
