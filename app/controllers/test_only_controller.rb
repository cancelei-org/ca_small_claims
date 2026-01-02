# frozen_string_literal: true

# Test-only controller for E2E test setup
# Only available in development and test environments
class TestOnlyController < ApplicationController
  before_action :ensure_test_environment
  before_action :authenticate_user!, except: [ :reset ]

  # POST /test_only/create_submission
  # Creates a submission for the current user
  def create_submission
    form_type = params[:form_type] || "SC-100"
    form_definition = FormDefinition.find_by(code: form_type)

    return redirect_to root_path, alert: "Form type not found: #{form_type}" unless form_definition

    submission = current_user.submissions.create!(
      form_definition: form_definition,
      form_data: { "test_field" => "test_value" },
      status: "draft"
    )

    redirect_to submission_path(submission)
  end

  # GET /test_only/create_session_submission
  # Creates a submission for testing cross-user access
  # Returns the submission's direct URL which should be protected
  def create_session_submission
    form_type = params[:form_type] || "SC-100"
    form_definition = FormDefinition.find_by(code: form_type)

    return redirect_to root_path, alert: "Form type not found: #{form_type}" unless form_definition

    # Create a submission tied to the current user
    submission = current_user.submissions.create!(
      form_definition: form_definition,
      form_data: { "test_field" => "test_value_from_user_a" },
      status: "draft"
    )

    # Redirect to submission show page (should be protected)
    redirect_to submission_path(submission)
  end

  # POST /test_only/reset
  # Resets test data (clears submissions for test users)
  def reset
    if Rails.env.test? || Rails.env.development?
      test_emails = %w[user_a@example.com user_b@example.com regular_user@example.com]
      User.where(email: test_emails).find_each do |user|
        user.submissions.destroy_all
      end
      SessionSubmission.where("created_at > ?", 1.hour.ago).destroy_all

      render json: { status: "ok", message: "Test data reset" }
    else
      render json: { status: "error", message: "Not allowed" }, status: :forbidden
    end
  end

  private

  def ensure_test_environment
    redirect_to root_path, alert: "Not available in production" unless Rails.env.test? || Rails.env.development?
  end
end
