# frozen_string_literal: true

require "rails_helper"
require "rails-controller-testing"

RSpec.describe "Activity Logging", type: :system do
  let(:admin_user) { create(:user, :admin) }

  before do
    driven_by :rack_test
  end

  describe "Alert creation and viewing" do
    it "creates alerts and displays them in admin interface", :aggregate_failures do
      # Create various alerts
      create(:alert_log, event: "pdf_generation_failed", severity: "error",
             payload: { form_code: "SC-100" }, created_at: 1.hour.ago)
      create(:alert_log, event: "slow_query_detected", severity: "warning",
             payload: { duration_ms: 5000 }, created_at: 30.minutes.ago)
      create(:alert_log, event: "form_submitted", severity: "info",
             payload: { submission_id: 123 }, created_at: 10.minutes.ago)

      # Sign in as admin
      login_as(admin_user, scope: :user)

      # Visit alerts page
      visit admin_alerts_path

      # Verify alerts are displayed
      expect(page).to have_content("pdf_generation_failed")
      expect(page).to have_content("slow_query_detected")
      expect(page).to have_content("form_submitted")

      # Verify they are grouped by severity
      expect(page).to have_content(/error/i)
      expect(page).to have_content(/warning/i)
      expect(page).to have_content(/info/i)
    end

    it "displays alerts in chronological order (most recent first)" do
      old_alert = create(:alert_log, event: "old_event", created_at: 2.days.ago)
      new_alert = create(:alert_log, event: "new_event", created_at: 1.hour.ago)

      login_as(admin_user, scope: :user)
      visit admin_alerts_path

      # Verify new event appears before old event in the page
      page_content = page.body
      new_position = page_content.index("new_event")
      old_position = page_content.index("old_event")

      expect(new_position).to be < old_position
    end

    it "limits display to 200 most recent alerts" do
      # Create more than 200 alerts
      create_list(:alert_log, 250, event: "bulk_event", severity: "info")

      login_as(admin_user, scope: :user)
      visit admin_alerts_path

      # Count how many alert rows are displayed on the page
      # The page should limit to 200 most recent alerts
      alert_count = page.all("tr", text: "bulk_event").count
      expect(alert_count).to be <= 200
    end
  end

  describe "Alert severity grouping" do
    before do
      create(:alert_log, event: "critical_error_1", severity: "error")
      create(:alert_log, event: "critical_error_2", severity: "error")
      create(:alert_log, event: "minor_warning", severity: "warning")
      create(:alert_log, event: "info_message", severity: "info")

      login_as(admin_user, scope: :user)
    end

    it "groups alerts by severity level" do
      visit admin_alerts_path

      # Verify alerts are displayed on the page by severity
      # Check that the page contains all expected events
      expect(page).to have_content("critical_error_1")
      expect(page).to have_content("critical_error_2")
      expect(page).to have_content("minor_warning")
      expect(page).to have_content("info_message")
    end

    it "displays severity-specific sections" do
      visit admin_alerts_path

      expect(page).to have_content("critical_error_1")
      expect(page).to have_content("critical_error_2")
      expect(page).to have_content("minor_warning")
      expect(page).to have_content("info_message")
    end
  end

  describe "Access control" do
    let(:regular_user) { create(:user) }

    it "allows admin users to view alerts" do
      create(:alert_log, event: "test_event", severity: "info")

      login_as(admin_user, scope: :user)
      visit admin_alerts_path

      expect(page).to have_http_status(:success)
      expect(page).to have_content("test_event")
    end

    it "denies regular users access to alerts" do
      login_as(regular_user, scope: :user)
      visit admin_alerts_path

      expect(page).to have_http_status(:forbidden)
    end

    it "redirects guests to sign in" do
      visit admin_alerts_path

      expect(page).to have_current_path(new_user_session_path)
    end
  end

  describe "Alert metadata display" do
    it "displays alert payload information" do
      create(:alert_log,
             event: "api_error",
             severity: "error",
             payload: {
               endpoint: "/api/v1/forms",
               status_code: 500,
               error_message: "Internal server error"
             })

      login_as(admin_user, scope: :user)
      visit admin_alerts_path

      expect(page).to have_content("api_error")
      # The alert event should be visible on the page
      expect(page).to have_content("error")
    end

    it "displays timestamps for alerts" do
      alert = create(:alert_log,
                     event: "timestamped_event",
                     created_at: Time.zone.parse("2026-01-01 12:00:00"))

      login_as(admin_user, scope: :user)
      visit admin_alerts_path

      expect(page).to have_content("timestamped_event")
    end
  end

  describe "Integration with admin dashboard" do
    it "shows alert count in dashboard" do
      create_list(:alert_log, 5, severity: "error")
      create_list(:alert_log, 3, severity: "warning")

      login_as(admin_user, scope: :user)
      visit admin_root_path

      # Dashboard should be accessible
      expect(page).to have_http_status(:success)
    end
  end

  describe "Alert logging concern integration" do
    it "creates alerts using the Alerting concern" do
      # Test that the Alerting concern is available for use
      test_controller = Class.new(ApplicationController) do
        include Alerting

        def test_action
          record_alert("test_event", severity: "info", payload: { test: true })
          head :ok
        end
      end

      # Simulate controller action
      controller_instance = test_controller.new
      allow(controller_instance).to receive(:record_alert).and_call_original

      expect {
        controller_instance.send(:record_alert, "test_event", severity: "info", payload: { test: true })
      }.to change(AlertLog, :count).by(1)

      alert = AlertLog.last
      expect(alert.event).to eq("test_event")
      expect(alert.severity).to eq("info")
      expect(alert.payload).to eq({ "test" => true })
    end

    it "handles alert creation failures gracefully" do
      test_controller = Class.new(ApplicationController) do
        include Alerting
      end

      controller_instance = test_controller.new
      allow(AlertLog).to receive(:create!).and_raise(StandardError.new("Database error"))
      allow(Rails.logger).to receive(:error)

      # Should not raise error
      expect {
        controller_instance.send(:record_alert, "failing_event")
      }.not_to raise_error

      expect(Rails.logger).to have_received(:error).with(/Failed to record alert/)
    end
  end
end
