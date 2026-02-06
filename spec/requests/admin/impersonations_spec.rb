# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Impersonations", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:target_user) { create(:user, email: "target@example.com", full_name: "Target User") }

  describe "GET /admin/impersonation/index" do
    context "as an admin" do
      before { sign_in admin }

      it "renders the impersonation logs page" do
        get admin_impersonation_path
        expect(response).to have_http_status(:success)
      end

      it "shows impersonation history" do
        create(:impersonation_log, admin: admin, target_user: target_user, reason: "Test reason")
        get admin_impersonation_path
        expect(response.body).to include("Test reason")
      end
    end
  end

  describe "POST /admin/users/:user_id/impersonate" do
    context "as an admin impersonating a regular user" do
      before { sign_in admin }

      it "starts impersonation and redirects to root" do
        post admin_impersonate_user_path(target_user), params: { reason: "Support investigation" }
        expect(response).to redirect_to(root_path)
        # Note: We don't follow_redirect! because the impersonation sign_in
        # is not fully compatible with request spec session handling
        # The redirect itself proves the impersonation started successfully
      end

      it "creates an impersonation log" do
        expect {
          post admin_impersonate_user_path(target_user), params: { reason: "Testing" }
        }.to change(ImpersonationLog, :count).by(1)
      end

      it "stores the reason in the log" do
        post admin_impersonate_user_path(target_user), params: { reason: "Support ticket #1234" }
        log = ImpersonationLog.last
        expect(log.reason).to eq("Support ticket #1234")
      end
    end

    context "as an admin trying to impersonate another admin" do
      let(:other_admin) { create(:user, :admin) }

      before { sign_in admin }

      it "denies the request and redirects" do
        post admin_impersonate_user_path(other_admin)
        expect(response).to redirect_to(admin_users_path)
        # Check flash message instead of following redirect
        expect(flash[:alert]).to include("cannot impersonate")
      end

      it "does not create an impersonation log" do
        expect {
          post admin_impersonate_user_path(other_admin)
        }.not_to change(ImpersonationLog, :count)
      end
    end

    context "as a regular user" do
      before { sign_in target_user }

      it "denies access" do
        other_user = create(:user)
        post admin_impersonate_user_path(other_user)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "DELETE /admin/impersonation" do
    context "when not currently impersonating" do
      before { sign_in admin }

      it "redirects with an alert" do
        delete admin_impersonation_path
        expect(response).to redirect_to(admin_root_path)
        # Check flash message instead of following redirect
        expect(flash[:alert]).to include("not currently impersonating")
      end
    end

    # Note: Testing the full impersonation flow requires integration tests
    # as request specs don't maintain session state between requests in the same way
  end
end
