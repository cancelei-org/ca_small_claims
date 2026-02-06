# frozen_string_literal: true

# Security Headers Configuration
# Adds additional security headers beyond what Rails provides by default.
# See: https://owasp.org/www-project-secure-headers/

Rails.application.configure do
  # Set X-Frame-Options to prevent clickjacking
  # This is set by Rails automatically when force_ssl is enabled, but we ensure it here
  config.action_dispatch.default_headers.merge!(
    # Prevent MIME type sniffing
    "X-Content-Type-Options" => "nosniff",

    # Enable XSS filter in older browsers (modern browsers have built-in protection)
    "X-XSS-Protection" => "0",

    # Prevent site from being embedded in iframes (clickjacking protection)
    # Note: X-Frame-Options is also set by CSP frame-ancestors, but this provides
    # backwards compatibility with older browsers
    "X-Frame-Options" => "SAMEORIGIN",

    # Control referrer information sent with requests
    "Referrer-Policy" => "strict-origin-when-cross-origin",

    # Restrict browser features/APIs that can be used
    "Permissions-Policy" => "accelerometer=(), camera=(), geolocation=(), gyroscope=(), magnetometer=(), microphone=(), payment=(), usb=()"
  )
end

# Additional HSTS configuration is handled by Rails when force_ssl is enabled
# Default: Strict-Transport-Security: max-age=63072000; includeSubDomains
