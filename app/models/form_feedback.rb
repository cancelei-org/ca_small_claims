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

  # Extended statuses for issue tracking workflow
  STATUSES = %w[open in_progress resolved closed].freeze

  # Priority levels for issue tracking
  PRIORITIES = %w[low medium high urgent].freeze

  PRIORITY_COLORS = {
    "low" => "badge-ghost",
    "medium" => "badge-info",
    "high" => "badge-warning",
    "urgent" => "badge-error"
  }.freeze

  STATUS_COLORS = {
    "open" => "badge-warning",
    "in_progress" => "badge-info",
    "resolved" => "badge-success",
    "closed" => "badge-neutral"
  }.freeze

  belongs_to :form_definition
  belongs_to :user, optional: true
  belongs_to :resolved_by, class_name: "User", optional: true

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :priority, presence: true, inclusion: { in: PRIORITIES }
  validates :issue_types, presence: true
  validate :valid_issue_types

  # Status scopes
  scope :open, -> { where(status: "open") }
  scope :in_progress, -> { where(status: "in_progress") }
  scope :resolved, -> { where(status: "resolved") }
  scope :closed, -> { where(status: "closed") }
  scope :active, -> { where(status: %w[open in_progress]) }
  scope :completed, -> { where(status: %w[resolved closed]) }

  # Legacy scope aliases for backward compatibility
  scope :pending, -> { open }
  scope :acknowledged, -> { in_progress }
  scope :unresolved, -> { active }

  # Priority scopes
  scope :low_priority, -> { where(priority: "low") }
  scope :medium_priority, -> { where(priority: "medium") }
  scope :high_priority, -> { where(priority: "high") }
  scope :urgent_priority, -> { where(priority: "urgent") }
  scope :high_or_urgent, -> { where(priority: %w[high urgent]) }

  # General scopes
  scope :low_rated, -> { where(rating: 1..2) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_form, ->(form_id) { where(form_definition_id: form_id) }
  scope :by_issue_type, ->(type) { where("? = ANY(issue_types)", type) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :created_between, ->(start_date, end_date) { where(created_at: start_date..end_date) }

  # Order by priority (urgent first) then by creation date
  scope :by_priority_order, -> {
    order(Arel.sql("CASE priority
      WHEN 'urgent' THEN 1
      WHEN 'high' THEN 2
      WHEN 'medium' THEN 3
      WHEN 'low' THEN 4
      ELSE 5
    END, created_at DESC"))
  }

  # Get all status and priority counts in a single query
  # Returns a hash with keys: :open, :in_progress, :resolved, :closed, :urgent_active, :high_or_urgent_active
  def self.status_counts
    counts = group(:status).count
    priority_counts = active.group(:priority).count

    {
      open: counts["open"] || 0,
      in_progress: counts["in_progress"] || 0,
      resolved: counts["resolved"] || 0,
      closed: counts["closed"] || 0,
      urgent_active: priority_counts["urgent"] || 0,
      high_or_urgent_active: (priority_counts["high"] || 0) + (priority_counts["urgent"] || 0),
      total: counts.values.sum
    }
  end

  # Status check methods
  def open?
    status == "open"
  end

  def in_progress?
    status == "in_progress"
  end

  def resolved?
    status == "resolved"
  end

  def closed?
    status == "closed"
  end

  def active?
    open? || in_progress?
  end

  # Legacy method aliases for backward compatibility
  alias pending? open?
  alias acknowledged? in_progress?

  # Priority check methods
  def low_priority?
    priority == "low"
  end

  def medium_priority?
    priority == "medium"
  end

  def high_priority?
    priority == "high"
  end

  def urgent_priority?
    priority == "urgent"
  end

  def high_or_urgent?
    high_priority? || urgent_priority?
  end

  # Status transition methods
  def start_progress!(admin_user = nil)
    update!(status: "in_progress")
  end

  # Legacy alias
  def acknowledge!
    start_progress!
  end

  def resolve!(admin_user, notes: nil)
    attrs = {
      status: "resolved",
      resolved_by: admin_user,
      resolved_at: Time.current
    }
    attrs[:admin_notes] = notes if notes.present?
    update!(attrs)
  end

  def close!(admin_user, notes: nil)
    attrs = {
      status: "closed",
      resolved_by: admin_user,
      resolved_at: Time.current
    }
    attrs[:admin_notes] = notes if notes.present?
    update!(attrs)
  end

  def reopen!
    update!(
      status: "open",
      resolved_by: nil,
      resolved_at: nil
    )
  end

  # Priority management
  def escalate!
    case priority
    when "low" then update!(priority: "medium")
    when "medium" then update!(priority: "high")
    when "high" then update!(priority: "urgent")
    end
  end

  def de_escalate!
    case priority
    when "urgent" then update!(priority: "high")
    when "high" then update!(priority: "medium")
    when "medium" then update!(priority: "low")
    end
  end

  def set_priority!(new_priority)
    update!(priority: new_priority) if PRIORITIES.include?(new_priority)
  end

  # Display helpers
  def priority_badge_class
    PRIORITY_COLORS[priority] || "badge-ghost"
  end

  def status_badge_class
    STATUS_COLORS[status] || "badge-ghost"
  end

  def priority_label
    priority&.titleize
  end

  def status_label
    case status
    when "open" then "Open"
    when "in_progress" then "In Progress"
    when "resolved" then "Resolved"
    when "closed" then "Closed"
    else status&.titleize
    end
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
    errors.add(:issue_types, "contains invalid types: #{invalid_types.join(', ')}") if invalid_types.any?
  end
end
