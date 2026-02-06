# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Admin::Alerts", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:regular_user) { create(:user) }

  describe "GET /admin/alerts" do
    context "as an admin user" do
      before do
        login_as(admin_user, scope: :user)
      end

      it "returns http success" do
        get admin_alerts_path

        expect(response).to have_http_status(:success)
      end

      it "displays alert logs grouped by severity" do
        create(:alert_log, event: "pdf_generation_failed", severity: "error")
        create(:alert_log, event: "slow_query", severity: "warning")
        create(:alert_log, event: "info_event", severity: "info")

        get admin_alerts_path

        expect(response.body).to include("pdf_generation_failed")
        expect(response.body).to include("slow_query")
        expect(response.body).to include("info_event")
      end

      it "limits results to 200 most recent alerts" do
        create_list(:alert_log, 250, event: "test_event", severity: "info")

        get admin_alerts_path

        alerts = assigns(:alerts)
        total_count = alerts.values.flatten.count
        expect(total_count).to eq(200)
      end

      it "orders alerts by most recent first" do
        old_alert = create(:alert_log, event: "old_event", created_at: 2.days.ago)
        new_alert = create(:alert_log, event: "new_event", created_at: 1.hour.ago)

        get admin_alerts_path

        all_alerts = assigns(:alerts).values.flatten
        expect(all_alerts.first.id).to eq(new_alert.id)
      end

      it "groups alerts by severity level" do
        create(:alert_log, event: "error1", severity: "error")
        create(:alert_log, event: "error2", severity: "error")
        create(:alert_log, event: "warning1", severity: "warning")

        get admin_alerts_path

        alerts = assigns(:alerts)
        expect(alerts["error"].count).to eq(2)
        expect(alerts["warning"].count).to eq(1)
      end
    end

    context "as a regular user" do
      before do
        login_as(regular_user, scope: :user)
      end

      it "denies access" do
        get admin_alerts_path

        expect(response).to have_http_status(:forbidden)
      end
    end

    context "as a guest" do
      it "redirects to sign in" do
        get admin_alerts_path

        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
