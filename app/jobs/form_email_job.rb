# frozen_string_literal: true

# Job to deliver completed PDF forms via email
# Handles both Submission and SessionSubmission types
class FormEmailJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff for transient failures
  retry_on Net::SMTPError, wait: :polynomially_longer, attempts: 5
  retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
  retry_on Errno::ECONNREFUSED, wait: 1.minute, attempts: 3

  # Discard jobs if user or submission no longer exists
  discard_on ActiveRecord::RecordNotFound

  # Send completed PDF form to user's email
  #
  # @param user_id [Integer] The user requesting the email
  # @param submission_id [Integer] The submission ID
  # @param submission_type [String] The submission class name ("Submission" or "SessionSubmission")
  def perform(user_id:, submission_id:, submission_type:)
    user = User.find(user_id)
    submission = find_submission(submission_id, submission_type)

    Rails.logger.info "Sending form PDF to #{user.email} for #{submission.form_definition.code}"

    NotificationMailer.form_pdf_delivery(user, submission).deliver_now

    Rails.logger.info "Successfully sent form PDF to #{user.email}"
  rescue StandardError => e
    Rails.logger.error "Failed to send form PDF email: #{e.message}"
    raise
  end

  private

  def find_submission(submission_id, submission_type)
    klass = submission_type.constantize
    raise ArgumentError, "Invalid submission type: #{submission_type}" unless [ Submission, SessionSubmission ].include?(klass)

    klass.find(submission_id)
  end
end
