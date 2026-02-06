# frozen_string_literal: true

# Provides common PDF generation and delivery methods for controllers.
# Extracts duplicated PDF handling logic from FormsController and SubmissionsController.
#
# Usage:
#   class MyController < ApplicationController
#     include PdfHandling
#
#     def preview
#       send_pdf_inline(@submission)
#     end
#
#     def download
#       send_pdf_download(@submission, flattened: true)
#     end
#
#     private
#
#     def pdf_failure_redirect_path
#       my_custom_path
#     end
#   end
#
module PdfHandling
  extend ActiveSupport::Concern

  # Send PDF inline (for preview in browser)
  #
  # @param submission [Submission, SessionSubmission] the submission to generate PDF for
  # @param filename [String, nil] optional custom filename
  # @param flattened [Boolean] whether to generate flattened (non-editable) PDF
  # @return [void]
  def send_pdf_inline(submission, filename: nil, flattened: false)
    send_pdf(submission, disposition: :inline, filename: filename, flattened: flattened)
  end

  # Send PDF as attachment (for download)
  #
  # @param submission [Submission, SessionSubmission] the submission to generate PDF for
  # @param filename [String, nil] optional custom filename
  # @param flattened [Boolean] whether to generate flattened (non-editable) PDF
  # @return [void]
  def send_pdf_download(submission, filename: nil, flattened: true)
    send_pdf(submission, disposition: :attachment, filename: filename, flattened: flattened)
  end

  private

  # Core PDF generation and delivery method
  #
  # @param submission [Submission, SessionSubmission] the submission to generate PDF for
  # @param disposition [Symbol] :inline for preview, :attachment for download
  # @param filename [String, nil] optional custom filename
  # @param flattened [Boolean] whether to generate flattened PDF
  # @return [void]
  def send_pdf(submission, disposition:, filename: nil, flattened: false)
    pdf_path = flattened ? submission.generate_flattened_pdf : submission.generate_pdf
    resolved_filename = filename || generate_pdf_filename(submission, disposition)

    if async_pdf_requested?
      return enqueue_pdf_job(
        submission,
        flattened: flattened,
        filename: resolved_filename,
        disposition: disposition
      )
    end

    send_file pdf_path,
      type: "application/pdf",
      disposition: disposition,
      filename: resolved_filename
  rescue StandardError => e
    handle_pdf_error(e, submission)
  end

  # Generate a default filename for the PDF
  #
  # @param submission [Submission, SessionSubmission] the submission
  # @param disposition [Symbol] :inline or :attachment
  # @return [String] the filename
  def generate_pdf_filename(submission, disposition)
    form_code = submission.form_definition.code
    date_suffix = Date.current.to_s

    if disposition == :inline
      "#{form_code}_preview.pdf"
    else
      "#{form_code}_#{date_suffix}.pdf"
    end
  end

  # Handle PDF generation errors with logging and redirect
  #
  # @param error [StandardError] the error that occurred
  # @param submission [Submission, SessionSubmission] the submission that failed
  # @return [void]
  def handle_pdf_error(error, submission)
    log_pdf_error(error)
    redirect_to pdf_failure_redirect_path(submission),
      alert: pdf_error_message(error)
  end

  # Log PDF generation error with details
  #
  # @param error [StandardError] the error to log
  # @return [void]
  def log_pdf_error(error)
    Rails.logger.error "PDF generation failed: #{error.class} - #{error.message}"
    Rails.logger.error error.backtrace.first(5).join("\n") if error.backtrace.present?
  end

  # Generate user-facing error message
  #
  # @param error [StandardError] the error that occurred
  # @return [String] the error message
  def pdf_error_message(error)
    "PDF generation failed: #{error.message.truncate(100)}"
  end

  # Override this method in controllers to customize redirect path on failure
  #
  # @param submission [Submission, SessionSubmission] the submission that failed
  # @return [String] the path to redirect to
  def pdf_failure_redirect_path(submission)
    if submission.respond_to?(:form_definition) && submission.form_definition.present?
      # For FormsController context
      if respond_to?(:form_path)
        form_path(submission.form_definition.code)
      elsif respond_to?(:submission_path)
        submission_path(submission)
      else
        root_path
      end
    else
      root_path
    end
  end

  def async_pdf_requested?
    async_pdf_enabled? && params[:async].present?
  end

  def async_pdf_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV["PDF_ASYNC_ENABLED"])
  end

  def enqueue_pdf_job(submission, flattened:, filename:, disposition:)
    PdfGenerationJob.perform_later(submission.class.name, submission.id, flattened: flattened)
    render json: {
      status: "queued",
      submission_id: submission.id,
      filename: filename,
      disposition: disposition
    }, status: :accepted
  end
end
