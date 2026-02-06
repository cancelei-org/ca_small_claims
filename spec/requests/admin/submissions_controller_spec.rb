# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Submissions", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:category) { create(:category) }
  let(:form_def) { create(:form_definition, code: "SC-100", category: category) }

  describe "GET /admin/submissions" do
    context "as an admin user" do
      before do
        login_as(admin_user, scope: :user)
      end

      it "returns http success" do
        get admin_submissions_path

        expect(response).to have_http_status(:success)
      end

      it "displays submissions with pagination" do
        create_list(:submission, 25, form_definition: form_def, user: regular_user)

        get admin_submissions_path

        expect(response).to have_http_status(:success)
        # Default limit is 20 per page
        expect(assigns(:submissions).count).to eq(20)
      end

      it "includes form definition and user information" do
        submission = create(:submission, form_definition: form_def, user: regular_user)

        get admin_submissions_path

        expect(response.body).to include(form_def.code)
        expect(response.body).to include(regular_user.email)
      end

      it "displays total counts" do
        create_list(:submission, 5, form_definition: form_def, user: regular_user)

        get admin_submissions_path

        expect(assigns(:total_count)).to eq(5)
      end

      it "filters by form definition" do
        form2 = create(:form_definition, code: "SC-105", category: category)
        submission1 = create(:submission, form_definition: form_def, user: regular_user)
        submission2 = create(:submission, form_definition: form2, user: regular_user)

        get admin_submissions_path, params: { form_id: form_def.id }

        submissions = assigns(:submissions)
        expect(submissions).to include(submission1)
        expect(submissions).not_to include(submission2)
      end

      it "filters by status" do
        draft = create(:submission, form_definition: form_def, user: regular_user, status: "draft")
        submitted = create(:submission, form_definition: form_def, user: regular_user, status: "submitted")

        get admin_submissions_path, params: { status: "draft" }

        submissions = assigns(:submissions)
        expect(submissions).to include(draft)
        expect(submissions).not_to include(submitted)
      end

      it "filters by user_id" do
        user2 = create(:user)
        submission1 = create(:submission, form_definition: form_def, user: regular_user)
        submission2 = create(:submission, form_definition: form_def, user: user2)

        get admin_submissions_path, params: { user_id: regular_user.id }

        submissions = assigns(:submissions)
        expect(submissions).to include(submission1)
        expect(submissions).not_to include(submission2)
      end

      it "filters by user type - registered" do
        registered = create(:submission, form_definition: form_def, user: regular_user)
        anonymous = create(:submission, form_definition: form_def, user: nil)

        get admin_submissions_path, params: { user_type: "registered" }

        submissions = assigns(:submissions)
        expect(submissions).to include(registered)
        expect(submissions).not_to include(anonymous)
      end

      it "filters by user type - anonymous" do
        registered = create(:submission, form_definition: form_def, user: regular_user)
        anonymous = create(:submission, form_definition: form_def, user: nil)

        get admin_submissions_path, params: { user_type: "anonymous" }

        submissions = assigns(:submissions)
        expect(submissions).to include(anonymous)
        expect(submissions).not_to include(registered)
      end

      it "filters by date range" do
        old_submission = create(:submission, form_definition: form_def, user: regular_user,
                                created_at: 5.days.ago)
        new_submission = create(:submission, form_definition: form_def, user: regular_user,
                                created_at: 1.day.ago)

        get admin_submissions_path, params: {
          date_from: 3.days.ago.to_date.to_s,
          date_to: Time.current.to_date.to_s
        }

        submissions = assigns(:submissions)
        expect(submissions).to include(new_submission)
        expect(submissions).not_to include(old_submission)
      end

      it "searches by submission ID" do
        submission = create(:submission, form_definition: form_def, user: regular_user)

        get admin_submissions_path, params: { search: submission.id.to_s }

        submissions = assigns(:submissions)
        expect(submissions).to include(submission)
        expect(submissions.count).to eq(1)
      end

      it "searches by user email" do
        user_with_email = create(:user, email: "specific@example.com")
        submission = create(:submission, form_definition: form_def, user: user_with_email)
        other_submission = create(:submission, form_definition: form_def, user: regular_user)

        get admin_submissions_path, params: { search: "specific" }

        submissions = assigns(:submissions)
        expect(submissions).to include(submission)
        expect(submissions).not_to include(other_submission)
      end
    end

    context "as a regular user" do
      before do
        login_as(regular_user, scope: :user)
      end

      it "denies access" do
        get admin_submissions_path

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        get admin_submissions_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /admin/submissions/:id" do
    let(:submission) { create(:submission, form_definition: form_def, user: regular_user) }

    context "as an admin user" do
      before do
        login_as(admin_user, scope: :user)
      end

      it "returns http success" do
        get admin_submission_path(submission)

        expect(response).to have_http_status(:success)
      end

      it "displays submission details" do
        get admin_submission_path(submission)

        expect(response.body).to include(form_def.code)
        expect(assigns(:submission)).to eq(submission)
      end

      it "includes associated form definition and user" do
        get admin_submission_path(submission)

        submission_obj = assigns(:submission)
        expect(submission_obj.association(:form_definition).loaded?).to be true
        expect(submission_obj.association(:user).loaded?).to be true
      end
    end

    context "as a regular user" do
      before do
        login_as(regular_user, scope: :user)
      end

      it "denies access" do
        get admin_submission_path(submission)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "PATCH /admin/submissions/:id/update_notes" do
    let(:submission) { create(:submission, form_definition: form_def, user: regular_user) }

    context "as an admin user" do
      before do
        login_as(admin_user, scope: :user)
      end

      it "updates admin notes" do
        patch update_notes_admin_submission_path(submission), params: { admin_notes: "Test note" }

        expect(response).to redirect_to(admin_submission_path(submission))
        expect(submission.reload.admin_notes).to eq("Test note")
      end

      it "returns JSON response when requested" do
        patch update_notes_admin_submission_path(submission),
              params: { admin_notes: "JSON note" },
              headers: { "HTTP_ACCEPT" => "application/json" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["success"]).to be true
        expect(json["admin_notes"]).to eq("JSON note")
      end

      it "allows clearing notes" do
        submission.update!(admin_notes: "Old note")

        patch update_notes_admin_submission_path(submission), params: { admin_notes: "" }

        expect(submission.reload.admin_notes).to be_blank
      end

      it "preserves multiline notes" do
        multiline = "Line 1\nLine 2\nLine 3"
        patch update_notes_admin_submission_path(submission), params: { admin_notes: multiline }

        expect(submission.reload.admin_notes).to eq(multiline)
      end
    end

    context "as a regular user" do
      before do
        login_as(regular_user, scope: :user)
      end

      it "denies access" do
        patch update_notes_admin_submission_path(submission), params: { admin_notes: "Test" }

        expect(response).to have_http_status(:forbidden)
        expect(submission.reload.admin_notes).to be_nil
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        patch update_notes_admin_submission_path(submission), params: { admin_notes: "Test" }

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
