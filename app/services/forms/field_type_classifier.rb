# frozen_string_literal: true

module Forms
  class FieldTypeClassifier
    # Patterns to detect field types from PDF field names
    # Order matters: more specific patterns should come first
    FIELD_TYPE_PATTERNS = {
      signature: [
        /signature/i,
        /sig$/i,        # Ends with "Sig" (e.g., PetitionerSig)
        /sig[^a-z]/i,   # "Sig" followed by non-letter (e.g., Sig1)
        /\bsign\b/i
      ],
      date: [
        /date/i,
        /\bdob\b/i,
        /birth.*date/i,
        /date.*birth/i,
        /hearing.*date/i,
        /filing.*date/i
      ],
      email: [
        /email/i,
        /e-mail/i
      ],
      tel: [
        /phone/i,
        /tel(?:ephone)?/i,
        /fax/i,
        /mobile/i,
        /cell/i
      ],
      currency: [
        /amount/i,
        /fee/i,
        /cost/i,
        /payment/i,
        /\$\d/,
        /dollar/i,
        /money/i,
        /price/i,
        /total.*due/i,
        /balance/i
      ],
      address: [
        /address/i,
        /street/i,
        /city/i,
        /state/i,
        /zip/i,
        /postal/i,
        /mailing/i
      ],
      checkbox: [
        /^checkbox/i,
        /\bchk\b/i,
        /check.*box/i
      ]
    }.freeze

    # Patterns to identify PII fields
    PII_PATTERNS = [
      /ssn/i,
      /social.*security/i,
      /birth.*date/i,
      /date.*birth/i,
      /\bdob\b/i,
      /driver.*license/i,
      /license.*number/i,
      /passport/i,
      /alien.*number/i,
      /immigration/i,
      /bank.*account/i,
      /credit.*card/i,
      /routing.*number/i
    ].freeze

    # PDF field names to skip (utility buttons, not user data)
    SKIP_PATTERNS = [
      /^Save$/i,
      /^Print$/i,
      /^Reset(Form)?$/i,
      /^Clear$/i,
      /^Submit$/i,
      /^WhiteOut/i,
      /^NoticeHeader/i,
      /^NoticeFooter/i,
      /^#pageSet/i,
      /^#subform/i,
      /^\[.*\]$/  # Pure array references
    ].freeze

    def initialize
      @cache = {}
    end

    def classify(pdf_field_name, pdf_reported_type = nil)
      return "checkbox" if pdf_reported_type.to_s.downcase == "checkbox"
      return "select" if %w[select choice dropdown].include?(pdf_reported_type.to_s.downcase)

      @cache[pdf_field_name] ||= detect_type_from_name(pdf_field_name)
    end

    def skip_field?(pdf_field_name)
      SKIP_PATTERNS.any? { |pattern| pdf_field_name.match?(pattern) }
    end

    def pii_field?(pdf_field_name, known_pii_fields = [])
      return true if known_pii_fields.include?(pdf_field_name)

      PII_PATTERNS.any? { |pattern| pdf_field_name.match?(pattern) }
    end

    def humanize_label(pdf_field_name)
      # Extract the meaningful part from hierarchical field names
      # e.g., "DV-140[0].Page1[0].Name[0]" -> "Name"
      # e.g., "FillText123" -> "Fill Text 123"
      # e.g., "PlaintiffName" -> "Plaintiff Name"

      # Get the last meaningful segment
      segment = extract_last_segment(pdf_field_name)

      # Remove numeric suffixes and indices
      cleaned = segment.gsub(/\[\d+\]/, "").gsub(/\d+$/, "")

      # Convert camelCase or PascalCase to words
      words = cleaned.gsub(/([a-z])([A-Z])/, '\1 \2')
                     .gsub(/([A-Z]+)([A-Z][a-z])/, '\1 \2')

      # Clean up and titleize
      words.gsub(/[_\-.]/, " ")
           .squeeze(" ")
           .strip
           .titleize
    end

    def sanitize_name(pdf_field_name)
      # Create a database-safe field name
      # e.g., "DV-140[0].Page1[0].Name[0]" -> "page1_name"
      # e.g., "FillText123" -> "fill_text_123"

      segment = extract_last_segment(pdf_field_name)

      segment.gsub(/\[\d+\]/, "")              # Remove array indices
             .gsub(/([a-z])([A-Z])/, '\1_\2')  # CamelCase to snake_case
             .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
             .gsub(/[^a-zA-Z0-9]/, "_")        # Replace non-alphanumeric
             .gsub(/_+/, "_")                  # Collapse multiple underscores
             .gsub(/^_|_$/, "")                # Remove leading/trailing underscores
             .downcase
    end

    def detect_section(pdf_field_name)
      # Try to extract section information from hierarchical field names
      # e.g., "DV-140[0].Page1[0].Caption[0].Name[0]" -> "Caption"
      # e.g., "PartyInfo.Name" -> "Party Info"

      parts = pdf_field_name.split(/[.\[\]]/).reject(&:blank?)

      # Look for section-like parts (not the form name or final field)
      return nil if parts.length < 3

      # Skip form name (first) and field name (last)
      middle_parts = parts[1..-2]

      # Find the first non-page section
      section = middle_parts.find do |part|
        !part.match?(/^Page\d+$/i) && !part.match?(/^\d+$/) && !part.match?(/^#/)
      end

      section ? humanize_label(section) : nil
    end

    private

    def detect_type_from_name(pdf_field_name)
      FIELD_TYPE_PATTERNS.each do |type, patterns|
        return type.to_s if patterns.any? { |pattern| pdf_field_name.match?(pattern) }
      end

      "text"
    end

    def extract_last_segment(pdf_field_name)
      # For hierarchical names like "Form[0].Page[0].Field[0]", get "Field"
      # For simple names like "FillText123", return as-is

      parts = pdf_field_name.split(/[.\[\]]/).reject(&:blank?)

      # Skip purely numeric parts
      meaningful_parts = parts.reject { |p| p.match?(/^\d+$/) }

      return pdf_field_name if meaningful_parts.empty?

      # Return the last meaningful part
      meaningful_parts.last
    end
  end
end
