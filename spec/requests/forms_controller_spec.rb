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

  describe "GET /forms with sorting" do
    let!(:popular_form) { create(:form_definition, code: "POP-100", category: category) }

    before do
      # Create submissions to make form popular
      create_list(:submission, 10, form_definition: popular_form)
    end

    it "sorts by popularity when requested" do
      get forms_path(sort: "popular")
      expect(response).to have_http_status(:success)
    end

    it "uses default ordering otherwise" do
      get forms_path(sort: "default")
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /forms/:id/apply_template" do
    let(:template_id) { "simple_scenario" }
    let(:applier) { instance_double(Templates::Applier) }

    before do
      allow(Templates::Applier).to receive(:new).and_return(applier)
    end

    context "with successful application" do
      before do
        allow(applier).to receive(:apply).and_return({ success: true, applied_fields: [] })
      end

      it "redirects with success notice for HTML" do
        post apply_template_form_path(form_def.code), params: { template_id: template_id }
        expect(response).to redirect_to(form_path(form_def.code))
        follow_redirect!
        expect(response.body).to include("Template applied")
      end

      it "returns JSON for API requests" do
        post apply_template_form_path(form_def.code),
             params: { template_id: template_id },
             headers: { "HTTP_ACCEPT" => "application/json" }
        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end
    end

    context "with failed application" do
      before do
        allow(applier).to receive(:apply).and_return({ success: false, errors: [ "Invalid template" ] })
      end

      it "redirects with alert for HTML" do
        post apply_template_form_path(form_def.code), params: { template_id: template_id }
        expect(response).to redirect_to(form_path(form_def.code))
      end

      it "returns error JSON for API requests" do
        post apply_template_form_path(form_def.code),
             params: { template_id: template_id },
             headers: { "HTTP_ACCEPT" => "application/json" }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "DELETE /forms/:id/clear_template" do
    before do
      get form_path(form_def.code) # Create submission
    end

    it "clears template metadata" do
      delete clear_template_form_path(form_def.code)
      expect(response).to redirect_to(form_path(form_def.code))
    end

    it "returns JSON for API requests" do
      delete clear_template_form_path(form_def.code),
             headers: { "HTTP_ACCEPT" => "application/json" }
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json["success"]).to be true
    end
  end

  describe "authenticated user features" do
    before do
      login_as(user, scope: :user)
    end

    it "shows form for authenticated user" do
      get form_path(form_def.code)
      expect(response).to have_http_status(:success)
    end

    it "supports skip_filled parameter for authenticated users" do
      get form_path(form_def.code, skip_filled: "true")
      expect(response).to have_http_status(:success)
    end

    it "creates submission associated with user" do
      expect {
        get form_path(form_def.code)
      }.to change { user.submissions.count }.by(1)
    end
  end

  describe "form lookup" do
    it "finds form by slug" do
      form_def.update!(slug: "plaintiffs-claim")
      get form_path("plaintiffs-claim")
      expect(response).to have_http_status(:success)
    end

    it "finds form by uppercase code" do
      get form_path("SC-100")
      expect(response).to have_http_status(:success)
    end

    it "returns 404 for invalid form" do
      get "/forms/INVALID-999"
      expect(response).to have_http_status(:not_found)
    end
  end
end
