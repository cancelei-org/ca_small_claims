# frozen_string_literal: true

class NotificationEmailJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff for transient failures
  retry_on Net::SMTPError, wait: :polynomially_longer, attempts: 5
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
  retry_on Errno::ECONNREFUSED, wait: 1.minute, attempts: 3

  # Discard jobs if user or record no longer exists
  discard_on ActiveRecord::RecordNotFound

  # Send form submission confirmation email
  # @param user_id [Integer] The user ID
  # @param submission_id [Integer] The submission ID
  def perform(notification_type, **args)
    case notification_type.to_sym
    when :form_submission_confirmation
      send_form_submission_confirmation(args[:user_id], args[:submission_id])
    when :form_download_ready
      send_form_download_ready(args[:user_id], args[:form_definition_id])
    when :deadline_reminder
      send_deadline_reminder(args[:user_id], args[:submission_id], args[:deadline_date])
    when :fee_waiver_status_update
      send_fee_waiver_status_update(args[:user_id], args[:submission_id], args[:status])
    else
      Rails.logger.warn("Unknown notification type: #{notification_type}")
    end
  end

  private

  def send_form_submission_confirmation(user_id, submission_id)
    user = User.find(user_id)
    submission = Submission.find(submission_id)

    NotificationMailer.form_submission_confirmation(user, submission).deliver_now
  end

  def send_form_download_ready(user_id, form_definition_id)
    user = User.find(user_id)
    form_definition = FormDefinition.find(form_definition_id)

    NotificationMailer.form_download_ready(user, form_definition).deliver_now
  end

  def send_deadline_reminder(user_id, submission_id, deadline_date)
    user = User.find(user_id)
    submission = Submission.find(submission_id)
    parsed_date = deadline_date.is_a?(String) ? Date.parse(deadline_date) : deadline_date

    NotificationMailer.deadline_reminder(user, submission, parsed_date).deliver_now
  end

  def send_fee_waiver_status_update(user_id, submission_id, status)
    user = User.find(user_id)
    submission = Submission.find(submission_id)

    NotificationMailer.fee_waiver_status_update(user, submission, status).deliver_now
  end
end
