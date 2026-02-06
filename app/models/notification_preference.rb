# frozen_string_literal: true

class NotificationPreference < ApplicationRecord
  belongs_to :user

  # Notification types available for email
  NOTIFICATION_TYPES = %w[
    email_form_submission
    email_form_download
    email_deadline_reminders
    email_fee_waiver_status
    email_marketing
  ].freeze

  # Transactional notifications (always enabled by default, can be disabled)
  TRANSACTIONAL_NOTIFICATIONS = %w[
    email_form_submission
    email_form_download
    email_deadline_reminders
    email_fee_waiver_status
  ].freeze

  # Check if a specific notification type is enabled
  # @param notification_type [String, Symbol] The type of notification to check
  # @return [Boolean] true if enabled, false otherwise
  def enabled?(notification_type)
    type = notification_type.to_s
    return false unless NOTIFICATION_TYPES.include?(type)

    send(type)
  end

  # Enable all transactional notifications
  def enable_all_transactional!
    update!(
      TRANSACTIONAL_NOTIFICATIONS.index_with { true }
    )
  end

  # Disable all notifications (useful for unsubscribe all)
  def disable_all!
    update!(
      NOTIFICATION_TYPES.index_with { false }
    )
  end

  # Returns a hash of all notification settings
  def to_settings_hash
    NOTIFICATION_TYPES.index_with { |type| send(type) }
  end
end
