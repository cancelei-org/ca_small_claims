# frozen_string_literal: true

require "rails_helper"

RSpec.describe Alerting, type: :concern do
  # Create a test controller class that includes the concern
  let(:test_controller_class) do
    Class.new(ApplicationController) do
      include Alerting

      def trigger_alert
        record_alert("test_event", severity: "error", payload: { test: true })
      end
    end
  end

  let(:controller) { test_controller_class.new }

  describe "#record_alert" do
    it "creates an AlertLog with event and severity" do
      expect {
        controller.send(:record_alert, "user_action", severity: "info")
      }.to change(AlertLog, :count).by(1)

      alert = AlertLog.last
      expect(alert.event).to eq("user_action")
      expect(alert.severity).to eq("info")
    end

    it "creates an AlertLog with payload" do
      payload = { user_id: 42, action: "create" }

      controller.send(:record_alert, "resource_created", severity: "info", payload: payload)

      alert = AlertLog.last
      expect(alert.payload).to eq(payload.stringify_keys)
    end

    it "defaults to error severity" do
      controller.send(:record_alert, "default_severity_test")

      alert = AlertLog.last
      expect(alert.severity).to eq("error")
    end

    it "handles different severity levels" do
      %w[error warning info debug].each do |severity|
        controller.send(:record_alert, "test_event", severity: severity)
        expect(AlertLog.last.severity).to eq(severity)
      end
    end

    context "when AlertLog creation fails" do
      before do
        allow(AlertLog).to receive(:create!).and_raise(StandardError.new("Database error"))
        allow(Rails.logger).to receive(:error)
      end

      it "does not raise an error" do
        expect {
          controller.send(:record_alert, "failing_event")
        }.not_to raise_error
      end

      it "logs the error to Rails logger" do
        controller.send(:record_alert, "failing_event")

        expect(Rails.logger).to have_received(:error)
          .with(/Failed to record alert failing_event/)
      end

      it "does not create an AlertLog record" do
        expect {
          controller.send(:record_alert, "failing_event")
        }.not_to change(AlertLog, :count)
      end
    end

    context "with complex payload" do
      it "handles nested payload data" do
        complex_payload = {
          user: { id: 1, email: "test@example.com" },
          metadata: { timestamp: Time.current.iso8601, source: "api" },
          errors: [ "error1", "error2" ]
        }

        controller.send(:record_alert, "complex_event", payload: complex_payload)

        alert = AlertLog.last
        expect(alert.payload["user"]["id"]).to eq(1)
        expect(alert.payload["metadata"]["source"]).to eq("api")
        expect(alert.payload["errors"]).to eq([ "error1", "error2" ])
      end
    end

    context "in different controllers" do
      it "works in API controllers" do
        api_controller = Class.new(Api::BaseController) do
          include Alerting
        end.new

        expect {
          api_controller.send(:record_alert, "api_event")
        }.to change(AlertLog, :count).by(1)
      end

      it "works in Admin controllers" do
        admin_controller = Class.new(Admin::BaseController) do
          include Alerting

          # Override authenticate_user! for testing
          def authenticate_user!; end
          def authorize_admin!; end
        end.new

        expect {
          admin_controller.send(:record_alert, "admin_event")
        }.to change(AlertLog, :count).by(1)
      end
    end
  end

  describe "method visibility" do
    it "makes record_alert a private method" do
      expect(controller.private_methods).to include(:record_alert)
    end

    it "does not expose record_alert as public" do
      expect(controller.public_methods).not_to include(:record_alert)
    end
  end
end
