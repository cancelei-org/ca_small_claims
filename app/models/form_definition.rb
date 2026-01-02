# frozen_string_literal: true

class FormDefinition < ApplicationRecord
  extend FriendlyId
  friendly_id :code, use: [ :slugged, :history ]

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
  scope :by_popularity, -> {
    left_joins(:submissions, :session_submissions)
      .group(:id)
      .order(Arel.sql("COUNT(submissions.id) + COUNT(session_submissions.id) DESC"))
  }
  scope :popular, ->(limit = 5) {
    by_popularity.limit(limit)
  }
  scope :fillable_forms, -> { where(fillable: true) }
  scope :non_fillable_forms, -> { where(fillable: false) }
  scope :search, ->(query) {
    return all if query.blank?

    term = "%#{query.downcase}%"
    where("LOWER(code) LIKE ? OR LOWER(title) LIKE ? OR LOWER(description) LIKE ?", term, term, term)
  }

  # Legacy constant for backward compatibility during migration
  LEGACY_CATEGORIES = %w[filing service pre_trial judgment post_judgment special info plaintiff defendant enforcement appeal collections informational fee_waiver].freeze

  def pdf_path
    if use_s3_storage?
      S3::TemplateService.new.download_template(pdf_filename)
    else
      Rails.root.join("lib", "pdf_templates", pdf_filename)
    end
  end

  def pdf_exists?
    if use_s3_storage?
      S3::TemplateService.new.template_exists?(pdf_filename)
    else
      File.exist?(Rails.root.join("lib", "pdf_templates", pdf_filename))
    end
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
    slug.presence || code
  end

  # FriendlyId: Generate new slug when slug is blank or code changes
  def should_generate_new_friendly_id?
    slug.blank? || code_changed?
  end

  # FriendlyId: Normalize slug format (SC-100 → sc-100)
  def normalize_friendly_id(input)
    input.to_s.downcase.gsub(/[^a-z0-9\-]/, "-").gsub(/-+/, "-").gsub(/^-|-$/, "")
  end

  # PDF filename derived from slug (sc-100 → sc100.pdf)
  def pdf_filename_from_slug
    "#{slug.to_s.delete('-')}.pdf"
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

    normalized_code = code.downcase.delete("-")
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

  # Returns total usage count (submissions + session submissions)
  def usage_count
    submissions.count + session_submissions.count
  end

  # Returns true if this form is in the top N most popular forms
  def popular?(threshold: 5)
    self.class.active.popular(threshold).pluck(:id).include?(id)
  end

  # Returns recommended forms based on category and common workflows
  def recommended_next_forms(limit: 3)
    # Get forms from same category excluding self
    same_category = self.class.active.where(category_id: category_id)
                        .where.not(id: id)
                        .by_popularity
                        .limit(limit)
                        .to_a

    return same_category if same_category.size >= limit

    # Supplement with popular forms from other categories
    remaining = limit - same_category.size
    other_popular = self.class.active.where.not(id: id)
                        .where.not(id: same_category.map(&:id))
                        .popular(remaining)
                        .to_a

    same_category + other_popular
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

  # Returns coordinates for all fields in the form for X-Ray mode
  def field_coordinates
    metadata["field_coordinates"] ||= extract_field_coordinates
  end

  def extract_field_coordinates
    return {} unless pdf_exists?

    extractor = Pdf::FieldExtractor.new(pdf_path)
    fields = extractor.extract

    coords = fields.each_with_object({}) do |f, hash|
      next unless f[:rect]
      hash[f[:name]] = {
        page: f[:page],
        rect: f[:rect], # [x1, y1, x2, y2]
        type: f[:type]
      }
    end

    update_column(:metadata, metadata.merge("field_coordinates" => coords))
    coords
  end

  private

  def use_s3_storage?
    ENV.fetch("USE_S3_STORAGE", "false") == "true"
  end
end
