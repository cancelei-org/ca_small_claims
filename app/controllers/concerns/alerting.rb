# frozen_string_literal: true

module Alerting
  extend ActiveSupport::Concern

  included do
    private def record_alert(event, severity: "error", payload: {})
      AlertLog.create!(event: event, severity: severity, payload: payload)
    rescue StandardError => e
      Rails.logger.error("Failed to record alert #{event}: #{e.message}")
    end
  end
end
