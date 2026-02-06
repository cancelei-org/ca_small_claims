# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  describe "GET /admin/users" do
    context "as an admin user" do
      before do
        login_as(admin_user, scope: :user)
      end

      it "returns http success" do
        get admin_users_path

        expect(response).to have_http_status(:success)
      end

      it "displays users with pagination" do
        create_list(:user, 25)

        get admin_users_path

        expect(response).to have_http_status(:success)
        expect(assigns(:users).count).to eq(20) # Default limit
      end

      it "displays total and type counts" do
        create_list(:user, 5)
        create_list(:user, 3, :guest)

        get admin_users_path

        expect(assigns(:total_count)).to be >= 8
        expect(assigns(:registered_count)).to be >= 5
        expect(assigns(:guest_count)).to be >= 3
      end

      it "filters by search term" do
        user1 = create(:user, email: "searchable@example.com")
        user2 = create(:user, email: "other@test.com")

        get admin_users_path, params: { search: "searchable" }

        users = assigns(:users)
        expect(users).to include(user1)
        expect(users).not_to include(user2)
      end

      it "filters by user type - registered" do
        registered = create(:user)
        guest = create(:user, :guest)

        get admin_users_path, params: { user_type: "registered" }

        users = assigns(:users)
        expect(users).to include(registered)
        expect(users).not_to include(guest)
      end

      it "filters by user type - guest" do
        registered = create(:user)
        guest = create(:user, :guest)

        get admin_users_path, params: { user_type: "guest" }

        users = assigns(:users)
        expect(users).to include(guest)
        expect(users).not_to include(registered)
      end

      it "filters by admin status" do
        admin = create(:user, :admin)
        regular = create(:user)

        get admin_users_path, params: { admin_status: "admin" }

        users = assigns(:users)
        expect(users).to include(admin)
        expect(users).not_to include(regular)
      end

      it "filters by date range" do
        old_user = create(:user, created_at: 10.days.ago)
        new_user = create(:user, created_at: 1.day.ago)

        get admin_users_path, params: {
          date_from: 5.days.ago.to_date.to_s,
          date_to: Time.current.to_date.to_s
        }

        users = assigns(:users)
        expect(users).to include(new_user)
        expect(users).not_to include(old_user)
      end
    end

    context "as a regular user" do
      before do
        login_as(regular_user, scope: :user)
      end

      it "denies access" do
        get admin_users_path

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        get admin_users_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end

  describe "GET /admin/users/:id" do
    let(:target_user) { create(:user) }
    let(:category) { create(:category) }
    let(:form_def) { create(:form_definition, code: "SC-100", category: category) }

    context "as an admin user" do
      before do
        login_as(admin_user, scope: :user)
      end

      it "returns http success" do
        get admin_user_path(target_user)

        expect(response).to have_http_status(:success)
      end

      it "displays user details" do
        get admin_user_path(target_user)

        expect(assigns(:user)).to eq(target_user)
      end

      it "displays submission and feedback counts" do
        create_list(:submission, 3, user: target_user, form_definition: form_def)
        create_list(:form_feedback, 2, user: target_user, form_definition: form_def)

        get admin_user_path(target_user)

        expect(assigns(:submissions_count)).to eq(3)
        expect(assigns(:feedbacks_count)).to eq(2)
      end

      it "displays recent submissions" do
        submissions = create_list(:submission, 7, user: target_user, form_definition: form_def)

        get admin_user_path(target_user)

        expect(assigns(:recent_submissions).count).to eq(5) # Limited to 5
      end
    end

    context "as a regular user" do
      before do
        login_as(regular_user, scope: :user)
      end

      it "denies access" do
        get admin_user_path(target_user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "GET /admin/users/:id/activity" do
    let(:target_user) { create(:user) }
    let(:category) { create(:category) }
    let(:form_def) { create(:form_definition, code: "SC-100", category: category) }

    context "as an admin user" do
      before do
        login_as(admin_user, scope: :user)
      end

      it "returns http success" do
        get activity_admin_user_path(target_user)

        expect(response).to have_http_status(:success)
      end

      it "displays activity timeline" do
        create(:submission, user: target_user, form_definition: form_def)
        create(:form_feedback, user: target_user, form_definition: form_def)

        get activity_admin_user_path(target_user)

        expect(assigns(:activities)).to be_present
        expect(assigns(:total_activities)).to be >= 2 # submission + account_created
      end

      it "supports pagination" do
        get activity_admin_user_path(target_user), params: { page: 1 }

        expect(assigns(:current_page)).to eq(1)
        expect(assigns(:total_pages)).to be >= 1
      end

      it "returns JSON when requested" do
        create(:submission, user: target_user, form_definition: form_def)

        get activity_admin_user_path(target_user), headers: { "Accept" => "application/json" }

        expect(response).to have_http_status(:success)
        json = JSON.parse(response.body)
        expect(json["activities"]).to be_an(Array)
        expect(json["pagination"]).to be_present
      end
    end

    context "as a regular user" do
      before do
        login_as(regular_user, scope: :user)
      end

      it "denies access" do
        get activity_admin_user_path(target_user)

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
