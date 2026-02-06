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

  # Returns fields grouped by section, and within each section,
  # identifies groups of fields that should be repeated together.
  # @return [Hash] { section_name => [ { type: :single, field: f }, { type: :group, name: 'g', fields: [...] } ] }
  def sections_with_groups
    field_definitions.group_by(&:section).transform_values do |fields|
      fields.sort_by(&:position).chunk_while do |a, b|
        a.repeating_group.present? && a.repeating_group == b.repeating_group
      end.map do |chunk|
        if chunk.first.repeating_group.present?
          { type: :group, name: chunk.first.repeating_group, fields: chunk }
        else
          chunk.map { |f| { type: :single, field: f } }
        end
      end.flatten
    end
  end

  after_commit -> { Cache::FormMetadataCache.invalidate! }, on: [ :create, :update, :destroy ]

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
  # Uses single query with UNION for efficiency
  def usage_count
    Submission.where(form_definition_id: id).count +
      SessionSubmission.where(form_definition_id: id).count
  end

  # Returns total usage count using cached counter (for batch operations)
  # Call with FormDefinition.with_usage_counts to preload
  def cached_usage_count
    @cached_usage_count ||= usage_count
  end

  # Batch load usage counts for multiple form definitions
  # Returns hash of {form_id => count}
  def self.usage_counts_for(form_ids)
    submission_counts = Submission.where(form_definition_id: form_ids)
                                  .group(:form_definition_id)
                                  .count
    session_counts = SessionSubmission.where(form_definition_id: form_ids)
                                      .group(:form_definition_id)
                                      .count

    form_ids.index_with do |id|
      (submission_counts[id] || 0) + (session_counts[id] || 0)
    end
  end

  # Returns true if this form is in the top N most popular forms
  # Optimized to use EXISTS query instead of loading all IDs into memory
  def popular?(threshold: 5)
    self.class.active.popular(threshold).exists?(id: id)
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

  # ============================================
  # Form Estimates (Difficulty & Time)
  # ============================================

  # Returns the estimated time to complete this form
  # @return [String] Formatted time estimate (e.g., "~15 min")
  def estimated_time
    time_estimator.formatted_estimate
  end

  # Returns the estimated minutes to complete this form
  # @return [Integer] Estimated minutes
  delegate :estimated_minutes, to: :time_estimator

  # Returns the difficulty level of this form
  # @return [Symbol] :easy, :medium, or :complex
  delegate :difficulty_level, to: :complexity_calculator

  # Returns human-readable difficulty label
  # @return [String] "Easy", "Medium", or "Complex"
  delegate :difficulty_label, to: :complexity_calculator

  # Returns the complexity score for this form
  # @return [Integer] Weighted complexity score
  delegate :complexity_score, to: :complexity_calculator

  # Returns detailed estimates including time range
  # @return [Hash] Hash with difficulty and time information
  def form_estimates
    {
      difficulty_level: difficulty_level,
      difficulty_label: difficulty_label,
      complexity_score: complexity_score,
      estimated_minutes: estimated_minutes,
      estimated_time: estimated_time,
      time_range: time_estimator.time_range,
      total_fields: complexity_calculator.total_fields,
      required_fields: complexity_calculator.required_fields_count
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

  def complexity_calculator
    @complexity_calculator ||= FormEstimates::ComplexityCalculator.new(self)
  end

  def time_estimator
    @time_estimator ||= FormEstimates::TimeEstimator.new(self)
  end

  def use_s3_storage?
    ENV.fetch("USE_S3_STORAGE", "false") == "true"
  end
end
