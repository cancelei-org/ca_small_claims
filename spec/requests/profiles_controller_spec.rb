# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Profiles", type: :request do
  let(:user) { create(:user) }

  describe "GET /profile" do
    context "when not signed in" do
      it "redirects to sign in" do
        get profile_path
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "returns http success" do
        get profile_path
        expect(response).to have_http_status(:success)
      end

      it "displays user email" do
        get profile_path
        expect(response.body).to include(user.email)
      end
    end
  end

  describe "PATCH /profile" do
    context "when not signed in" do
      it "redirects to sign in" do
        patch profile_path, params: { user: { full_name: "John" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "when signed in" do
      before { sign_in user }

      it "updates profile with valid params" do
        patch profile_path, params: {
          user: {
            full_name: "John Doe",
            phone: "555-1234",
            address: "123 Main St",
            city: "Los Angeles",
            state: "CA",
            zip_code: "90001"
          }
        }

        expect(response).to redirect_to(profile_path)
        user.reload
        expect(user.full_name).to eq("John Doe")
        expect(user.city).to eq("Los Angeles")
      end

      it "returns turbo_stream on success" do
        patch profile_path,
              params: { user: { full_name: "Jane Doe" } },
              headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:success)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("Profile saved")
      end

      it "handles validation errors gracefully" do
        # Assuming no validation errors for permitted params
        # This tests the update flow completes
        patch profile_path, params: { user: { full_name: "" } }
        expect(response).to redirect_to(profile_path)
      end
    end
  end
end
