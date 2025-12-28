# frozen_string_literal: true

class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_many :submissions, dependent: :destroy
  has_many :form_feedbacks, dependent: :nullify
  has_many :resolved_feedbacks, class_name: "FormFeedback", foreign_key: "resolved_by_id", dependent: :nullify, inverse_of: :resolved_by

  scope :guests, -> { where(guest: true) }
  scope :registered, -> { where(guest: false) }

  before_create :set_guest_token, if: :guest?

  def display_name
    full_name.presence || email.split("@").first
  end

  def admin?
    admin == true
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

  private

  def set_guest_token
    self.guest_token ||= SecureRandom.urlsafe_base64(32)
  end
end
