# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::ProductFeedbacks", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:user) { create(:user) }

  describe "GET /admin/product_feedbacks" do
    before { sign_in admin }

    it "returns http success" do
      get admin_product_feedbacks_path
      expect(response).to have_http_status(:success)
    end

    it "displays product feedbacks" do
      feedbacks = create_list(:product_feedback, 3)
      get admin_product_feedbacks_path
      feedbacks.each do |feedback|
        expect(response.body).to include(feedback.title)
      end
    end

    it "displays status counts" do
      create(:product_feedback, :pending)
      create(:product_feedback, :under_review)
      create(:product_feedback, :completed)

      get admin_product_feedbacks_path
      expect(response.body).to include("Pending")
      expect(response.body).to include("Under Review")
    end

    context "with filters" do
      let!(:bug_feedback) { create(:product_feedback, :bug) }
      let!(:feature_feedback) { create(:product_feedback, :feature) }

      it "filters by category" do
        get admin_product_feedbacks_path(category: "bug")
        expect(response.body).to include(bug_feedback.title)
        expect(response.body).not_to include(feature_feedback.title)
      end

      it "filters by status" do
        pending_feedback = create(:product_feedback, :pending)
        completed_feedback = create(:product_feedback, :completed)

        get admin_product_feedbacks_path(status: "pending")
        expect(response.body).to include(pending_feedback.title)
        expect(response.body).not_to include(completed_feedback.title)
      end
    end

    context "when not admin" do
      before do
        sign_out admin
        sign_in user
      end

      it "returns unauthorized" do
        get admin_product_feedbacks_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /admin/product_feedbacks/:id" do
    before { sign_in admin }

    let(:feedback) { create(:product_feedback, :with_admin_notes) }

    it "returns http success" do
      get admin_product_feedback_path(feedback)
      expect(response).to have_http_status(:success)
    end

    it "displays the feedback details" do
      get admin_product_feedback_path(feedback)
      expect(response.body).to include(feedback.title)
      expect(response.body).to include(feedback.description)
    end

    it "displays admin notes" do
      get admin_product_feedback_path(feedback)
      expect(response.body).to include(feedback.admin_notes)
    end

    it "displays status update buttons" do
      get admin_product_feedback_path(feedback)
      expect(response.body).to include("Update Status")
    end
  end

  describe "PATCH /admin/product_feedbacks/:id" do
    before { sign_in admin }

    let(:feedback) { create(:product_feedback, :pending) }

    it "updates the feedback status" do
      patch admin_product_feedback_path(feedback), params: {
        product_feedback: { status: "under_review" }
      }
      expect(feedback.reload.status).to eq("under_review")
    end

    it "updates admin notes" do
      patch admin_product_feedback_path(feedback), params: {
        product_feedback: { admin_notes: "New admin note" }
      }
      expect(feedback.reload.admin_notes).to eq("New admin note")
    end

    it "redirects to product feedbacks index" do
      patch admin_product_feedback_path(feedback), params: {
        product_feedback: { status: "under_review" }
      }
      expect(response).to redirect_to(admin_product_feedbacks_path)
    end
  end

  describe "PATCH /admin/product_feedbacks/:id/update_status" do
    before { sign_in admin }

    let(:feedback) { create(:product_feedback, :pending) }

    it "updates the status" do
      patch update_status_admin_product_feedback_path(feedback), params: { status: "planned" }
      expect(feedback.reload.status).to eq("planned")
    end

    it "enqueues a status change notification email" do
      expect {
        patch update_status_admin_product_feedback_path(feedback), params: { status: "planned" }
      }.to have_enqueued_mail(ProductFeedbackMailer, :status_changed)
    end

    it "rejects invalid statuses" do
      patch update_status_admin_product_feedback_path(feedback), params: { status: "invalid" }
      expect(feedback.reload.status).to eq("pending")
    end
  end

  describe "PATCH /admin/product_feedbacks/:id/update_admin_notes" do
    before { sign_in admin }

    let(:feedback) { create(:product_feedback) }

    it "updates admin notes" do
      patch update_admin_notes_admin_product_feedback_path(feedback), params: { admin_notes: "Updated notes" }
      expect(feedback.reload.admin_notes).to eq("Updated notes")
    end

    it "sanitizes admin notes" do
      patch update_admin_notes_admin_product_feedback_path(feedback), params: { admin_notes: "Notes\x00with\x01control\x02chars" }
      expect(feedback.reload.admin_notes).not_to include("\x00")
    end
  end

  describe "GET /admin/product_feedbacks/export" do
    before { sign_in admin }

    let!(:feedbacks) { create_list(:product_feedback, 3) }

    it "returns a CSV file" do
      get export_admin_product_feedbacks_path(format: :csv)
      expect(response.content_type).to include("text/csv")
    end

    it "includes feedback data in CSV" do
      get export_admin_product_feedbacks_path(format: :csv)
      feedbacks.each do |feedback|
        expect(response.body).to include(feedback.title)
      end
    end

    it "includes appropriate headers" do
      get export_admin_product_feedbacks_path(format: :csv)
      expect(response.body).to include("ID")
      expect(response.body).to include("Category")
      expect(response.body).to include("Status")
      expect(response.body).to include("Title")
    end
  end
end
