# frozen_string_literal: true

class AlertLog < ApplicationRecord
  validates :event, :severity, presence: true

  scope :recent, -> { order(created_at: :desc) }
end
