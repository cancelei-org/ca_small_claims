# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Dashboard", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  describe "GET /admin" do
    context "as an admin user" do
      before do
        login_as(admin_user, scope: :user)
      end

      it "returns http success" do
        get admin_root_path

        expect(response).to have_http_status(:success)
      end

      it "displays feedback statistics" do
        category = create(:category)
        form_def = create(:form_definition, category: category)
        create_list(:form_feedback, 3, :pending, form_definition: form_def)
        create_list(:form_feedback, 2, :acknowledged, form_definition: form_def)
        create(:form_feedback, :resolved, form_definition: form_def, resolved_at: Time.current)

        get admin_root_path

        expect(response.body).to include("6") # total feedbacks
        expect(response.body).to include("3") # pending
        expect(response.body).to include("2") # acknowledged
      end

      it "displays forms needing attention" do
        category = create(:category)
        form1 = create(:form_definition, code: "SC-100", category: category)
        form2 = create(:form_definition, code: "SC-105", category: category)

        create_list(:form_feedback, 5, :pending, form_definition: form1)
        create_list(:form_feedback, 2, :pending, form_definition: form2)

        get admin_root_path

        expect(response.body).to include("SC-100")
        expect(response.body).to include("SC-105")
      end

      it "displays recent feedbacks" do
        category = create(:category)
        form_def = create(:form_definition, code: "SC-100", category: category)
        feedback = create(:form_feedback, form_definition: form_def, user: regular_user, comment: "Test feedback")

        get admin_root_path

        expect(response.body).to include("Test feedback")
      end

      it "calculates average rating" do
        category = create(:category)
        form_def = create(:form_definition, category: category)
        create(:form_feedback, form_definition: form_def, rating: 5)
        create(:form_feedback, form_definition: form_def, rating: 3)

        get admin_root_path

        expect(assigns(:stats)[:average_rating]).to eq(4.0)
      end
    end

    context "as a regular user" do
      before do
        login_as(regular_user, scope: :user)
      end

      it "denies access" do
        get admin_root_path

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        get admin_root_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
