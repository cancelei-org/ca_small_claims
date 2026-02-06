# frozen_string_literal: true

module Impersonation
  extend ActiveSupport::Concern

  included do
    helper_method :impersonating?, :true_user, :impersonated_user
  end

  # Check if currently impersonating another user
  def impersonating?
    session[:impersonator_id].present?
  end

  # Returns the real admin user (the one doing the impersonation)
  # Returns current_user if not impersonating
  def true_user
    return current_user unless impersonating?

    @true_user ||= User.find_by(id: session[:impersonator_id])
  end

  # Returns the user being impersonated
  # Returns nil if not impersonating
  def impersonated_user
    return nil unless impersonating?

    current_user
  end

  # Start impersonating a user
  # @param target_user [User] The user to impersonate
  # @param reason [String] Optional reason for impersonation
  # @return [ImpersonationLog] The created audit log
  def start_impersonation(target_user, reason: nil)
    raise Pundit::NotAuthorizedError unless ImpersonationPolicy.new(current_user, target_user).impersonate?

    # Store the real admin's ID
    session[:impersonator_id] = current_user.id
    session[:impersonation_log_id] = create_impersonation_log(target_user, reason).id

    # Sign in as the target user (Devise)
    sign_in(:user, target_user)
  end

  # Stop impersonating and return to the real admin account
  def stop_impersonation
    return unless impersonating?

    admin_user = User.find_by(id: session[:impersonator_id])
    impersonation_log = ImpersonationLog.find_by(id: session[:impersonation_log_id])

    # End the impersonation log
    impersonation_log&.end_session!

    # Clear impersonation session data
    session.delete(:impersonator_id)
    session.delete(:impersonation_log_id)

    # Sign back in as the admin
    sign_in(:user, admin_user) if admin_user
  end

  private

  def create_impersonation_log(target_user, reason)
    ImpersonationLog.create!(
      admin: current_user,
      target_user: target_user,
      started_at: Time.current,
      reason: reason,
      ip_address: request.remote_ip,
      user_agent: request.user_agent
    )
  end
end
