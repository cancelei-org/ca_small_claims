# frozen_string_literal: true

require "rails_helper"

RSpec.describe AlertLog, type: :model do
  describe "validations" do
    it { should validate_presence_of(:event) }
    it { should validate_presence_of(:severity) }
  end

  describe ".recent scope" do
    it "orders alerts by creation date descending" do
      old_alert = create(:alert_log, created_at: 2.days.ago)
      new_alert = create(:alert_log, created_at: 1.hour.ago)
      middle_alert = create(:alert_log, created_at: 1.day.ago)

      recent = AlertLog.recent

      expect(recent.first).to eq(new_alert)
      expect(recent.second).to eq(middle_alert)
      expect(recent.third).to eq(old_alert)
    end
  end

  describe "alert creation" do
    it "creates an alert with event and severity" do
      alert = create(:alert_log, event: "test_event", severity: "error")

      expect(alert).to be_persisted
      expect(alert.event).to eq("test_event")
      expect(alert.severity).to eq("error")
    end

    it "creates an alert with payload" do
      payload = { user_id: 123, action: "delete", resource: "submission" }
      alert = create(:alert_log, event: "resource_deleted", severity: "warning", payload: payload)

      expect(alert.payload).to eq(payload.stringify_keys)
    end

    it "creates an alert without payload" do
      alert = create(:alert_log, event: "simple_event", severity: "info")

      expect(alert.payload).to eq({})
    end
  end

  describe "severity levels" do
    it "supports error severity" do
      alert = create(:alert_log, severity: "error")
      expect(alert.severity).to eq("error")
    end

    it "supports warning severity" do
      alert = create(:alert_log, severity: "warning")
      expect(alert.severity).to eq("warning")
    end

    it "supports info severity" do
      alert = create(:alert_log, severity: "info")
      expect(alert.severity).to eq("info")
    end

    it "supports debug severity" do
      alert = create(:alert_log, severity: "debug")
      expect(alert.severity).to eq("debug")
    end
  end

  describe "timestamps" do
    it "automatically sets created_at" do
      alert = create(:alert_log)
      expect(alert.created_at).to be_present
    end

    it "automatically sets updated_at" do
      alert = create(:alert_log)
      expect(alert.updated_at).to be_present
    end
  end
end
