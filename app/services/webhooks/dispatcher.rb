# frozen_string_literal: true

module Webhooks
  class Dispatcher
    def initialize(endpoints: configured_endpoints, secret: ENV["WEBHOOK_SECRET"])
      @endpoints = endpoints
      @secret = secret
    end

    def deliver(event:, payload:)
      return unless @endpoints.any?

      @endpoints.each do |endpoint|
        WebhookDeliveryJob.perform_later(endpoint, event, payload, signature(payload))
      end
    end

    private

    def configured_endpoints
      ENV.fetch("WEBHOOK_ENDPOINTS", "").split(",").map(&:strip).reject(&:blank?)
    end

    def signature(payload)
      return nil unless @secret

      data = payload.to_json
      "sha256=#{OpenSSL::HMAC.hexdigest("SHA256", @secret, data)}"
    end
  end
end
