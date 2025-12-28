# frozen_string_literal: true

class FormDefinition < ApplicationRecord
  belongs_to :category, optional: true

  has_many :field_definitions, dependent: :destroy
  has_many :workflow_steps, dependent: :destroy
  has_many :workflows, through: :workflow_steps
  has_many :submissions, dependent: :destroy
  has_many :session_submissions, dependent: :destroy
  has_many :form_feedbacks, dependent: :destroy

  validates :code, presence: true, uniqueness: true
  validates :title, presence: true
  validates :pdf_filename, presence: true

  scope :active, -> { where(active: true) }
  scope :by_category, ->(cat) { joins(:category).where(categories: { slug: cat }) }
  scope :by_category_id, ->(id) { where(category_id: id) }
  scope :ordered, -> { order(:position, :code) }
  scope :fillable_forms, -> { where(fillable: true) }
  scope :non_fillable_forms, -> { where(fillable: false) }

  # Legacy constant for backward compatibility during migration
  LEGACY_CATEGORIES = %w[filing service pre_trial judgment post_judgment special info plaintiff defendant enforcement appeal collections informational fee_waiver].freeze

  def pdf_path
    Rails.root.join("lib", "pdf_templates", pdf_filename)
  end

  def pdf_exists?
    File.exist?(pdf_path)
  end

  def sections
    field_definitions.group_by(&:section).transform_values { |fields| fields.sort_by(&:position) }
  end

  def required_fields
    field_definitions.where(required: true)
  end

  def shared_field_keys
    field_definitions.where.not(shared_field_key: nil).pluck(:shared_field_key)
  end

  def fields_by_page
    field_definitions.group_by(&:page_number)
  end

  def to_param
    code
  end

  # Returns the PDF generation strategy for this form
  # :form_filling for fillable PDFs (pdftk/HexaPDF)
  # :html_generation for non-fillable PDFs (Grover/HTML)
  def generation_strategy
    fillable? ? :form_filling : :html_generation
  end

  # Returns the path to the HTML template for non-fillable forms
  def html_template_path
    return nil if fillable?

    normalized_code = code.downcase.gsub("-", "")
    Rails.root.join("app/views/pdf_templates/small_claims/#{normalized_code}.html.erb")
  end

  # Checks if an HTML template exists for this form
  def html_template_exists?
    return false if fillable?

    File.exist?(html_template_path)
  end

  # Returns true if this form can be generated as a PDF
  def can_generate_pdf?
    fillable? ? pdf_exists? : html_template_exists?
  end

  # Returns feedback statistics for this form
  def feedback_stats
    {
      total: form_feedbacks.count,
      pending: form_feedbacks.pending.count,
      average_rating: form_feedbacks.average(:rating)&.round(1) || 0,
      low_rated_count: form_feedbacks.low_rated.count
    }
  end

  # Returns true if this form has pending feedback that needs attention
  def needs_attention?
    form_feedbacks.pending.exists? || form_feedbacks.low_rated.unresolved.exists?
  end
end
