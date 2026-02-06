# frozen_string_literal: true

class Workflow < ApplicationRecord
  belongs_to :category, optional: true

  has_many :workflow_steps, -> { order(:position) }, dependent: :destroy
  has_many :form_definitions, through: :workflow_steps
  has_many :submissions, dependent: :nullify

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :by_category, ->(cat) { joins(:category).where(categories: { slug: cat }) }
  scope :by_category_id, ->(id) { where(category_id: id) }
  scope :ordered, -> { order(:position, :name) }

  def first_step
    workflow_steps.order(:position).first
  end

  def step_at(position)
    workflow_steps.find_by(position: position)
  end

  def next_step(current_position)
    workflow_steps.where("position > ?", current_position).order(:position).first
  end

  def previous_step(current_position)
    workflow_steps.where("position < ?", current_position).order(:position).last
  end

  def total_steps
    workflow_steps.count
  end

  def required_steps
    workflow_steps.where(required: true)
  end

  def to_param
    slug
  end
end
