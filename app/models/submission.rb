# frozen_string_literal: true

class Submission < ApplicationRecord
  include FormDataAccessor
  include StatusChecker
  include Notifiable

  belongs_to :user, optional: true
  belongs_to :form_definition
  belongs_to :workflow, optional: true

  validates :status, inclusion: { in: %w[draft completed submitted] }

  # Generate status query methods: draft?, completed?, submitted?
  define_status_methods :draft, :completed, :submitted

  scope :drafts, -> { where(status: "draft") }
  scope :completed, -> { where(status: "completed") }
  scope :submitted, -> { where(status: "submitted") }
  scope :for_session, ->(sid) { where(session_id: sid) }
  scope :in_workflow, ->(wid) { where(workflow_session_id: wid) }
  scope :recent, -> { order(updated_at: :desc) }

  before_create :set_defaults

  # Find or create a draft submission for a form
  # @param form_definition [FormDefinition] The form to create submission for
  # @param user [User, nil] The authenticated user (if any)
  # @param session_id [String, nil] The anonymous session ID (if no user)
  # @param workflow [Workflow, nil] Optional workflow context
  # @return [Submission] The found or created submission
  def self.find_or_create_for(form_definition:, user: nil, session_id: nil, workflow: nil)
    scope = user ? user.submissions : where(session_id: session_id)
    scope.find_or_create_by!(
      form_definition: form_definition,
      workflow: workflow,
      status: "draft"
    )
  end

  def anonymous?
    user_id.nil?
  end

  def complete!
    update!(status: "completed", completed_at: Time.current)
  end

  def submit!
    update!(status: "submitted")
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

  after_commit :enqueue_webhook_events, on: [ :create, :update ]

  private

  def set_defaults
    self.workflow_session_id ||= SecureRandom.uuid if workflow_id.present?
  end

  def enqueue_webhook_events
    payload = {
      id: id,
      status: status,
      form_code: form_definition.code,
      updated_at: updated_at,
      user_id: user_id
    }
    Webhooks::Dispatcher.new.deliver(event: "submission.saved", payload: payload)
  end
end
