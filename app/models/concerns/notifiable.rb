# frozen_string_literal: true

# Concern to handle email notification callbacks for submissions
# Automatically triggers notifications when submission status changes
module Notifiable
  extend ActiveSupport::Concern

  included do
    after_commit :send_submission_confirmation_notification, on: :update, if: :just_completed?
    after_commit :send_fee_waiver_notification, on: :update, if: :fee_waiver_status_changed?
  end

  # Send notification when form submission is completed
  def notify_submission_completed!
    return unless user.present? && user.can_receive_emails?

    NotificationEmailJob.perform_later(
      :form_submission_confirmation,
      user_id: user.id,
      submission_id: id
    )
  end

  # Send notification when form download is ready
  def notify_download_ready!
    return unless user.present? && user.can_receive_emails?

    NotificationEmailJob.perform_later(
      :form_download_ready,
      user_id: user.id,
      form_definition_id: form_definition_id
    )
  end

  # Send deadline reminder notification
  # @param deadline_date [Date] The deadline date to remind about
  def notify_deadline_reminder!(deadline_date)
    return unless user.present? && user.can_receive_emails?

    NotificationEmailJob.perform_later(
      :deadline_reminder,
      user_id: user.id,
      submission_id: id,
      deadline_date: deadline_date.to_s
    )
  end

  # Send fee waiver status notification
  # @param status [String] The new fee waiver status
  def notify_fee_waiver_status!(status)
    return unless user.present? && user.can_receive_emails?

    NotificationEmailJob.perform_later(
      :fee_waiver_status_update,
      user_id: user.id,
      submission_id: id,
      status: status
    )
  end

  private

  # Check if submission was just completed (status changed to 'completed')
  def just_completed?
    saved_change_to_status? && status == "completed" && user.present?
  end

  # Check if this is a fee waiver form and status changed
  # Fee waiver forms are typically FW-001, FW-002, FW-003
  def fee_waiver_status_changed?
    return false unless form_definition.code.to_s.start_with?("FW-")
    return false unless saved_change_to_status?
    return false unless user.present?

    true
  end

  def send_submission_confirmation_notification
    notify_submission_completed!
  end

  def send_fee_waiver_notification
    notify_fee_waiver_status!(status)
  end
end
