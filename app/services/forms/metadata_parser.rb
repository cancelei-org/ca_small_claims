# frozen_string_literal: true

module Forms
  class MetadataParser
    attr_reader :json_path

    def initialize(json_path)
      @json_path = json_path
    end

    def parse
      results.map { |result| normalize_result(result) }
    end

    def stats
      @stats ||= data[:stats]
    end

    def forms_by_category
      stats[:forms_by_category] || {}
    end

    def fillable_by_category
      stats[:fillable_by_category] || {}
    end

    def total_forms
      stats[:total_forms] || 0
    end

    def fillable_forms
      stats[:fillable_forms] || 0
    end

    private

    def data
      @data ||= JSON.parse(File.read(json_path), symbolize_names: true)
    end

    def results
      data[:results] || []
    end

    def normalize_result(result)
      {
        form_number: extract_form_number(result),
        filename: result[:filename],
        source_path: result[:path],
        file_size: result[:file_size],
        is_fillable: result[:is_fillable] == true,
        num_pages: result[:num_pages] || 0,
        total_fields: result[:total_fields] || 0,
        pii_fields: result[:pii_fields] || 0,
        field_names: filter_field_names(result[:field_names] || []),
        pii_field_names: result[:pii_field_names] || [],
        field_types: result[:field_types] || {},
        category_prefix: extract_prefix(result[:form_number] || result[:filename]),
        error: result[:error]
      }
    end

    def extract_form_number(result)
      form_num = result[:form_number]
      return form_num if form_num.present?

      # Fallback: extract from filename (e.g., "sc100.pdf" -> "SC-100")
      filename = result[:filename].to_s.sub(/\.pdf$/i, "")
      normalize_form_number(filename)
    end

    def normalize_form_number(raw)
      # Convert "sc100" to "SC-100", "fl300a" to "FL-300A"
      return raw.upcase if raw.include?("-")

      match = raw.match(/^([a-z]+)(\d+)([a-z]*)$/i)
      return raw.upcase unless match

      prefix = match[1].upcase
      number = match[2]
      suffix = match[3].upcase
      "#{prefix}-#{number}#{suffix}"
    end

    def extract_prefix(form_number)
      return nil if form_number.blank?

      # Handle both "SC-100" and "sc100" formats
      normalized = form_number.to_s.upcase
      match = normalized.match(/^([A-Z]+)/)
      match&.[](1)
    end

    def filter_field_names(field_names)
      # Remove utility fields that shouldn't be imported as user-facing fields
      skip_patterns = [
        /^Save$/i,
        /^Print$/i,
        /^Reset(Form)?$/i,
        /^Clear$/i,
        /^WhiteOut/i,
        /^NoticeHeader/i,
        /^NoticeFooter/i,
        /^#pageSet/i
      ]

      field_names.reject do |name|
        skip_patterns.any? { |pattern| name.match?(pattern) }
      end
    end
  end
end
