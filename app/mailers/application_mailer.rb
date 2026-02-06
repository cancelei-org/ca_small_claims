# frozen_string_literal: true

class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM_ADDRESS", "noreply@casmallclaims.example.com") }
  layout "mailer"

  # Helper method for generating URLs in mailers
  helper_method :app_host

  private

  def app_host
    ENV.fetch("APP_HOST", "localhost:3000")
  end
end
