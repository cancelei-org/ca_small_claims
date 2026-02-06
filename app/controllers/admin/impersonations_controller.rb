# frozen_string_literal: true

module Admin
  class ImpersonationsController < BaseController
    include Pagy::Backend

    before_action :set_target_user, only: [ :create ]
    skip_before_action :authorize_admin!, only: [ :destroy ]

    # GET /admin/impersonations
    # List impersonation history
    def index
      @pagy, @impersonation_logs = pagy(
        ImpersonationLog.includes(:admin, :target_user).recent,
        limit: 25
      )

      @active_impersonations = ImpersonationLog.active.includes(:admin, :target_user)
      @total_impersonations = ImpersonationLog.count
      @active_count = @active_impersonations.count
    end

    # POST /admin/impersonations
    # Start impersonating a user
    def create
      authorize @target_user, :impersonate?, policy_class: ImpersonationPolicy

      reason = params[:reason].presence

      start_impersonation(@target_user, reason: reason)

      log_audit_event(
        "impersonation_started",
        target: @target_user,
        details: { reason: reason }
      )

      redirect_to root_path, notice: "You are now viewing the site as #{@target_user.display_name}"
    rescue Pundit::NotAuthorizedError
      redirect_to admin_users_path, alert: "You cannot impersonate this user"
    end

    # DELETE /admin/impersonations
    # Stop impersonating and return to admin account
    def destroy
      unless impersonating?
        redirect_to admin_root_path, alert: "You are not currently impersonating anyone"
        return
      end

      # Security check: verify the true_user (admin) is still valid and authorized
      admin = true_user
      unless admin&.can_impersonate?
        # Clear potentially corrupted session and redirect
        session.delete(:impersonator_id)
        session.delete(:impersonation_log_id)
        redirect_to root_path, alert: "Invalid impersonation session"
        return
      end

      impersonated = current_user

      stop_impersonation

      log_audit_event(
        "impersonation_ended",
        target: impersonated,
        details: { admin_id: admin.id }
      )

      redirect_to admin_users_path, notice: "You have stopped impersonating #{impersonated.display_name}"
    end

    private

    def set_target_user
      @target_user = User.find(params[:user_id])
    end
  end
end
