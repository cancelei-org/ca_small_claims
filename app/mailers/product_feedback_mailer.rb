# frozen_string_literal: true

class ProductFeedbackMailer < ApplicationMailer
  def admin_notification(product_feedback)
    @product_feedback = product_feedback
    @user = product_feedback.user

    mail(
      to: admin_email,
      subject: "[Product Feedback] New #{product_feedback.category_display_name}: #{product_feedback.title.truncate(50)}"
    )
  end

  def status_changed(product_feedback, old_status)
    @product_feedback = product_feedback
    @user = product_feedback.user
    @old_status = old_status

    return unless @user.can_receive_emails?

    mail(
      to: @user.email,
      subject: "Your feedback status has been updated to: #{product_feedback.status_display_name}"
    )
  end

  private

  def admin_email
    ENV.fetch("ADMIN_EMAIL", "admin@casmallclaims.example.com")
  end
end
