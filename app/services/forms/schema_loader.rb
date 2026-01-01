# frozen_string_literal: true

module Forms
  class SchemaLoader
    SCHEMA_PATH = Rails.root.join("config", "form_schemas")

    class << self
      def load(form_code)
        # Search recursively for the schema file
        file_path = find_schema_file(form_code)
        raise "Schema not found: #{form_code}" unless file_path

        Utilities::YamlLoader.load_file(file_path)
      end

      def load_all
        schema_files.each_with_object({}) do |file, hash|
          # Load schema first to get the canonical code from the file
          result = Utilities::YamlLoader.safe_load_file(file)
          next unless result[:success]

          schema = result[:data]
          # Use the code from the schema file (e.g., "SC-100") rather than filename
          form_code = schema.dig(:form, :code) || File.basename(file, ".yml").upcase
          hash[form_code] = schema
        rescue StandardError => e
          Rails.logger.warn "Failed to load schema #{file}: #{e.message}"
        end
      end

      def exists?(form_code)
        find_schema_file(form_code).present?
      end

      def schema_files
        Dir.glob(SCHEMA_PATH.join("**", "*.yml"))
           .reject { |f| f.include?("_shared/") }
      end

      private

      def find_schema_file(form_code)
        normalized = form_code.to_s.downcase
        # Also try without hyphens since schema files are named without them (e.g., sc100.yml not sc-100.yml)
        normalized_no_hyphen = normalized.delete("-")

        [ normalized, normalized_no_hyphen ].each do |code_variant|
          # Try flat path first for backward compatibility
          flat_path = SCHEMA_PATH.join("#{code_variant}.yml")
          return flat_path if File.exist?(flat_path)

          # Search recursively
          pattern = SCHEMA_PATH.join("**", "#{code_variant}.yml")
          found = Dir.glob(pattern).reject { |f| f.include?("_shared/") }.first
          return found if found
        end

        nil
      end

      public

      def sync_to_database!
        load_all.each do |code, schema|
          sync_form(code, schema)
        end
      end

      def sync_form(code, schema)
        form_data = schema[:form] || {}

        form = FormDefinition.find_or_initialize_by(code: code)
        form.update!(
          title: form_data[:title] || code,
          description: form_data[:description],
          category: find_category(form_data[:category]),
          pdf_filename: form_data[:pdf_filename] || "#{code.downcase}.pdf",
          page_count: form_data[:page_count],
          fillable: form_data.fetch(:fillable, true),
          metadata: form_data[:metadata] || {}
        )

        sync_fields!(form, schema)
        form
      end

      def find_category(category_string)
        return nil if category_string.blank?

        # Try direct slug match first
        category = Category.find_by(slug: category_string)
        return category if category

        # Try the last part of a path like "small_claims/general"
        slug = category_string.to_s.split("/").last&.tr("_", "-")
        category = Category.find_by(slug: slug)
        return category if category

        # Try without underscores/hyphens
        normalized = category_string.to_s.split("/").last&.gsub(/[_-]/, "")
        Category.where("LOWER(REPLACE(REPLACE(slug, '-', ''), '_', '')) = ?", normalized&.downcase).first
      end

      private

      def sync_fields!(form, schema)
        existing_field_ids = []

        sections = schema[:sections] || {}

        # Collect all fields with their section info, preserving extraction order
        all_fields = []
        extraction_order = 0

        # Handle both hash (section_name => section_data) and array formats
        if sections.is_a?(Hash)
          sections.each do |section_name, section_data|
            next unless section_data.is_a?(Hash) && section_data[:fields]

            section_data[:fields].each do |field_data|
              extraction_order += 1
              all_fields << {
                section_name: section_name.to_s,
                section_data: section_data,
                field_data: field_data,
                page: field_data[:page] || section_data[:page] || 999,
                extraction_order: extraction_order
              }
            end
          end
        elsif sections.is_a?(Array)
          sections.each do |section|
            section_name = section[:name] || "general"
            (section[:fields] || []).each do |field_data|
              extraction_order += 1
              all_fields << {
                section_name: section_name,
                section_data: section,
                field_data: field_data,
                page: field_data[:page] || section[:page] || 999,
                extraction_order: extraction_order
              }
            end
          end
        end

        # Sort by page first, then by original extraction order (visual position)
        all_fields.sort_by! { |f| [ f[:page].to_i, f[:extraction_order] ] }

        # Now sync with globally sorted positions
        all_fields.each_with_index do |entry, idx|
          position = idx + 1
          field = sync_field(form, entry[:section_name], entry[:section_data], entry[:field_data], position)
          existing_field_ids << field.id if field
        end

        # Remove fields no longer in schema
        form.field_definitions.where.not(id: existing_field_ids).destroy_all
      end

      def sync_field(form, section_name, section_data, field_data, position)
        return nil if field_data[:name].blank?

        field = form.field_definitions.find_or_initialize_by(
          name: field_data[:name]
        )

        field.update!(
          pdf_field_name: field_data[:pdf_field_name] || field_data[:name],
          field_type: field_data[:type] || "text",
          label: field_data[:label],
          help_text: field_data[:help_text],
          placeholder: field_data[:placeholder],
          required: field_data[:required] || false,
          validation_pattern: field_data[:validation] || field_data[:pattern],
          max_length: field_data[:max_length],
          min_length: field_data[:min_length],
          section: section_name,
          position: position,
          page_number: field_data[:page] || section_data[:page] || 1,  # Prefer field-level page
          width: field_data[:width] || "full",
          conditions: field_data[:conditions] || {},
          repeating_group: field_data[:repeating_group],
          max_repetitions: field_data[:max_repetitions],
          options: field_data[:options] || [],
          shared_field_key: field_data[:shared_key]
        )

        field
      end
    end
  end
end
