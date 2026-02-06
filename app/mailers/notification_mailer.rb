# frozen_string_literal: true

class NotificationMailer < ApplicationMailer
  default from: -> { default_from_address }

  # Email sent when a form submission is completed
  # @param user [User] The user who submitted the form
  # @param submission [Submission] The completed submission
  def form_submission_confirmation(user, submission)
    return unless user.can_receive_emails?
    return unless user.notifications_enabled?(:email_form_submission)

    @user = user
    @submission = submission
    @form_definition = submission.form_definition

    mail(
      to: @user.email,
      subject: "Your #{@form_definition.code} form has been submitted"
    )
  end

  # Email sent when a form PDF is ready for download
  # @param user [User] The user who requested the form
  # @param form_definition [FormDefinition] The form that is ready
  def form_download_ready(user, form_definition)
    return unless user.can_receive_emails?
    return unless user.notifications_enabled?(:email_form_download)

    @user = user
    @form_definition = form_definition

    mail(
      to: @user.email,
      subject: "Your #{@form_definition.code} form is ready for download"
    )
  end

  # Email sent to remind users of upcoming deadlines
  # @param user [User] The user to remind
  # @param submission [Submission] The submission with the deadline
  # @param deadline_date [Date] The deadline date
  def deadline_reminder(user, submission, deadline_date)
    return unless user.can_receive_emails?
    return unless user.notifications_enabled?(:email_deadline_reminders)

    @user = user
    @submission = submission
    @form_definition = submission.form_definition
    @deadline_date = deadline_date
    @days_until_deadline = (deadline_date - Date.current).to_i

    mail(
      to: @user.email,
      subject: deadline_subject
    )
  end

  # Email sent with the completed PDF form attached
  # @param user [User] The user requesting the form
  # @param submission [Submission, SessionSubmission] The completed submission
  def form_pdf_delivery(user, submission)
    return unless user.can_receive_emails?

    @user = user
    @submission = submission
    @form_definition = submission.form_definition

    # Generate the PDF and attach it
    pdf_path = submission.generate_flattened_pdf
    filename = "#{@form_definition.code}_#{Date.current}.pdf"

    attachments[filename] = {
      mime_type: "application/pdf",
      content: File.read(pdf_path)
    }

    mail(
      to: @user.email,
      subject: "Your #{@form_definition.code} form is attached - #{@form_definition.title}"
    )
  end

  # Email sent when fee waiver status changes
  # @param user [User] The user whose fee waiver status changed
  # @param submission [Submission] The fee waiver submission
  # @param status [String] The new status ('approved', 'denied', 'pending_review')
  def fee_waiver_status_update(user, submission, status)
    return unless user.can_receive_emails?
    return unless user.notifications_enabled?(:email_fee_waiver_status)

    @user = user
    @submission = submission
    @form_definition = submission.form_definition
    @status = status
    @status_message = fee_waiver_status_message(status)

    mail(
      to: @user.email,
      subject: "Fee Waiver Application Status: #{status.titleize}"
    )
  end

  private

  def default_from_address
    ENV.fetch("MAILER_FROM_ADDRESS", "noreply@casmallclaims.example.com")
  end

  def deadline_subject
    if @days_until_deadline <= 0
      "URGENT: Deadline passed for #{@form_definition.code}"
    elsif @days_until_deadline <= 3
      "URGENT: #{@days_until_deadline} days until deadline for #{@form_definition.code}"
    elsif @days_until_deadline <= 7
      "Reminder: #{@days_until_deadline} days until deadline for #{@form_definition.code}"
    else
      "Upcoming deadline for #{@form_definition.code} on #{@deadline_date.strftime('%B %d, %Y')}"
    end
  end

  def fee_waiver_status_message(status)
    case status.to_s
    when "approved"
      "Your fee waiver application has been approved. Court filing fees will be waived."
    when "denied"
      "Your fee waiver application was not approved. You may need to pay court filing fees."
    when "pending_review"
      "Your fee waiver application is being reviewed by the court."
    else
      "Your fee waiver application status has been updated."
    end
  end
end
