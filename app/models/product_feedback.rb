# frozen_string_literal: true

class ProductFeedback < ApplicationRecord
  ALLOWED_ATTACHMENT_TYPES = %w[image/png image/jpeg image/gif image/webp].freeze
  MAX_ATTACHMENT_SIZE = 5.megabytes
  MAX_ATTACHMENTS = 5

  belongs_to :user
  has_many :votes, class_name: "ProductFeedbackVote", dependent: :destroy
  has_many :voters, through: :votes, source: :user
  has_many_attached :attachments

  # Enums - using _category and _status prefixes to avoid method conflicts
  enum :category, {
    general: 0,
    bug: 1,
    feature: 2,
    partnership: 3
  }

  enum :status, {
    pending: 0,
    under_review: 1,
    planned: 2,
    in_progress: 3,
    completed: 4,
    declined: 5
  }

  # Validations
  validates :title, presence: true, length: { maximum: 200 }
  validates :description, presence: true, length: { maximum: 5000 }
  validates :category, presence: true
  validates :status, presence: true

  # Rate limiting: 10 submissions per 24 hours per user
  validate :rate_limit_not_exceeded, on: :create
  validate :validate_attachments

  # Scopes
  scope :recent, -> { order(created_at: :desc) }
  scope :popular, -> { order(votes_count: :desc) }
  scope :by_category, ->(category) { where(category: category) }
  scope :by_status, ->(status) { where(status: status) }
  scope :open, -> { where(status: %i[pending under_review planned in_progress]) }
  scope :closed, -> { where(status: %i[completed declined]) }

  # Class methods
  def self.categories_for_select
    categories.keys.map { |c| [category_display_name(c), c] }
  end

  def self.statuses_for_select
    statuses.keys.map { |s| [status_display_name(s), s] }
  end

  def self.category_display_name(category)
    {
      "general" => "General Feedback",
      "bug" => "Bug Report",
      "feature" => "Feature Request",
      "partnership" => "Partnership Inquiry"
    }[category.to_s] || category.to_s.humanize
  end

  def self.status_display_name(status)
    {
      "pending" => "Pending Review",
      "under_review" => "Under Review",
      "planned" => "Planned",
      "in_progress" => "In Progress",
      "completed" => "Completed",
      "declined" => "Declined"
    }[status.to_s] || status.to_s.humanize
  end

  def self.category_icon(category)
    {
      "general" => "chat-bubble-left-right",
      "bug" => "bug-ant",
      "feature" => "sparkles",
      "partnership" => "users"
    }[category.to_s] || "chat-bubble-left"
  end

  def self.status_color(status)
    {
      "pending" => "badge-ghost",
      "under_review" => "badge-info",
      "planned" => "badge-primary",
      "in_progress" => "badge-warning",
      "completed" => "badge-success",
      "declined" => "badge-error"
    }[status.to_s] || "badge-ghost"
  end

  # Instance methods
  def category_display_name
    self.class.category_display_name(category)
  end

  def status_display_name
    self.class.status_display_name(status)
  end

  def category_icon
    self.class.category_icon(category)
  end

  def status_color
    self.class.status_color(status)
  end

  def voted_by?(user)
    return false if user.nil?

    votes.exists?(user: user)
  end

  def vote_by(user)
    return nil if user.nil? || voted_by?(user)

    votes.create(user: user)
  end

  def unvote_by(user)
    return nil if user.nil?

    votes.find_by(user: user)&.destroy
  end

  def open?
    pending? || under_review? || planned? || in_progress?
  end

  def closed?
    completed? || declined?
  end

  private

  def rate_limit_not_exceeded
    return unless user.present?

    recent_count = ProductFeedback.where(user: user)
                                  .where("created_at > ?", 24.hours.ago)
                                  .count

    return unless recent_count >= 10

    errors.add(:base, "You have reached the maximum number of feedback submissions (10) in 24 hours. Please try again later.")
  end

  def validate_attachments
    return unless attachments.attached?

    if attachments.count > MAX_ATTACHMENTS
      errors.add(:attachments, "cannot have more than #{MAX_ATTACHMENTS} files")
    end

    attachments.each do |attachment|
      unless ALLOWED_ATTACHMENT_TYPES.include?(attachment.content_type)
        errors.add(:attachments, "must be PNG, JPEG, GIF, or WebP images")
      end

      if attachment.byte_size > MAX_ATTACHMENT_SIZE
        errors.add(:attachments, "must be smaller than #{MAX_ATTACHMENT_SIZE / 1.megabyte}MB each")
      end
    end
  end
end
