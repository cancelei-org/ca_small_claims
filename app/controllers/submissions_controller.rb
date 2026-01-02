# frozen_string_literal: true

class SubmissionsController < ApplicationController
  include SessionStorage
  include PdfHandling

  before_action :set_submission, only: [ :show, :destroy, :pdf, :download_pdf ]

  def index
    @submissions = if current_user
      current_user.submissions.includes(:form_definition).recent
    else
      Submission.for_session(form_session_id).includes(:form_definition).recent
    end
  end

  def show
    @form_definition = @submission.form_definition
    @field_definitions = @form_definition.field_definitions.by_position
  end

  def destroy
    form_code = @submission.form_definition.code
    @submission.destroy

    redirect_to submissions_path, notice: "Submission for #{form_code} deleted."
  end

  def pdf
    send_pdf_inline(@submission)
  end

  def download_pdf
    send_pdf_download(@submission)
  end

  private

  def set_submission
    @submission = Submission.find(params[:id])

    redirect_to submissions_path, alert: "Submission not found." unless can_access_submission?(@submission)
  end

  # Override PdfHandling concern method
  def pdf_failure_redirect_path(submission)
    submission_path(submission)
  end

  def valid_pdf_path?(path)
    return false if path.blank?

    expanded_path = File.expand_path(path)
    allowed_dirs = [
      Rails.root.join("tmp", "pdfs").to_s,
      Rails.root.join("storage").to_s
    ]

    allowed_dirs.any? { |dir| expanded_path.start_with?(dir) } && File.exist?(expanded_path)
  end
end
