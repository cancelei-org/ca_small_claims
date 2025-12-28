# frozen_string_literal: true

class FormFeedback < ApplicationRecord
  ISSUE_TYPES = {
    "elements_misaligned" => "Elements rendered in misalignment",
    "pdf_not_filling" => "PDF not filling out correctly",
    "pdf_download_failed" => "PDF download failed",
    "fields_unclear" => "Form fields unclear",
    "missing_information" => "Missing information",
    "other" => "Other issue"
  }.freeze

  STATUSES = %w[pending acknowledged resolved].freeze

  belongs_to :form_definition
  belongs_to :user, optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :issue_types, presence: true
  validate :valid_issue_types

  scope :pending, -> { where(status: "pending") }
  scope :acknowledged, -> { where(status: "acknowledged") }
  scope :resolved, -> { where(status: "resolved") }
  scope :unresolved, -> { where.not(status: "resolved") }
  scope :low_rated, -> { where(rating: 1..2) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_form, ->(form_id) { where(form_definition_id: form_id) }
  scope :by_issue_type, ->(type) { where("? = ANY(issue_types)", type) }
  scope :created_between, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  def pending?
    status == "pending"
  end

  def acknowledged?
    status == "acknowledged"
  end

  def resolved?
    status == "resolved"
  end

  def acknowledge!
    update!(status: "acknowledged")
  end

  def resolve!(admin_user, notes: nil)
    update!(
      status: "resolved",
      resolved_by: admin_user,
      resolved_at: Time.current,
      admin_notes: notes
    )
  end

  def issue_type_labels
    issue_types.map { |type| ISSUE_TYPES[type] }.compact
  end

  def rating_label
    case rating
    when 1 then "Very Poor"
    when 2 then "Poor"
    when 3 then "Average"
    when 4 then "Good"
    when 5 then "Excellent"
    end
  end

  def submitted_by
    user&.display_name || "Anonymous (#{session_id&.first(8)}...)"
  end

  private

  def valid_issue_types
    return if issue_types.blank?

    invalid_types = issue_types - ISSUE_TYPES.keys
    if invalid_types.any?
      errors.add(:issue_types, "contains invalid types: #{invalid_types.join(', ')}")
    end
  end
end
