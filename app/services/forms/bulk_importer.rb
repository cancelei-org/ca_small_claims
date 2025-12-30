# frozen_string_literal: true

module Forms
  class BulkImporter
    attr_reader :metadata_path, :pdf_source_dir, :options, :stats, :errors

    DEFAULT_OPTIONS = {
      dry_run: false,
      skip_pdfs: false,
      skip_fields: false,
      category_filter: nil,  # e.g., "SC" for small claims only
      batch_size: 100,
      verbose: false
    }.freeze

    def initialize(metadata_path:, pdf_source_dir:, options: {})
      @metadata_path = metadata_path
      @pdf_source_dir = pdf_source_dir
      @options = DEFAULT_OPTIONS.merge(options)
      @stats = {
        categories: 0,
        forms_created: 0,
        forms_updated: 0,
        fields_created: 0,
        fields_updated: 0,
        pdfs_copied: 0,
        pdfs_skipped: 0,
        errors: 0
      }
      @errors = []
      @field_classifier = FieldTypeClassifier.new
    end

    def import!
      log_start

      ActiveRecord::Base.transaction do
        create_categories!
        import_forms!
        copy_pdf_templates! unless @options[:skip_pdfs]

        if @options[:dry_run]
          log "DRY RUN - Rolling back all changes"
          raise ActiveRecord::Rollback
        end
      end

      log_completion
      self
    end

    def parser
      @parser ||= MetadataParser.new(@metadata_path)
    end

    private

    def create_categories!
      log "Creating categories..."
      @stats[:categories] = CategoryMapper.create_all!
      log "  Created/verified #{@stats[:categories]} categories"
    end

    def import_forms!
      log "Importing forms..."
      forms_data = parser.parse

      if @options[:category_filter]
        filter = @options[:category_filter].upcase
        forms_data = forms_data.select { |f| f[:category_prefix] == filter }
        log "  Filtered to #{forms_data.count} forms with prefix: #{filter}"
      end

      total = forms_data.count
      forms_data.each_with_index do |form_data, index|
        import_single_form(form_data)

        if (index + 1) % @options[:batch_size] == 0
          log "  Progress: #{index + 1}/#{total} forms processed..."
        end
      end
    end

    def import_single_form(form_data)
      ActiveRecord::Base.transaction(requires_new: true) do
        form = upsert_form_definition(form_data)
        generate_field_definitions(form, form_data) if form_data[:is_fillable] && !@options[:skip_fields]
      end
    rescue ActiveRecord::RecordInvalid => e
      handle_error(form_data, "Validation error: #{e.message}")
    rescue StandardError => e
      handle_error(form_data, "#{e.class}: #{e.message}")
    end

    def upsert_form_definition(form_data)
      form = FormDefinition.find_or_initialize_by(code: form_data[:form_number])
      was_new = form.new_record?

      category = CategoryMapper.category_for_prefix(form_data[:category_prefix])

      form.assign_attributes(
        title: generate_title(form_data),
        description: generate_description(form_data),
        pdf_filename: form_data[:filename],
        fillable: form_data[:is_fillable],
        page_count: form_data[:num_pages],
        category_id: category&.id,
        position: calculate_position(form_data),
        active: true,
        metadata: {
          file_size: form_data[:file_size],
          total_fields: form_data[:total_fields],
          pii_fields: form_data[:pii_fields],
          source_path: form_data[:source_path],
          imported_at: Time.current.iso8601
        }
      )
      # Also store prefix string in the legacy category column (write directly to avoid association conflict)
      form.write_attribute(:category, form_data[:category_prefix])

      form.save!

      if was_new
        @stats[:forms_created] += 1
      else
        @stats[:forms_updated] += 1
      end

      log_verbose "  #{was_new ? 'Created' : 'Updated'}: #{form.code} - #{form.title}"
      form
    end

    def generate_field_definitions(form, form_data)
      return if form_data[:field_names].blank?

      existing_field_ids = []
      position = 0

      form_data[:field_names].each do |pdf_field_name|
        next if @field_classifier.skip_field?(pdf_field_name)

        position += 1
        field = upsert_field_definition(form, pdf_field_name, form_data, position)
        existing_field_ids << field.id if field
      end

      # Don't remove existing fields on re-import (they may have been manually curated)
      # This is different from SchemaLoader which removes fields not in schema
    end

    def upsert_field_definition(form, pdf_field_name, form_data, position)
      sanitized_name = @field_classifier.sanitize_name(pdf_field_name)

      # Ensure unique name within form
      sanitized_name = ensure_unique_field_name(form, sanitized_name, position)

      field = form.field_definitions.find_or_initialize_by(name: sanitized_name)
      was_new = field.new_record?

      # Determine field type from metadata if available
      pdf_type = detect_pdf_type(pdf_field_name, form_data[:field_types])
      field_type = @field_classifier.classify(pdf_field_name, pdf_type)

      field.assign_attributes(
        pdf_field_name: pdf_field_name,
        field_type: field_type,
        label: @field_classifier.humanize_label(pdf_field_name),
        section: @field_classifier.detect_section(pdf_field_name),
        position: position,
        required: false  # Default to not required; can be curated later
      )

      field.save!

      if was_new
        @stats[:fields_created] += 1
      else
        @stats[:fields_updated] += 1
      end

      field
    rescue ActiveRecord::RecordInvalid => e
      handle_error({ form: form.code, field: pdf_field_name }, "Field error: #{e.message}")
      nil
    end

    def ensure_unique_field_name(form, base_name, position)
      return base_name if form.new_record?

      existing = form.field_definitions.where(name: base_name).where.not(position: position).exists?
      return base_name unless existing

      # Append position to make unique
      "#{base_name}_#{position}"
    end

    def detect_pdf_type(pdf_field_name, field_types)
      return nil unless field_types.is_a?(Hash)

      # The field_types hash contains counts like {"text": 12, "checkbox": 6}
      # We can use the field name pattern to guess the type
      return "checkbox" if pdf_field_name.match?(/^checkbox/i)
      return "text" if pdf_field_name.match?(/^(fill)?text/i)

      nil
    end

    def copy_pdf_templates!
      log "Copying PDF templates..."

      copier = Pdf::TemplateCopier.new(
        source_dir: @pdf_source_dir,
        target_dir: Rails.root.join("lib", "pdf_templates")
      )

      # Get filenames from parsed forms
      filenames = parser.parse.map { |f| f[:filename] }

      if @options[:category_filter]
        filter = @options[:category_filter].downcase
        filenames = filenames.select { |f| f.downcase.start_with?(filter) }
      end

      copier.copy_all!(filenames)

      @stats[:pdfs_copied] = copier.stats[:copied]
      @stats[:pdfs_skipped] = copier.stats[:skipped]

      copier.errors.each do |error|
        @errors << { type: :pdf, **error }
      end

      log "  Copied: #{@stats[:pdfs_copied]}, Skipped: #{@stats[:pdfs_skipped]}"
    end

    def generate_title(form_data)
      # Use form number as base title
      # Can be enhanced later with actual form titles from a lookup
      form_data[:form_number]
    end

    def generate_description(form_data)
      category_name = CategoryMapper.category_name(form_data[:category_prefix])
      pages = form_data[:num_pages]
      fields = form_data[:total_fields]

      parts = []
      parts << "California #{category_name} form" if category_name
      parts << "#{pages} page#{'s' if pages != 1}" if pages.positive?
      parts << "#{fields} field#{'s' if fields != 1}" if fields.positive?
      parts << "(fillable)" if form_data[:is_fillable]

      parts.join(", ").presence
    end

    def calculate_position(form_data)
      # Prioritize Small Claims forms
      prefix = form_data[:category_prefix]
      form_number = form_data[:form_number]

      # Extract numeric portion for ordering within category
      numeric = form_number.scan(/\d+/).first.to_i

      case prefix
      when "SC"
        # Small claims: positions 1-1000
        numeric
      else
        # Other categories: positions 1000+, grouped by category
        category_offset = CategoryMapper::CATEGORIES.dig(prefix, :position) || 999
        (category_offset * 100) + numeric
      end
    end

    def handle_error(context, message)
      @stats[:errors] += 1
      error_entry = { context: context, error: message, timestamp: Time.current }
      @errors << error_entry
      Rails.logger.error "[BulkImporter] #{context}: #{message}"
    end

    def log(message)
      puts message if @options[:verbose] || !Rails.env.test?
      Rails.logger.info "[BulkImporter] #{message}"
    end

    def log_verbose(message)
      return unless @options[:verbose]

      puts message
      Rails.logger.debug "[BulkImporter] #{message}"
    end

    def log_start
      log "=" * 60
      log "California Court Forms Bulk Import"
      log "=" * 60
      log "Source: #{@pdf_source_dir}"
      log "Metadata: #{@metadata_path}"
      log "Options: #{@options.except(:verbose)}"
      log "Mode: #{@options[:dry_run] ? 'DRY RUN' : 'LIVE'}"
      log ""
    end

    def log_completion
      log ""
      log "=" * 60
      log "Import #{@options[:dry_run] ? 'Preview' : 'Complete'}"
      log "=" * 60
      log "Categories: #{@stats[:categories]}"
      log "Forms created: #{@stats[:forms_created]}"
      log "Forms updated: #{@stats[:forms_updated]}"
      log "Fields created: #{@stats[:fields_created]}"
      log "Fields updated: #{@stats[:fields_updated]}"
      log "PDFs copied: #{@stats[:pdfs_copied]}"
      log "PDFs skipped: #{@stats[:pdfs_skipped]}"
      log "Errors: #{@stats[:errors]}"

      if @errors.any?
        log ""
        log "First #{[ @errors.count, 10 ].min} errors:"
        @errors.first(10).each do |error|
          log "  - #{error[:context]}: #{error[:error]}"
        end
        log "  ... and #{@errors.count - 10} more" if @errors.count > 10
      end
    end
  end
end
