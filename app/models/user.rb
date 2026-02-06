# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Encryption for sensitive PII
  encrypts :full_name, :address, :city, :zip_code, :phone, :date_of_birth

  # Roles
  ROLES = %w[user admin super_admin].freeze

  has_many :submissions, dependent: :destroy
  has_many :form_feedbacks, dependent: :nullify
  has_many :resolved_feedbacks, class_name: "FormFeedback", foreign_key: "resolved_by_id", dependent: :nullify, inverse_of: :resolved_by
  has_one :notification_preference, dependent: :destroy
  has_many :product_feedbacks, dependent: :destroy
  has_many :product_feedback_votes, dependent: :destroy

  # Impersonation tracking
  has_many :impersonation_logs_as_admin, class_name: "ImpersonationLog", foreign_key: "admin_id", dependent: :destroy, inverse_of: :admin
  has_many :impersonation_logs_as_target, class_name: "ImpersonationLog", foreign_key: "target_user_id", dependent: :destroy, inverse_of: :target_user

  scope :guests, -> { where(guest: true) }
  scope :registered, -> { where(guest: false) }

  before_create :set_guest_token, if: :guest?

  def display_name
    full_name.presence || email.split("@").first
  end

  def admin?
    admin == true || role.in?(%w[admin super_admin])
  end

  def super_admin?
    role == "super_admin"
  end

  # Check if this user can impersonate others
  def can_impersonate?
    admin? || super_admin?
  end

  # Check if this user can be impersonated
  def can_be_impersonated?
    !admin? && !super_admin?
  end

  def profile_for_autofill
    {
      full_name: full_name,
      address: address,
      city: city,
      state: state,
      zip_code: zip_code,
      phone: phone,
      date_of_birth: date_of_birth
    }.compact
  end

  def profile_complete?
    full_name.present? && address.present? && city.present? && zip_code.present?
  end

  def migrate_session_data!(session_id)
    SessionSubmission.for_session(session_id).find_each do |session_sub|
      submissions.find_or_create_by!(
        form_definition: session_sub.form_definition,
        status: "draft"
      ) do |submission|
        submission.form_data = session_sub.form_data
      end
    end

    SessionSubmission.for_session(session_id).delete_all
  end

  def form_submissions_for(form_definition)
    submissions.where(form_definition: form_definition)
  end

  def recent_submissions(limit = 10)
    submissions.recent.limit(limit)
  end

  # Tutorial tracking
  def tutorial_completed?(tutorial_id)
    completed_tutorials.include?(tutorial_id.to_s)
  end

  def complete_tutorial!(tutorial_id)
    self.preferences ||= {}
    self.preferences["completed_tutorials"] ||= []
    self.preferences["completed_tutorials"] << tutorial_id.to_s unless tutorial_completed?(tutorial_id)
    save!
  end

  def completed_tutorials
    (preferences || {}).fetch("completed_tutorials", [])
  end

  # Notification preferences helpers
  # Creates notification preferences with defaults if they don't exist
  def ensure_notification_preference!
    notification_preference || create_notification_preference!
  end

  # Check if user wants to receive a specific notification type
  # @param notification_type [String, Symbol] The notification type to check
  # @return [Boolean] true if notification is enabled
  def notifications_enabled?(notification_type)
    ensure_notification_preference!.enabled?(notification_type)
  end

  # Quick access to check if user can receive emails (has verified email)
  def can_receive_emails?
    email.present? && !guest?
  end

  private

  def set_guest_token
    self.guest_token ||= SecureRandom.urlsafe_base64(32)
  end
end
