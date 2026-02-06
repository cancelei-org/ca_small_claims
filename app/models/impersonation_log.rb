# frozen_string_literal: true

class ImpersonationLog < ApplicationRecord
  belongs_to :admin, class_name: "User"
  belongs_to :target_user, class_name: "User"

  validates :started_at, presence: true
  validates :reason, length: { maximum: 500 }

  scope :active, -> { where(ended_at: nil) }
  scope :completed, -> { where.not(ended_at: nil) }
  scope :recent, -> { order(started_at: :desc) }
  scope :by_admin, ->(admin) { where(admin: admin) }

  def active?
    ended_at.nil?
  end

  def duration
    return nil if started_at.nil?

    end_time = ended_at || Time.current
    end_time - started_at
  end

  def duration_in_words
    return "ongoing" if active?

    seconds = duration.to_i
    return "less than a minute" if seconds < 60

    minutes = seconds / 60
    return "#{minutes} minute#{'s' if minutes > 1}" if minutes < 60

    hours = minutes / 60
    remaining_minutes = minutes % 60
    "#{hours} hour#{'s' if hours > 1} #{remaining_minutes} minute#{'s' if remaining_minutes > 1}"
  end

  def end_session!
    update!(ended_at: Time.current) if active?
  end
end
