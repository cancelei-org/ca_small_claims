# frozen_string_literal: true

require "rails_helper"

RSpec.describe Webhooks::Dispatcher do
  describe "#deliver" do
    let(:endpoint) { "https://example.com/webhook" }
    let(:event) { "form.submitted" }
    let(:payload) { { form_id: 1, user_id: 2 } }

    context "with configured endpoints" do
      subject(:dispatcher) { described_class.new(endpoints: [ endpoint ], secret: "test_secret") }

      it "enqueues a WebhookDeliveryJob for each endpoint" do
        expect {
          dispatcher.deliver(event: event, payload: payload)
        }.to have_enqueued_job(WebhookDeliveryJob).with(
          endpoint,
          event,
          payload,
          kind_of(String)
        )
      end

      it "generates a valid HMAC signature" do
        allow(WebhookDeliveryJob).to receive(:perform_later)

        dispatcher.deliver(event: event, payload: payload)

        expect(WebhookDeliveryJob).to have_received(:perform_later).with(
          endpoint,
          event,
          payload,
          match(/^sha256=[a-f0-9]{64}$/)
        )
      end
    end

    context "with multiple endpoints" do
      let(:endpoints) { [ "https://example.com/webhook1", "https://example.com/webhook2" ] }

      subject(:dispatcher) { described_class.new(endpoints: endpoints, secret: "test_secret") }

      it "enqueues a job for each endpoint" do
        expect {
          dispatcher.deliver(event: event, payload: payload)
        }.to have_enqueued_job(WebhookDeliveryJob).exactly(2).times
      end
    end

    context "with no endpoints" do
      subject(:dispatcher) { described_class.new(endpoints: [], secret: "test_secret") }

      it "does not enqueue any jobs" do
        expect {
          dispatcher.deliver(event: event, payload: payload)
        }.not_to have_enqueued_job(WebhookDeliveryJob)
      end
    end

    context "without a secret" do
      subject(:dispatcher) { described_class.new(endpoints: [ endpoint ], secret: nil) }

      it "passes nil as signature" do
        allow(WebhookDeliveryJob).to receive(:perform_later)

        dispatcher.deliver(event: event, payload: payload)

        expect(WebhookDeliveryJob).to have_received(:perform_later).with(
          endpoint,
          event,
          payload,
          nil
        )
      end
    end
  end

  describe "#signature" do
    it "generates consistent signatures for the same payload" do
      dispatcher = described_class.new(endpoints: [], secret: "test_secret")
      payload = { data: "test" }

      # Access private method for testing
      signature1 = dispatcher.send(:signature, payload)
      signature2 = dispatcher.send(:signature, payload)

      expect(signature1).to eq(signature2)
    end

    it "generates different signatures for different payloads" do
      dispatcher = described_class.new(endpoints: [], secret: "test_secret")

      signature1 = dispatcher.send(:signature, { data: "test1" })
      signature2 = dispatcher.send(:signature, { data: "test2" })

      expect(signature1).not_to eq(signature2)
    end

    it "generates different signatures for different secrets" do
      dispatcher1 = described_class.new(endpoints: [], secret: "secret1")
      dispatcher2 = described_class.new(endpoints: [], secret: "secret2")
      payload = { data: "test" }

      signature1 = dispatcher1.send(:signature, payload)
      signature2 = dispatcher2.send(:signature, payload)

      expect(signature1).not_to eq(signature2)
    end
  end

  describe "default configuration" do
    around do |example|
      original_endpoints = ENV["WEBHOOK_ENDPOINTS"]
      original_secret = ENV["WEBHOOK_SECRET"]
      example.run
    ensure
      ENV["WEBHOOK_ENDPOINTS"] = original_endpoints
      ENV["WEBHOOK_SECRET"] = original_secret
    end

    it "reads endpoints from environment variable" do
      ENV["WEBHOOK_ENDPOINTS"] = "https://a.com, https://b.com"
      ENV["WEBHOOK_SECRET"] = "env_secret"

      dispatcher = described_class.new

      expect {
        dispatcher.deliver(event: "test", payload: {})
      }.to have_enqueued_job(WebhookDeliveryJob).exactly(2).times
    end

    it "handles empty WEBHOOK_ENDPOINTS" do
      ENV["WEBHOOK_ENDPOINTS"] = ""

      dispatcher = described_class.new

      expect {
        dispatcher.deliver(event: "test", payload: {})
      }.not_to have_enqueued_job(WebhookDeliveryJob)
    end
  end
end
