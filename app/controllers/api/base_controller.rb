# frozen_string_literal: true

module Api
  class BaseController < ActionController::API
    include ActionController::HttpAuthentication::Token::ControllerMethods

    before_action :set_default_format
    before_action :authenticate_token!

    rescue_from ActiveRecord::RecordNotFound do
      render json: { error: "not_found" }, status: :not_found
    end

    private

    def set_default_format
      request.format = :json
    end

    def authenticate_token!
      return if api_token.blank?

      head :unauthorized unless secure_compare(api_token, request_token)
    end

    def request_token
      token, = token_and_options(request)
      token
    end

    def api_token
      ENV["API_TOKEN"]
    end

    def secure_compare(a, b)
      ActiveSupport::SecurityUtils.secure_compare(a, b) if a.present? && b.present?
    end

    def log_alert(event, severity: "error", payload: {})
      AlertLog.create!(event: event, severity: severity, payload: payload)
    rescue StandardError => e
      Rails.logger.error("Failed to log alert #{event}: #{e.message}")
    end
  end
end
