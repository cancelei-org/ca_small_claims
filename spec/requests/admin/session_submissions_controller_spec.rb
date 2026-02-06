# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::SessionSubmissions", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:form_def) { create(:form_definition, code: "SC-100") }

  describe "GET /admin/session_submissions" do
    context "as an admin user" do
      before { login_as(admin_user, scope: :user) }

      it "returns http success" do
        get admin_session_submissions_path
        expect(response).to have_http_status(:success)
      end

      it "displays session submissions" do
        create(:session_submission, form_definition: form_def, session_id: "test-session-123")
        get admin_session_submissions_path
        expect(response.body).to include("test-session")
      end

      it "shows active and expired counts" do
        create(:session_submission, form_definition: form_def, expires_at: 1.day.from_now)
        create(:session_submission, form_definition: form_def, expires_at: 1.day.ago)

        get admin_session_submissions_path

        expect(assigns(:total_active)).to eq(1)
        expect(assigns(:total_expired)).to eq(1)
      end

      it "filters by status - active" do
        active = create(:session_submission, form_definition: form_def, expires_at: 1.day.from_now)
        expired = create(:session_submission, form_definition: form_def, expires_at: 1.day.ago)

        get admin_session_submissions_path, params: { status: "active" }

        submissions = assigns(:session_submissions)
        expect(submissions).to include(active)
        expect(submissions).not_to include(expired)
      end

      it "filters by status - expired" do
        active = create(:session_submission, form_definition: form_def, expires_at: 1.day.from_now)
        expired = create(:session_submission, form_definition: form_def, expires_at: 1.day.ago)

        get admin_session_submissions_path, params: { status: "expired" }

        submissions = assigns(:session_submissions)
        expect(submissions).to include(expired)
        expect(submissions).not_to include(active)
      end

      it "filters by form_id" do
        form2 = create(:form_definition, code: "SC-105")
        session1 = create(:session_submission, form_definition: form_def)
        session2 = create(:session_submission, form_definition: form2)

        get admin_session_submissions_path, params: { form_id: form_def.id }

        submissions = assigns(:session_submissions)
        expect(submissions).to include(session1)
        expect(submissions).not_to include(session2)
      end

      it "searches by session_id" do
        target = create(:session_submission, form_definition: form_def, session_id: "target-session")
        other = create(:session_submission, form_definition: form_def, session_id: "other-session")

        get admin_session_submissions_path, params: { session_id: "target-session" }

        submissions = assigns(:session_submissions)
        expect(submissions).to include(target)
        expect(submissions).not_to include(other)
      end
    end

    context "as a regular user" do
      before { login_as(regular_user, scope: :user) }

      it "denies access" do
        get admin_session_submissions_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /admin/session_submissions/:id" do
    let(:session_submission) { create(:session_submission, form_definition: form_def) }

    context "as an admin user" do
      before { login_as(admin_user, scope: :user) }

      it "returns http success" do
        get admin_session_submission_path(session_submission)
        expect(response).to have_http_status(:success)
      end

      it "displays session details" do
        get admin_session_submission_path(session_submission)
        expect(response.body).to include(form_def.code)
      end
    end
  end

  describe "PATCH /admin/session_submissions/:id/recover" do
    let(:expired_session) { create(:session_submission, form_definition: form_def, expires_at: 1.day.ago) }
    let(:active_session) { create(:session_submission, form_definition: form_def, expires_at: 1.day.from_now) }

    context "as an admin user" do
      before { login_as(admin_user, scope: :user) }

      it "recovers an expired session" do
        patch recover_admin_session_submission_path(expired_session)

        expect(response).to redirect_to(admin_session_submissions_path)
        expect(expired_session.reload.expires_at).to be > Time.current
      end

      it "extends expiration by 72 hours" do
        patch recover_admin_session_submission_path(expired_session)

        expect(expired_session.reload.expires_at).to be_within(1.minute).of(72.hours.from_now)
      end

      it "returns JSON response when requested" do
        patch recover_admin_session_submission_path(expired_session),
              headers: { "HTTP_ACCEPT" => "application/json" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end

      it "does not recover active session" do
        patch recover_admin_session_submission_path(active_session)

        expect(response).to redirect_to(admin_session_submissions_path)
        expect(flash[:alert]).to include("not expired")
      end
    end
  end

  describe "DELETE /admin/session_submissions/:id" do
    let!(:session_submission) { create(:session_submission, form_definition: form_def) }

    context "as an admin user" do
      before { login_as(admin_user, scope: :user) }

      it "deletes the session submission" do
        expect {
          delete admin_session_submission_path(session_submission)
        }.to change(SessionSubmission, :count).by(-1)

        expect(response).to redirect_to(admin_session_submissions_path)
      end

      it "returns JSON response when requested" do
        delete admin_session_submission_path(session_submission),
               headers: { "HTTP_ACCEPT" => "application/json" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
      end
    end
  end

  describe "DELETE /admin/session_submissions/cleanup_expired" do
    context "as an admin user" do
      before { login_as(admin_user, scope: :user) }

      it "deletes all expired sessions" do
        create(:session_submission, form_definition: form_def, expires_at: 1.day.ago)
        create(:session_submission, form_definition: form_def, expires_at: 2.days.ago)
        active = create(:session_submission, form_definition: form_def, expires_at: 1.day.from_now)

        expect {
          delete cleanup_expired_admin_session_submissions_path
        }.to change(SessionSubmission, :count).by(-2)

        expect(SessionSubmission.exists?(active.id)).to be true
      end

      it "redirects with count notice" do
        create_list(:session_submission, 3, form_definition: form_def, expires_at: 1.day.ago)

        delete cleanup_expired_admin_session_submissions_path

        expect(response).to redirect_to(admin_session_submissions_path)
        expect(flash[:notice]).to include("3")
      end
    end
  end

  describe "PATCH /admin/session_submissions/bulk_recover" do
    context "as an admin user" do
      before { login_as(admin_user, scope: :user) }

      it "recovers multiple expired sessions" do
        expired1 = create(:session_submission, form_definition: form_def, expires_at: 1.day.ago)
        expired2 = create(:session_submission, form_definition: form_def, expires_at: 2.days.ago)

        patch bulk_recover_admin_session_submissions_path, params: { ids: [ expired1.id, expired2.id ] }

        expect(expired1.reload.expires_at).to be > Time.current
        expect(expired2.reload.expires_at).to be > Time.current
        expect(response).to redirect_to(admin_session_submissions_path)
      end

      it "only recovers expired sessions from provided ids" do
        expired = create(:session_submission, form_definition: form_def, expires_at: 1.day.ago)
        active = create(:session_submission, form_definition: form_def, expires_at: 1.day.from_now)
        original_expires = active.expires_at

        patch bulk_recover_admin_session_submissions_path, params: { ids: [ expired.id, active.id ] }

        expect(active.reload.expires_at).to eq(original_expires)
      end
    end
  end
end
