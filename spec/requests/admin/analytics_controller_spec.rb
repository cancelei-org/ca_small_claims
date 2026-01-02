# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Analytics", type: :request do
  let(:admin) { create(:user, :admin) }

  before do
    login_as(admin, scope: :user)
  end

  describe "GET /admin/analytics" do
    it "returns http success" do
      create_list(:submission, 5, :completed)
      get admin_analytics_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Analytics")
      expect(response.body).to include("Completion Rate")
    end

    it "handles zero submissions" do
      Submission.delete_all
      get admin_analytics_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("0%")
    end
  end
end
