# frozen_string_literal: true

module Pdf
  class FieldExtractor
    attr_reader :pdf_path

    def initialize(pdf_path)
      @pdf_path = pdf_path.to_s
    end

    def extract
      return [] unless File.exist?(@pdf_path)

      # Prefer HexaPDF for better position data (rect coordinates)
      # Fall back to pdftk if HexaPDF fails
      fields = extract_with_hexapdf
      return fields if fields.any?

      # Fallback to pdftk if HexaPDF fails
      if pdftk_available?
        fields = extract_with_pdftk
        return fields if fields.any?
      end

      []
    rescue StandardError => e
      Rails.logger.error "PDF field extraction failed: #{e.message}"
      []
    end

    def field_names
      extract.map { |f| f[:name] }
    end

    private

    def pdftk_available?
      Utilities::PdftkResolver.available?
    end

    def extract_with_pdftk
      pdftk = PdfForms.new(pdftk_path)
      fields = pdftk.get_fields(@pdf_path)

      extracted = fields.map do |field|
        {
          name: field.name,
          type: detect_field_type(field),
          options: field.options,
          value: field.value,
          page: extract_page_from_name(field.name),
          rect: nil  # pdftk doesn't provide rect directly
        }
      end

      # Sort by page number extracted from field names
      extracted.sort_by { |f| [ f[:page] || 999, f[:name] ] }
    rescue StandardError => e
      # pdftk failed (e.g., encrypted PDF) - will fallback to HexaPDF
      Rails.logger.debug "pdftk extraction failed, will try HexaPDF: #{e.message}"
      []
    end

    def extract_page_from_name(field_name)
      # Many PDF fields include page number in their name: Page1, Page2, p1, p2, etc.
      match = field_name.to_s.match(/page\s*(\d+)|p(\d+)\[/i)
      return match[1].to_i if match && match[1]
      return match[2].to_i if match && match[2]

      nil
    end

    def extract_with_hexapdf
      require "hexapdf"

      doc = HexaPDF::Document.open(@pdf_path)
      fields = []

      doc.acro_form&.each_field do |field|
        # Get position data from widget annotation
        widget = field.each_widget.first
        rect = extract_rect(widget)
        page_num = find_page_for_widget(doc, widget) || extract_page_from_name(field.full_field_name)

        fields << {
          name: field.full_field_name,
          type: hexapdf_field_type(field),
          options: field[:Opt]&.to_a,
          value: field.field_value,
          page: page_num,
          rect: rect  # [x1, y1, x2, y2] - PDF coords (origin bottom-left)
        }
      end

      # Sort by page, then by visual position (top-to-bottom, left-to-right)
      sort_fields_by_position(fields)
    rescue StandardError => e
      Rails.logger.warn "HexaPDF extraction failed: #{e.message}"
      []
    end

    def extract_rect(widget)
      return nil unless widget

      rect = widget[:Rect]
      return nil unless rect

      # Handle both array and HexaPDF::Rectangle types
      if rect.respond_to?(:to_a)
        rect.to_a.map(&:to_f)
      elsif rect.is_a?(Array)
        rect.map(&:to_f)
      end
    rescue StandardError
      nil
    end

    def find_page_for_widget(doc, widget)
      return nil unless widget

      doc.pages.each_with_index do |page, idx|
        annots = page[:Annots]
        next unless annots

        # Check if this page contains the widget
        if annots.any? { |a| a&.value == widget.value rescue false }
          return idx + 1
        end
      end
      nil
    end

    def sort_fields_by_position(fields)
      fields.sort_by do |f|
        page = f[:page] || 999
        rect = f[:rect] || [ 0, 0, 0, 0 ]
        # PDF Y coordinates: higher = higher on page, so negate for top-to-bottom sort
        y_pos = rect[3] ? -rect[3] : 0
        x_pos = rect[0] || 0
        [ page, y_pos, x_pos ]
      end
    end

    def pdftk_path
      Utilities::PdftkResolver.path
    end

    def detect_field_type(field)
      type = field.type&.to_s&.downcase

      case type
      when "button"
        field.options&.any? ? "radio" : "checkbox"
      when "choice"
        "select"
      when "text"
        detect_text_subtype(field.name)
      else
        "text"
      end
    end

    def hexapdf_field_type(field)
      case field.field_type
      when :Btn
        field.check_box? ? "checkbox" : "radio"
      when :Ch
        "select"
      when :Tx
        detect_text_subtype(field.full_field_name)
      else
        "text"
      end
    end

    def detect_text_subtype(field_name)
      name = field_name.to_s.downcase

      case name
      when /date/ then "date"
      when /phone|tel/ then "tel"
      when /email/ then "email"
      when /amount|currency|\$|money/ then "currency"
      when /signature|sig/ then "signature"
      when /address/ then "address"
      else "text"
      end
    end
  end
end
