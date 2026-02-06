class ApplicationController < ActionController::Base
  include SessionStorage
  include Pundit::Authorization
  include Impersonation
  before_action :set_locale

  # Handle CSRF token verification failures gracefully
  rescue_from ActionController::InvalidAuthenticityToken, with: :handle_csrf_error

  # Handle Pundit authorization failures
  rescue_from Pundit::NotAuthorizedError, with: :handle_authorization_error

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  def append_info_to_payload(payload)
    super
    payload[:request_id] = request.request_id
    payload[:remote_ip] = request.remote_ip
    payload[:user_agent] = request.user_agent
    payload[:user_id] = current_user&.id
    session_id = session.id
    payload[:session_id] = session_id.respond_to?(:private_id) ? session_id.private_id : session_id
    payload[:path] = request.fullpath

    # Include impersonation info in logs
    if impersonating?
      payload[:impersonating] = true
      payload[:true_user_id] = true_user&.id
    end
  end

  def set_locale
    locale = extract_locale
    I18n.locale = locale
    session[:locale] = locale
    cookies[:locale] = { value: locale, expires: 1.year.from_now }
  end

  def extract_locale
    # Priority: params > session > cookie > default
    locale = params[:locale].presence || session[:locale].presence || cookies[:locale].presence
    locale = locale.to_sym if locale.present?

    # Validate against available locales
    if locale && I18n.available_locales.include?(locale)
      locale
    else
      I18n.default_locale
    end
  end

  def authenticate_admin!
    redirect_to root_path, alert: "Admin access required" unless current_user&.admin?
  end

  def handle_csrf_error
    Rails.logger.warn "[ApplicationController] CSRF Token verification failed. Redirecting user to refresh token."
    # Don't reset entire session - the redirect will generate a fresh CSRF token
    # Resetting session here can cause cascading CSRF failures on retry
    respond_to do |format|
      format.html do
        flash[:alert] = "Your session has expired. Please try again."
        redirect_to root_path
      end
      format.turbo_stream do
        flash[:alert] = "Your session has expired. Please try again."
        redirect_to root_path
      end
      format.json do
        render json: { error: "CSRF token invalid. Please refresh and try again." }, status: :unprocessable_entity
      end
    end
  end

  def handle_authorization_error
    Rails.logger.warn "[ApplicationController] Authorization failed for user #{current_user&.id}"
    respond_to do |format|
      format.html do
        flash.now[:alert] = "You are not authorized to perform this action."
        render plain: "403 Forbidden", status: :forbidden
      end
      format.turbo_stream { head :forbidden }
      format.json { render json: { error: "Forbidden" }, status: :forbidden }
    end
  end
end
