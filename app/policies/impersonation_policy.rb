# frozen_string_literal: true

class ImpersonationPolicy < ApplicationPolicy
  # Policy for user impersonation by admins
  # record is the User being impersonated (target_user)

  def impersonate?
    can_impersonate? && target_can_be_impersonated?
  end

  def stop_impersonating?
    # Only users with impersonation privileges can stop
    # This prevents session tampering attacks
    user.present? && user.can_impersonate?
  end

  def index?
    admin?
  end

  private

  def can_impersonate?
    return false unless user.present?

    user.can_impersonate?
  end

  def target_can_be_impersonated?
    return false unless record.present?

    # Cannot impersonate self
    return false if record.id == user.id

    # Cannot impersonate admins or super_admins
    record.can_be_impersonated?
  end
end
