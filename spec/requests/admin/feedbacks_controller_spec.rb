# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Feedbacks", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:category) { create(:category) }
  let(:form_def) { create(:form_definition, code: "SC-100", category: category) }

  describe "GET /admin/feedbacks" do
    context "as an admin user" do
      before do
        sign_in admin_user
      end

      it "returns http success" do
        get admin_feedbacks_path

        expect(response).to have_http_status(:success)
      end

      it "displays feedbacks with pagination" do
        create_list(:form_feedback, 25, form_definition: form_def, user: regular_user)

        get admin_feedbacks_path

        expect(response).to have_http_status(:success)
        expect(assigns(:feedbacks).count).to eq(20) # Default limit
      end

      it "displays pending count" do
        create_list(:form_feedback, 5, :pending, form_definition: form_def)
        create_list(:form_feedback, 3, :acknowledged, form_definition: form_def)

        get admin_feedbacks_path

        expect(assigns(:pending_count)).to eq(5)
      end

      it "filters by form definition" do
        form2 = create(:form_definition, code: "SC-105", category: category)
        feedback1 = create(:form_feedback, form_definition: form_def)
        feedback2 = create(:form_feedback, form_definition: form2)

        get admin_feedbacks_path, params: { form_id: form_def.id }

        feedbacks = assigns(:feedbacks)
        expect(feedbacks).to include(feedback1)
        expect(feedbacks).not_to include(feedback2)
      end

      it "filters by status" do
        open_feedback = create(:form_feedback, :pending, form_definition: form_def)
        in_progress_feedback = create(:form_feedback, :acknowledged, form_definition: form_def)

        get admin_feedbacks_path, params: { status: "open" }

        feedbacks = assigns(:feedbacks)
        expect(feedbacks).to include(open_feedback)
        expect(feedbacks).not_to include(in_progress_feedback)
      end

      it "filters by issue type" do
        technical = create(:form_feedback, form_definition: form_def, issue_types: [ "pdf_not_filling" ])
        unclear = create(:form_feedback, form_definition: form_def, issue_types: [ "fields_unclear" ])

        get admin_feedbacks_path, params: { issue_type: "pdf_not_filling" }

        feedbacks = assigns(:feedbacks)
        expect(feedbacks).to include(technical)
        expect(feedbacks).not_to include(unclear)
      end

      it "filters by rating" do
        high_rating = create(:form_feedback, form_definition: form_def, rating: 5)
        low_rating = create(:form_feedback, form_definition: form_def, rating: 1)

        get admin_feedbacks_path, params: { rating: "5" }

        feedbacks = assigns(:feedbacks)
        expect(feedbacks).to include(high_rating)
        expect(feedbacks).not_to include(low_rating)
      end

      it "filters by date range" do
        old_feedback = create(:form_feedback, form_definition: form_def, created_at: 5.days.ago)
        new_feedback = create(:form_feedback, form_definition: form_def, created_at: 1.day.ago)

        get admin_feedbacks_path, params: {
          date_from: 3.days.ago.to_date.to_s,
          date_to: Time.current.to_date.to_s
        }

        feedbacks = assigns(:feedbacks)
        expect(feedbacks).to include(new_feedback)
        expect(feedbacks).not_to include(old_feedback)
      end
    end

    context "as a regular user" do
      before do
        sign_in regular_user
      end

      it "denies access" do
        get admin_feedbacks_path

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        get admin_feedbacks_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /admin/feedbacks/:id" do
    let(:feedback) { create(:form_feedback, form_definition: form_def, user: regular_user) }

    context "as an admin user" do
      before do
        sign_in admin_user
      end

      it "returns http success" do
        get admin_feedback_path(feedback)

        expect(response).to have_http_status(:success)
      end

      it "displays feedback details" do
        get admin_feedback_path(feedback)

        expect(assigns(:feedback)).to eq(feedback)
        expect(assigns(:pending_count)).to be_a(Integer)
      end
    end

    context "as a regular user" do
      before do
        sign_in regular_user
      end

      it "denies access" do
        get admin_feedback_path(feedback)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/feedbacks/:id" do
    let(:feedback) { create(:form_feedback, :pending, form_definition: form_def) }

    context "as an admin user" do
      before do
        sign_in admin_user
      end

      it "updates feedback with valid params" do
        patch admin_feedback_path(feedback), params: {
          form_feedback: { admin_notes: "Updated notes", status: "in_progress" }
        }

        expect(response).to redirect_to(admin_feedbacks_path)
        feedback.reload
        expect(feedback.admin_notes).to eq("Updated notes")
        expect(feedback.status).to eq("in_progress")
      end

      it "handles turbo_stream requests" do
        patch admin_feedback_path(feedback),
              params: { form_feedback: { admin_notes: "Test" } },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("turbo-stream")
      end
    end

    context "as a regular user" do
      before do
        sign_in regular_user
      end

      it "denies access" do
        patch admin_feedback_path(feedback), params: {
          form_feedback: { admin_notes: "Notes" }
        }

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/feedbacks/:id/acknowledge" do
    let(:feedback) { create(:form_feedback, :pending, form_definition: form_def) }

    context "as an admin user" do
      before do
        sign_in admin_user
      end

      it "acknowledges the feedback" do
        patch acknowledge_admin_feedback_path(feedback)

        expect(response).to redirect_to(admin_feedbacks_path)
        feedback.reload
        expect(feedback.status).to eq("in_progress")
      end

      it "handles turbo_stream requests" do
        patch acknowledge_admin_feedback_path(feedback),
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("turbo-stream")
      end
    end

    context "as a regular user" do
      before do
        sign_in regular_user
      end

      it "denies access" do
        patch acknowledge_admin_feedback_path(feedback)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/feedbacks/:id/resolve" do
    let(:feedback) { create(:form_feedback, :acknowledged, form_definition: form_def) }

    context "as an admin user" do
      before do
        sign_in admin_user
      end

      it "resolves the feedback" do
        patch resolve_admin_feedback_path(feedback), params: { admin_notes: "Fixed the issue" }

        expect(response).to redirect_to(admin_feedbacks_path)
        feedback.reload
        expect(feedback.status).to eq("resolved")
        expect(feedback.resolved_by_id).to eq(admin_user.id)
        expect(feedback.resolved_at).to be_present
      end

      it "handles turbo_stream requests" do
        patch resolve_admin_feedback_path(feedback),
              params: { admin_notes: "Fixed" },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("turbo-stream")
      end
    end

    context "as a regular user" do
      before do
        sign_in regular_user
      end

      it "denies access" do
        patch resolve_admin_feedback_path(feedback)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/feedbacks/:id/close" do
    let(:feedback) { create(:form_feedback, :acknowledged, form_definition: form_def) }

    context "as an admin user" do
      before { sign_in admin_user }

      it "closes the feedback" do
        patch close_admin_feedback_path(feedback), params: { admin_notes: "Closing as duplicate" }

        expect(response).to redirect_to(admin_feedbacks_path)
        feedback.reload
        expect(feedback.status).to eq("closed")
        expect(feedback.resolved_by_id).to eq(admin_user.id)
        expect(feedback.resolved_at).to be_present
      end

      it "handles turbo_stream requests" do
        patch close_admin_feedback_path(feedback),
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("turbo-stream")
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "denies access" do
        patch close_admin_feedback_path(feedback)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/feedbacks/:id/reopen" do
    let(:feedback) { create(:form_feedback, :resolved, form_definition: form_def) }

    context "as an admin user" do
      before { sign_in admin_user }

      it "reopens the feedback" do
        patch reopen_admin_feedback_path(feedback)

        expect(response).to redirect_to(admin_feedbacks_path)
        feedback.reload
        expect(feedback.status).to eq("open")
        expect(feedback.resolved_by_id).to be_nil
        expect(feedback.resolved_at).to be_nil
      end

      it "handles turbo_stream requests" do
        patch reopen_admin_feedback_path(feedback),
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("turbo-stream")
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "denies access" do
        patch reopen_admin_feedback_path(feedback)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/feedbacks/:id/escalate" do
    let(:feedback) { create(:form_feedback, form_definition: form_def, priority: "low") }

    context "as an admin user" do
      before { sign_in admin_user }

      it "escalates the feedback priority" do
        patch escalate_admin_feedback_path(feedback)

        expect(response).to redirect_to(admin_feedbacks_path)
        feedback.reload
        expect(feedback.priority).to eq("medium")
      end

      it "escalates from medium to high" do
        feedback.update!(priority: "medium")
        patch escalate_admin_feedback_path(feedback)
        expect(feedback.reload.priority).to eq("high")
      end

      it "escalates from high to urgent" do
        feedback.update!(priority: "high")
        patch escalate_admin_feedback_path(feedback)
        expect(feedback.reload.priority).to eq("urgent")
      end

      it "handles turbo_stream requests" do
        patch escalate_admin_feedback_path(feedback),
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("turbo-stream")
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "denies access" do
        patch escalate_admin_feedback_path(feedback)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/feedbacks/:id/de_escalate" do
    let(:feedback) { create(:form_feedback, form_definition: form_def, priority: "urgent") }

    context "as an admin user" do
      before { sign_in admin_user }

      it "de-escalates the feedback priority" do
        patch de_escalate_admin_feedback_path(feedback)

        expect(response).to redirect_to(admin_feedbacks_path)
        feedback.reload
        expect(feedback.priority).to eq("high")
      end

      it "de-escalates from high to medium" do
        feedback.update!(priority: "high")
        patch de_escalate_admin_feedback_path(feedback)
        expect(feedback.reload.priority).to eq("medium")
      end

      it "de-escalates from medium to low" do
        feedback.update!(priority: "medium")
        patch de_escalate_admin_feedback_path(feedback)
        expect(feedback.reload.priority).to eq("low")
      end

      it "handles turbo_stream requests" do
        patch de_escalate_admin_feedback_path(feedback),
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("turbo-stream")
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "denies access" do
        patch de_escalate_admin_feedback_path(feedback)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/feedbacks/:id/set_priority" do
    let(:feedback) { create(:form_feedback, form_definition: form_def, priority: "low") }

    context "as an admin user" do
      before { sign_in admin_user }

      it "sets the feedback priority directly" do
        patch set_priority_admin_feedback_path(feedback), params: { priority: "urgent" }

        expect(response).to redirect_to(admin_feedbacks_path)
        feedback.reload
        expect(feedback.priority).to eq("urgent")
      end

      it "rejects invalid priority values" do
        patch set_priority_admin_feedback_path(feedback), params: { priority: "invalid" }

        feedback.reload
        expect(feedback.priority).to eq("low") # unchanged
      end

      it "handles turbo_stream requests" do
        patch set_priority_admin_feedback_path(feedback),
              params: { priority: "high" },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:success)
        expect(response.content_type).to include("turbo-stream")
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "denies access" do
        patch set_priority_admin_feedback_path(feedback), params: { priority: "high" }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/feedbacks/bulk_acknowledge" do
    context "as an admin user" do
      before { sign_in admin_user }

      it "acknowledges multiple pending feedbacks" do
        pending1 = create(:form_feedback, :pending, form_definition: form_def)
        pending2 = create(:form_feedback, :pending, form_definition: form_def)

        patch bulk_acknowledge_admin_feedbacks_path, params: { ids: [ pending1.id, pending2.id ] }

        expect(response).to redirect_to(admin_feedbacks_path)
        expect(pending1.reload.status).to eq("in_progress")
        expect(pending2.reload.status).to eq("in_progress")
      end

      it "only acknowledges pending feedbacks" do
        pending = create(:form_feedback, :pending, form_definition: form_def)
        resolved = create(:form_feedback, :resolved, form_definition: form_def)

        patch bulk_acknowledge_admin_feedbacks_path, params: { ids: [ pending.id, resolved.id ] }

        expect(pending.reload.status).to eq("in_progress")
        expect(resolved.reload.status).to eq("resolved")
      end

      it "returns JSON response when requested" do
        pending1 = create(:form_feedback, :pending, form_definition: form_def)
        pending2 = create(:form_feedback, :pending, form_definition: form_def)

        patch bulk_acknowledge_admin_feedbacks_path,
              params: { ids: [ pending1.id, pending2.id ] },
              headers: { "HTTP_ACCEPT" => "application/json" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["updated_count"]).to eq(2)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "denies access" do
        patch bulk_acknowledge_admin_feedbacks_path, params: { ids: [] }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/feedbacks/bulk_resolve" do
    context "as an admin user" do
      before { sign_in admin_user }

      it "resolves multiple unresolved feedbacks" do
        pending = create(:form_feedback, :pending, form_definition: form_def)
        acknowledged = create(:form_feedback, :acknowledged, form_definition: form_def)

        patch bulk_resolve_admin_feedbacks_path, params: { ids: [ pending.id, acknowledged.id ] }

        expect(response).to redirect_to(admin_feedbacks_path)
        expect(pending.reload.status).to eq("resolved")
        expect(acknowledged.reload.status).to eq("resolved")
      end

      it "does not re-resolve already resolved feedbacks" do
        resolved = create(:form_feedback, :resolved, form_definition: form_def, resolved_by: regular_user)
        original_resolver = resolved.resolved_by_id

        patch bulk_resolve_admin_feedbacks_path, params: { ids: [ resolved.id ] }

        expect(resolved.reload.resolved_by_id).to eq(original_resolver)
      end

      it "sets admin_notes when provided" do
        pending = create(:form_feedback, :pending, form_definition: form_def)

        patch bulk_resolve_admin_feedbacks_path, params: { ids: [ pending.id ], admin_notes: "Bulk resolved" }

        expect(pending.reload.admin_notes).to eq("Bulk resolved")
      end

      it "returns JSON response when requested" do
        pending = create(:form_feedback, :pending, form_definition: form_def)

        patch bulk_resolve_admin_feedbacks_path,
              params: { ids: [ pending.id ] },
              headers: { "HTTP_ACCEPT" => "application/json" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["resolved_count"]).to eq(1)
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "denies access" do
        patch bulk_resolve_admin_feedbacks_path, params: { ids: [] }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /admin/feedbacks/bulk_delete" do
    context "as an admin user" do
      before { sign_in admin_user }

      it "deletes multiple feedbacks" do
        feedback1 = create(:form_feedback, form_definition: form_def)
        feedback2 = create(:form_feedback, form_definition: form_def)

        expect {
          delete bulk_delete_admin_feedbacks_path, params: { ids: [ feedback1.id, feedback2.id ] }
        }.to change(FormFeedback, :count).by(-2)

        expect(response).to redirect_to(admin_feedbacks_path)
      end

      it "returns JSON response when requested" do
        feedback1 = create(:form_feedback, form_definition: form_def)
        feedback2 = create(:form_feedback, form_definition: form_def)

        delete bulk_delete_admin_feedbacks_path,
               params: { ids: [ feedback1.id, feedback2.id ] },
               headers: { "HTTP_ACCEPT" => "application/json" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["deleted_count"]).to eq(2)
      end

      it "handles empty ids gracefully" do
        delete bulk_delete_admin_feedbacks_path, params: { ids: [] }

        expect(response).to redirect_to(admin_feedbacks_path)
        expect(flash[:notice]).to include("0")
      end
    end

    context "as a regular user" do
      before { sign_in regular_user }

      it "denies access" do
        delete bulk_delete_admin_feedbacks_path, params: { ids: [] }
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
