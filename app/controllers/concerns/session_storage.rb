# frozen_string_literal: true

module SessionStorage
  extend ActiveSupport::Concern

  SESSION_EXPIRATION_HOURS = 72

  included do
    before_action :ensure_session_id
    helper_method :form_session_id, :storage_manager, :session_created_at,
                  :session_expires_at, :session_time_remaining, :anonymous_session?
  end

  private

  def ensure_session_id
    session[:form_session_id] ||= SecureRandom.uuid
    session[:session_created_at] ||= Time.current.iso8601
  end

  def session_created_at
    return nil unless session[:session_created_at]

    Time.zone.parse(session[:session_created_at])
  rescue ArgumentError
    nil
  end

  def session_expires_at
    return nil unless session_created_at

    session_created_at + SESSION_EXPIRATION_HOURS.hours
  end

  def session_time_remaining
    return nil unless session_expires_at

    remaining = session_expires_at - Time.current
    remaining.positive? ? remaining : 0
  end

  def anonymous_session?
    !user_signed_in? && session[:form_session_id].present?
  end

  def form_session_id
    session[:form_session_id]
  end

  def storage_manager
    @storage_manager ||= Sessions::StorageManager.new(form_session_id)
  end

  def current_user_or_session
    current_user || form_session_id
  end

  def find_or_create_submission(form_definition, workflow: nil)
    Submission.find_or_create_for(
      form_definition: form_definition,
      user: current_user,
      session_id: form_session_id,
      workflow: workflow
    )
  end

  def can_access_submission?(submission)
    return true if current_user && submission.user_id == current_user.id
    return true if submission.session_id == form_session_id

    false
  end
end
