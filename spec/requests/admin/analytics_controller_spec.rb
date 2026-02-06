# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Analytics", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:form_def) { create(:form_definition, code: "SC-100", active: true) }
  let(:form_def2) { create(:form_definition, code: "SC-105", active: true) }

  before do
    sign_in admin
  end

  describe "GET /admin/analytics" do
    it "returns http success" do
      create_list(:submission, 5, :completed, form_definition: form_def)
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

    it "accepts period parameter" do
      get admin_analytics_path, params: { period: "7d" }
      expect(response).to have_http_status(:success)
    end

    it "accepts custom date range" do
      get admin_analytics_path, params: {
        start_date: 7.days.ago.to_date.to_s,
        end_date: Date.current.to_s
      }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/analytics/export" do
    before do
      create_list(:submission, 3, :completed, form_definition: form_def)
    end

    it "redirects with alert for unsupported format" do
      get export_admin_analytics_path, params: { format: :xlsx }
      expect(response).to redirect_to(admin_analytics_path)
      expect(flash[:alert]).to include("Unsupported export format")
    end

    it "handles export errors gracefully" do
      allow(Reports::Exporter).to receive(:csv).and_raise(NotImplementedError, "Export not available")
      get export_admin_analytics_path, params: { format: :csv }
      expect(response).to redirect_to(admin_analytics_path)
    end
  end

  describe "GET /admin/analytics/funnel" do
    before do
      # Create submissions at various stages
      create_list(:submission, 5, form_definition: form_def, form_data: {})
      create_list(:submission, 3, form_definition: form_def, form_data: { "name" => "Test" })
      create_list(:submission, 2, :completed, form_definition: form_def)
    end

    it "returns http success" do
      get funnel_admin_analytics_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Funnel")
    end

    it "accepts form_id filter" do
      get funnel_admin_analytics_path, params: { form_id: form_def.id }
      expect(response).to have_http_status(:success)
    end

    it "accepts user_type filter" do
      get funnel_admin_analytics_path, params: { user_type: "registered" }
      expect(response).to have_http_status(:success)
    end

    it "accepts period parameter" do
      get funnel_admin_analytics_path, params: { period: "7d" }
      expect(response).to have_http_status(:success)
    end

    it "shows user type comparison when no type selected" do
      get funnel_admin_analytics_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/analytics/time_metrics" do
    before do
      # Create completed submissions with various completion times
      create(:submission, :completed, form_definition: form_def,
        created_at: 3.days.ago, completed_at: 3.days.ago + 15.minutes)
      create(:submission, :completed, form_definition: form_def,
        created_at: 3.days.ago, completed_at: 3.days.ago + 30.minutes)
    end

    it "returns http success" do
      get time_metrics_admin_analytics_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Time")
    end

    it "accepts form_id filter" do
      get time_metrics_admin_analytics_path, params: { form_id: form_def.id }
      expect(response).to have_http_status(:success)
    end

    it "accepts period parameter" do
      get time_metrics_admin_analytics_path, params: { period: "90d" }
      expect(response).to have_http_status(:success)
    end

    it "shows mode comparison for specific form" do
      workflow = create(:workflow)
      create(:submission, :completed, form_definition: form_def, workflow: workflow,
        created_at: 3.days.ago, completed_at: 3.days.ago + 10.minutes)

      get time_metrics_admin_analytics_path, params: { form_id: form_def.id }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/analytics/drop_off" do
    let!(:field1) { create(:field_definition, form_definition: form_def, name: "field1", position: 1) }
    let!(:field2) { create(:field_definition, form_definition: form_def, name: "field2", position: 2) }

    before do
      # Create abandoned submissions
      create(:submission, form_definition: form_def, status: "draft",
        form_data: { "field1" => "value" },
        created_at: 5.days.ago, updated_at: 3.days.ago)
    end

    it "returns http success" do
      get drop_off_admin_analytics_path
      expect(response).to have_http_status(:success)
    end

    it "accepts form_id filter" do
      get drop_off_admin_analytics_path, params: { form_id: form_def.id }
      expect(response).to have_http_status(:success)
    end

    it "shows field analysis for specific form" do
      get drop_off_admin_analytics_path, params: { form_id: form_def.id }
      expect(response).to have_http_status(:success)
    end

    it "accepts period parameter" do
      get drop_off_admin_analytics_path, params: { period: "7d" }
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/analytics/geographic" do
    let(:la_user) { create(:user, :with_profile, city: "Los Angeles") }

    before do
      create_list(:submission, 3, user: la_user, form_definition: form_def)
    end

    it "returns http success" do
      get geographic_admin_analytics_path
      expect(response).to have_http_status(:success)
    end

    it "accepts period parameter" do
      get geographic_admin_analytics_path, params: { period: "30d" }
      expect(response).to have_http_status(:success)
    end

    it "handles no geographic data" do
      Submission.delete_all
      get geographic_admin_analytics_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /admin/analytics/sentiment" do
    before do
      create(:form_feedback, form_definition: form_def, rating: 5, created_at: 3.days.ago)
      create(:form_feedback, form_definition: form_def, rating: 3, created_at: 3.days.ago)
      create(:form_feedback, form_definition: form_def, rating: 1, created_at: 3.days.ago)
    end

    it "returns http success" do
      get sentiment_admin_analytics_path
      expect(response).to have_http_status(:success)
    end

    it "accepts form_id filter" do
      get sentiment_admin_analytics_path, params: { form_id: form_def.id }
      expect(response).to have_http_status(:success)
    end

    it "accepts period parameter" do
      get sentiment_admin_analytics_path, params: { period: "7d" }
      expect(response).to have_http_status(:success)
    end

    it "handles no feedback data" do
      FormFeedback.delete_all
      get sentiment_admin_analytics_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "authentication" do
    before do
      logout(:user)
    end

    it "redirects unauthenticated users from index" do
      get admin_analytics_path
      expect(response).to redirect_to(new_user_session_path)
    end

    it "redirects unauthenticated users from funnel" do
      get funnel_admin_analytics_path
      expect(response).to redirect_to(new_user_session_path)
    end

    context "with non-admin user" do
      let(:regular_user) { create(:user) }

      before do
        sign_in regular_user
      end

      it "denies access to analytics" do
        get admin_analytics_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
