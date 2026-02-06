# frozen_string_literal: true

class WebhookDeliveryJob < ApplicationJob
  queue_as :default

  def perform(endpoint, event, payload, signature = nil)
    body = payload.to_json
    headers = {
      "Content-Type" => "application/json",
      "User-Agent" => "ca-small-claims-webhook",
      "X-Webhook-Event" => event
    }
    headers["X-Webhook-Signature"] = signature if signature

    HTTParty.post(endpoint, body: body, headers: headers, timeout: 5)
  rescue StandardError => e
    Rails.logger.error("Webhook delivery failed: #{e.message}")
  end
end
