# frozen_string_literal: true

module Forms
  class SchemaValidator
    REQUIRED_FORM_KEYS = %w[code title pdf_filename category].freeze
    REQUIRED_FIELD_KEYS = %w[name type label].freeze
    VALID_FIELD_TYPES = %w[
      text textarea tel email date currency number
      checkbox radio select signature address
      hidden readonly
    ].freeze

    class ValidationError < StandardError; end

    attr_reader :errors, :warnings

    def initialize
      @errors = []
      @warnings = []
    end

    def validate(schema, file_path: nil)
      @errors = []
      @warnings = []
      @file_path = file_path

      return self unless schema.is_a?(Hash)

      validate_form_metadata(schema[:form] || schema["form"])
      validate_sections(schema[:sections] || schema["sections"])
      validate_pdf_exists(schema.dig(:form, :pdf_filename) || schema.dig("form", "pdf_filename"))

      self
    end

    def valid?
      @errors.empty?
    end

    def to_s
      result = []
      result << "File: #{@file_path}" if @file_path
      result << "Errors: #{@errors.join(', ')}" if @errors.any?
      result << "Warnings: #{@warnings.join(', ')}" if @warnings.any?
      result << "Valid" if valid? && @warnings.empty?
      result.join("\n")
    end

    def validate!
      raise ValidationError, @errors.join(", ") unless valid?

      self
    end

    class << self
      def validate_all
        results = { valid: [], invalid: [], warnings: [] }
        schema_files.each do |file|
          schema = load_schema(file)
          validator = new.validate(schema, file_path: file)

          if validator.valid?
            results[:valid] << file
            results[:warnings] << { file: file, warnings: validator.warnings } if validator.warnings.any?
          else
            results[:invalid] << { file: file, errors: validator.errors }
          end
        end
        results
      end

      def validate_file(file_path)
        schema = load_schema(file_path)
        new.validate(schema, file_path: file_path)
      end

      def schema_files
        Dir.glob(Rails.root.join("config", "form_schemas", "**", "*.yml"))
           .reject { |f| f.include?("_shared/") }
      end

      def load_schema(file_path)
        result = Utilities::YamlLoader.safe_load_file(file_path)
        result[:success] ? result[:data] : { parse_error: result[:error] }
      end

      def check_shared_key_collisions
        keys = {}
        collisions = []

        schema_files.each do |file|
          schema = load_schema(file)
          form_code = schema.dig(:form, :code) || File.basename(file, ".yml").upcase

          extract_fields(schema).each do |field|
            shared_key = field[:shared_key]
            next unless shared_key

            if keys[shared_key]
              # Only warn if unnamespaced
              unless shared_key.include?(":")
                collisions << {
                  key: shared_key,
                  forms: [ keys[shared_key], form_code ]
                }
              end
            end
            keys[shared_key] = form_code
          end
        end

        collisions.uniq { |c| c[:key] }
      end

      private

      def extract_fields(schema)
        fields = []
        sections = schema[:sections] || schema["sections"] || {}

        sections.each do |_section_name, section_data|
          section_data = {} unless section_data.is_a?(Hash)
          (section_data[:fields] || section_data["fields"] || []).each do |field|
            fields << field.transform_keys(&:to_sym)
          end
        end

        fields
      end
    end

    private

    def validate_form_metadata(form_data)
      unless form_data.is_a?(Hash)
        @errors << "Missing 'form' section"
        return
      end

      REQUIRED_FORM_KEYS.each do |key|
        if form_data[key.to_sym].nil? && form_data[key].nil?
          @errors << "Missing required form key: #{key}"
        end
      end

      # Validate category exists
      category = form_data[:category] || form_data["category"]
      if category && !Category.exists?(slug: category)
        @warnings << "Category '#{category}' not found in database"
      end
    end

    def validate_sections(sections)
      unless sections.is_a?(Hash) || sections.is_a?(Array)
        @errors << "Missing or invalid 'sections'"
        return
      end

      field_names = []
      sections_data = sections.is_a?(Hash) ? sections.values : sections

      sections_data.each do |section_data|
        next unless section_data.is_a?(Hash)

        fields = section_data[:fields] || section_data["fields"] || []
        fields.each do |field|
          validate_field(field, field_names)
        end
      end
    end

    def validate_field(field, field_names)
      unless field.is_a?(Hash)
        @errors << "Invalid field definition (not a hash)"
        return
      end

      field = field.transform_keys(&:to_sym)

      # Check required keys
      REQUIRED_FIELD_KEYS.each do |key|
        if field[key.to_sym].nil?
          @errors << "Field missing required key '#{key}': #{field.inspect}"
        end
      end

      # Validate field type
      field_type = field[:type]&.to_s
      unless field_type.nil? || VALID_FIELD_TYPES.include?(field_type)
        @errors << "Invalid field type '#{field_type}' for field '#{field[:name]}'"
      end

      # Check for duplicate field names
      name = field[:name]
      if field_names.include?(name)
        @errors << "Duplicate field name: #{name}"
      else
        field_names << name
      end

      # Validate shared key format (recommend namespacing)
      shared_key = field[:shared_key]
      if shared_key && !shared_key.include?(":")
        @warnings << "Unnamespaced shared_key '#{shared_key}' in field '#{name}' (consider using 'common:#{shared_key}')"
      end
    end

    def validate_pdf_exists(pdf_filename)
      return if pdf_filename.nil?

      pdf_path = Rails.root.join("lib", "pdf_templates", pdf_filename)
      @warnings << "PDF file not found: #{pdf_filename}" unless File.exist?(pdf_path)
    end
  end
end
