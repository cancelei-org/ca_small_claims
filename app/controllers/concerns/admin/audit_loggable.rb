# frozen_string_literal: true

module Admin
  module AuditLoggable
    extend ActiveSupport::Concern

    private

    def log_audit_event(event, target: nil, details: {})
      AuditLog.create!(
        user: current_user,
        event: event,
        target_type: target&.class&.name,
        target_id: target&.id,
        details: details,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    rescue StandardError => e
      Rails.logger.error "[AuditLog] Failed to create audit log: #{e.message}"
    end
  end
end
