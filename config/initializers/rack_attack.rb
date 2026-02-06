# frozen_string_literal: true

if Rails.env.production?
  class Rack::Attack
    throttle("req/ip", limit: 100, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/")
    end

    throttle("logins/ip", limit: 20, period: 1.minute) do |req|
      req.ip if req.path == "/users/sign_in" && req.post?
    end

    throttle("api/ip", limit: 60, period: 1.minute) do |req|
      req.ip if req.path.start_with?("/api/")
    end

    self.throttled_responder = lambda do |request|
      match_data = request.env["rack.attack.match_data"] || {}
      retry_after = match_data[:period]
      [
        429,
        { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
        [ { error: "rate_limited", message: "Too many requests. Please retry later." }.to_json ]
      ]
    end
  end

  Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new
end
