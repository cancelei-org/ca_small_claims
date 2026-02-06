# frozen_string_literal: true

# Configure HTTPS preference for Cloudflare Tunnel access
# This initializer sets up URL generation to prefer HTTPS when accessed via tunnel,
# while maintaining HTTP fallback for local development.
#
# Environment variables:
#   TUNNEL_HOST - The tunnel hostname (default: dev-ca-small-claims.flukebase.me)
#   USE_TUNNEL  - Set to "true" to prefer HTTPS URLs in development
#
# The tunnel (cloudflared) handles SSL termination, so we don't need force_ssl.
# Rails will detect the original protocol via X-Forwarded-Proto header.

Rails.application.config.after_initialize do
  # Trust the X-Forwarded-Proto header from cloudflared
  Rails.application.config.action_dispatch.trusted_proxies = ActionDispatch::RemoteIp::TRUSTED_PROXIES

  # Configure Action Cable to work with both HTTP and HTTPS
  if Rails.env.development?
    # Allow connections from tunnel domains
    Rails.application.config.action_cable.allowed_request_origins = [
      "http://localhost:3001",
      "https://localhost:3001",
      "http://127.0.0.1:3001",
      "https://127.0.0.1:3001",
      %r{https?://.*\.flukebase\.me},
      %r{https?://.*\.trycloudflare\.com}
    ]
  end
end

# Middleware to set protocol based on X-Forwarded-Proto header
# This ensures url_for and other helpers generate correct HTTPS URLs when accessed via tunnel
class TunnelHttpsMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Check if request is coming through tunnel (has X-Forwarded-Proto)
    if env["HTTP_X_FORWARDED_PROTO"] == "https"
      env["rack.url_scheme"] = "https"
      env["HTTPS"] = "on"
    end

    @app.call(env)
  end
end

# Insert middleware after RemoteIp (which processes X-Forwarded headers)
# This ensures protocol is set correctly before cookies/session are loaded,
# preventing CSRF token validation failures due to protocol mismatch
Rails.application.config.middleware.insert_after ActionDispatch::RemoteIp, TunnelHttpsMiddleware if Rails.env.development?
