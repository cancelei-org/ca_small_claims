# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Submissions", type: :request do
  let!(:form_def) { create(:form_definition, code: "SC-100", title: "Plaintiff's Claim") }
  let!(:submission) { create(:submission, form_definition: form_def, session_id: "session-123") }

  before do
    # Simulate session
    allow_any_instance_of(SubmissionsController).to receive(:form_session_id).and_return("session-123")
  end

  describe "GET /submissions" do
    it "returns http success" do
      get submissions_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("SC-100")
    end
  end

  describe "GET /submissions/:id" do
    it "returns http success" do
      get submission_path(submission)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("SC-100")
    end

    it "redirects if unauthorized" do
      other_submission = create(:submission, session_id: "other-session")
      get submission_path(other_submission)
      expect(response).to redirect_to(submissions_path)
    end
  end

  describe "DELETE /submissions/:id" do
    it "destroys the submission" do
      expect {
        delete submission_path(submission)
      }.to change(Submission, :count).by(-1)
      expect(response).to redirect_to(submissions_path)
    end
  end

  describe "GET /submissions/:id/pdf" do
    let(:pdf_path) { Rails.root.join("tmp", "test.pdf") }

    before do
      File.write(pdf_path, "PDF CONTENT")
      allow_any_instance_of(Submission).to receive(:generate_pdf).and_return(pdf_path.to_s)
    end

    after do
      File.delete(pdf_path) if File.exist?(pdf_path)
    end

    it "returns PDF content" do
      get pdf_submission_path(submission)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to eq("application/pdf")
    end
  end

  describe "GET /submissions/:id/download_pdf" do
    let(:pdf_path) { Rails.root.join("tmp", "test_flat.pdf") }

    before do
      File.write(pdf_path, "FLATTENED PDF")
      allow_any_instance_of(Submission).to receive(:generate_flattened_pdf).and_return(pdf_path.to_s)
    end

    after do
      File.delete(pdf_path) if File.exist?(pdf_path)
    end

    it "downloads the PDF" do
      get download_pdf_submission_path(submission)
      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to include('attachment; filename="SC-100_')
    end
  end
end
