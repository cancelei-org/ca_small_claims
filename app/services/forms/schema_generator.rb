# frozen_string_literal: true

module Forms
  class SchemaGenerator
    VALID_FIELD_TYPES = %w[
      text textarea tel email date currency number
      checkbox checkbox_group radio select
      signature address hidden readonly
    ].freeze

    # Form code patterns to category mapping
    CATEGORY_MAP = {
      "SC" => "small_claims/general",
      "FL" => "family_law/general",
      "DV" => "family_law/domestic_violence",
      "CH" => "restraining_orders/civil_harassment",
      "EA" => "restraining_orders/elder_abuse",
      "GV" => "restraining_orders/gun_violence",
      "WV" => "restraining_orders/workplace_violence",
      "SV" => "restraining_orders/school_violence",
      "GC" => "guardianship/general",
      "JV" => "juvenile/general",
      "CR" => "criminal/general",
      "DE" => "probate/decedent",
      "TR" => "civil/traffic",
      "NC" => "civil/name_change",
      "MC" => "civil/miscellaneous",
      "CIV" => "civil/general",
      "EJ" => "civil/enforcement",
      "FW" => "administrative/fee_waiver",
      "POS" => "administrative/service",
      "SUM" => "administrative/service",
      "SUBP" => "civil/discovery",
      "INT" => "civil/discovery",
      "DISC" => "civil/discovery",
      "APP" => "administrative/general",
      "CARE" => "civil/care",
      "HC" => "civil/habeas_corpus",
      "MIL" => "civil/military",
      "PLD" => "civil/pleading",
      "WG" => "civil/wage_garnishment"
    }.freeze

    # Common shared key patterns
    SHARED_KEY_PATTERNS = {
      /plaintiff.*name/i => "plaintiff:name",
      /plaintiff.*street/i => "plaintiff:street",
      /plaintiff.*city/i => "plaintiff:city",
      /plaintiff.*state/i => "plaintiff:state",
      /plaintiff.*zip/i => "plaintiff:zip",
      /plaintiff.*phone/i => "plaintiff:phone",
      /plaintiff.*email/i => "plaintiff:email",
      /defendant.*name/i => "defendant:name",
      /petitioner.*name/i => "petitioner:name",
      /petitioner.*street/i => "petitioner:street",
      /respondent.*name/i => "respondent:name",
      /court.*name/i => "court:name",
      /court.*address/i => "court:address",
      /case.*number/i => "case:number",
      /filing.*date/i => "filing:date"
    }.freeze

    attr_reader :form_code, :options, :errors, :warnings

    def initialize(form_code, options = {})
      @form_code = normalize_form_code(form_code)
      @options = options
      @classifier = FieldTypeClassifier.new
      @errors = []
      @warnings = []
    end

    def generate
      @errors = []
      @warnings = []

      pdf_path = find_pdf_path
      unless pdf_path
        @errors << "PDF file not found for #{@form_code}"
        return nil
      end

      fields = extract_fields(pdf_path)
      if fields.empty?
        @warnings << "No fields extracted from #{@form_code} - may be non-fillable"
        return generate_non_fillable_schema(pdf_path)
      end

      generate_schema(fields, pdf_path)
    end

    def generate_to_file
      schema = generate
      return false unless schema

      output_path = schema_output_path
      ensure_directory_exists(output_path)

      File.write(output_path, schema.to_yaml)
      Rails.logger.info "Generated schema: #{output_path}"

      output_path
    rescue StandardError => e
      @errors << "Failed to write schema: #{e.message}"
      false
    end

    def self.generate_batch(prefix, options = {})
      results = { success: [], failed: [], skipped: [] }

      pdf_dir = Rails.root.join("lib", "pdf_templates")
      pattern = File.join(pdf_dir, "#{prefix.downcase}*.pdf")

      Dir.glob(pattern).each do |pdf_path|
        form_code = extract_form_code_from_filename(pdf_path)
        next unless form_code

        if schema_exists?(form_code) && !options[:force]
          results[:skipped] << form_code
          next
        end

        generator = new(form_code, options)
        if generator.generate_to_file
          results[:success] << form_code
        else
          results[:failed] << { code: form_code, errors: generator.errors }
        end
      end

      results
    end

    def self.analyze(prefix)
      report = []
      pdf_dir = Rails.root.join("lib", "pdf_templates")
      pattern = File.join(pdf_dir, "#{prefix.downcase}*.pdf")

      Dir.glob(pattern).each do |pdf_path|
        form_code = extract_form_code_from_filename(pdf_path)
        next unless form_code

        extractor = Pdf::FieldExtractor.new(pdf_path)
        fields = extractor.extract

        report << {
          code: form_code,
          fillable: fields.any?,
          field_count: fields.size,
          has_schema: schema_exists?(form_code),
          pdf_exists: true
        }
      end

      report.sort_by { |r| r[:code] }
    end

    private

    def normalize_form_code(code)
      Utilities::FormCodeNormalizer.normalize(code)
    end

    def find_pdf_path
      pdf_dir = Rails.root.join("lib", "pdf_templates")
      filename = "#{Utilities::FormCodeNormalizer.to_filename(@form_code)}.pdf"

      path = pdf_dir.join(filename)
      return path.to_s if File.exist?(path)

      # Try with hyphen (for backwards compatibility)
      filename_with_hyphen = "#{@form_code.downcase}.pdf"
      path_with_hyphen = pdf_dir.join(filename_with_hyphen)
      return path_with_hyphen.to_s if File.exist?(path_with_hyphen)

      nil
    end

    def extract_fields(pdf_path)
      extractor = Pdf::FieldExtractor.new(pdf_path)
      fields = extractor.extract

      # Filter out skip fields and deduplicate
      fields.reject { |f| @classifier.skip_field?(f[:name]) }
            .uniq { |f| f[:name] }
    end

    def generate_schema(fields, pdf_path)
      sections = group_fields_into_sections(fields)

      # Use symbol keys for compatibility with SchemaLoader
      {
        form: {
          code: @form_code,
          title: infer_title,
          description: "",
          category: infer_category_slug,
          pdf_filename: File.basename(pdf_path),
          fillable: true,
          instructions: ""
        },
        sections: sections
      }
    end

    def generate_non_fillable_schema(pdf_path)
      {
        form: {
          code: @form_code,
          title: infer_title,
          description: "",
          category: infer_category_slug,
          pdf_filename: File.basename(pdf_path),
          fillable: false,
          instructions: ""
        },
        sections: {}
      }
    end

    def group_fields_into_sections(fields)
      # Use LinkedHash-style ordering to preserve field insertion order
      sections = {}
      field_positions = Hash.new(0)
      section_order = []  # Track order sections are first encountered

      fields.each do |field|
        section_name = @classifier.detect_section(field[:name]) || "general"
        section_key = section_name.parameterize.underscore

        unless sections[section_key]
          section_order << section_key
          sections[section_key] = {
            title: section_name.titleize,
            page: field[:page],  # Page number for section ordering
            fields: []
          }
        end

        field_def = build_field_definition(field, field_positions)
        if field_def
          # Include page number in field definition for proper ordering
          field_def[:page] = field[:page] if field[:page]
          sections[section_key][:fields] << field_def
          field_positions[field_def[:name]] += 1
        end
      end

      # Return sections in the order they were first encountered (preserves visual order)
      section_order.each_with_object({}) do |key, ordered|
        ordered[key] = sections[key]
      end
    end

    def build_field_definition(field, field_positions)
      pdf_name = field[:name]
      base_name = @classifier.sanitize_name(pdf_name)

      # Handle duplicate field names with position suffix
      base_name = "#{base_name}_#{field_positions[base_name] + 1}" if field_positions[base_name].positive?

      field_type = classify_field_type(field)
      return nil unless VALID_FIELD_TYPES.include?(field_type)

      definition = {
        name: base_name,
        pdf_field_name: pdf_name,
        type: field_type,
        label: @classifier.humanize_label(pdf_name),
        required: false,
        width: infer_width(field_type)
      }

      # Add shared key if applicable
      shared_key = detect_shared_key(base_name, pdf_name)
      definition[:shared_key] = shared_key if shared_key

      # Add options for select/radio fields
      if %w[select radio].include?(field_type) && field[:options]&.any?
        definition[:options] = field[:options].map do |opt|
          { value: opt.to_s, label: opt.to_s.titleize }
        end
      end

      # Mark PII fields
      @warnings << "PII field detected: #{base_name}" if @classifier.pii_field?(pdf_name)

      definition
    end

    def classify_field_type(field)
      reported_type = field[:type].to_s

      # Use classifier for more accurate detection
      @classifier.classify(field[:name], reported_type)
    end

    def detect_shared_key(base_name, pdf_name)
      combined = "#{base_name} #{pdf_name}"

      SHARED_KEY_PATTERNS.each do |pattern, key|
        return key if combined.match?(pattern)
      end

      nil
    end

    def infer_width(field_type)
      case field_type
      when "textarea", "address"
        "full"
      when "signature"
        "full"
      when "date", "tel", "email"
        "half"
      when "checkbox"
        "full"
      when "currency", "number"
        "third"
      else
        "full"
      end
    end

    def infer_title
      # Basic title inference - should be enhanced or manually curated
      prefix = @form_code.split("-").first
      number = @form_code.split("-").last
      "#{prefix} #{number} Form"
    end

    def infer_category_slug
      prefix = @form_code.split("-").first.upcase
      CATEGORY_MAP[prefix] || "general"
    end

    def schema_output_path
      category_path = infer_category_slug
      filename = "#{@form_code.downcase.delete('-')}.yml"

      Rails.root.join("config", "form_schemas", category_path, filename)
    end

    def ensure_directory_exists(path)
      dir = File.dirname(path)
      FileUtils.mkdir_p(dir) unless File.directory?(dir)
    end

    def self.extract_form_code_from_filename(pdf_path)
      Utilities::FormCodeNormalizer.from_filename(pdf_path)
    end

    def self.schema_exists?(form_code)
      normalized = Utilities::FormCodeNormalizer.to_filename(form_code)
      Dir.glob(Rails.root.join("config", "form_schemas", "**", "#{normalized}.yml")).any?
    end
  end
end
