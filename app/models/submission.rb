# frozen_string_literal: true

class Submission < ApplicationRecord
  include FormDataAccessor

  belongs_to :user, optional: true
  belongs_to :form_definition
  belongs_to :workflow, optional: true

  validates :status, inclusion: { in: %w[draft completed submitted] }

  scope :drafts, -> { where(status: "draft") }
  scope :completed, -> { where(status: "completed") }
  scope :submitted, -> { where(status: "submitted") }
  scope :for_session, ->(sid) { where(session_id: sid) }
  scope :in_workflow, ->(wid) { where(workflow_session_id: wid) }
  scope :recent, -> { order(updated_at: :desc) }

  before_create :set_defaults

  def anonymous?
    user_id.nil?
  end

  def complete!
    update!(status: "completed", completed_at: Time.current)
  end

  def submit!
    update!(status: "submitted")
  end

  def draft?
    status == "draft"
  end

  def completed?
    status == "completed"
  end

  def generate_pdf
    Pdf::FormFiller.new(self).generate
  end

  def generate_flattened_pdf
    Pdf::FormFiller.new(self).generate_flattened
  end

  # Cache key for PDF generation - changes when form data changes
  def pdf_cache_key
    data_hash = Digest::MD5.hexdigest(form_data.to_json)
    "pdf_cache/#{id}/#{data_hash}"
  end

  # Check if cached PDF is still valid
  def pdf_cache_valid?
    return false unless pdf_generated_at.present?

    # Cache valid if generated after last update and within TTL
    pdf_generated_at > updated_at && pdf_generated_at > 10.seconds.ago
  end

  # Mark PDF as generated (for cache tracking)
  def mark_pdf_generated!
    update_column(:pdf_generated_at, Time.current)
  end

  def shared_data
    form_definition.field_definitions
      .where.not(shared_field_key: nil)
      .each_with_object({}) do |field, hash|
        value = field_value(field.name)
        hash[field.shared_field_key] = value if value.present?
      end
  end

  def completion_percentage
    return 0 if form_definition.required_fields.empty?

    filled = form_definition.required_fields.count do |field|
      field_value(field.name).present?
    end

    (filled.to_f / form_definition.required_fields.count * 100).round
  end

  private

  def set_defaults
    self.workflow_session_id ||= SecureRandom.uuid if workflow_id.present?
  end
end
