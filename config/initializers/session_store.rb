# frozen_string_literal: true

# Session Cookie Security Configuration
# Configures secure session cookies for production-ready security.
#
# Security features:
# - SameSite: :lax - Prevents CSRF by restricting cross-site cookie sending
#   (use :strict for higher security, but may break some OAuth flows)
# - secure: true (production) - Cookies only sent over HTTPS
# - httponly: true - Prevents JavaScript access (XSS protection)
#
# See: https://owasp.org/www-community/controls/SecureCookieAttribute
# See: https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Set-Cookie/SameSite

Rails.application.config.session_store :cookie_store,
  key: "_ca_small_claims_session",
  same_site: :lax,
  secure: Rails.env.production?,
  httponly: true,
  expire_after: 24.hours
