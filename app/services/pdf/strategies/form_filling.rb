# frozen_string_literal: true

module Pdf
  module Strategies
    class FormFilling < Base
      def generate
        ensure_output_directory
        pdf_data = build_pdf_data

        if pdftk_available?
          fill_with_pdftk(pdf_data)
        else
          fill_with_hexapdf(pdf_data)
        end
      end

      def generate_flattened
        output = generate
        return output unless pdftk_available?

        flattened_path = output.sub(".pdf", "_flattened.pdf")

        success = system(pdftk_path, output, "output", flattened_path, "flatten")

        unless success
          Rails.logger.error "pdftk flatten failed with exit status #{$?.exitstatus} for #{output}"
          return output
        end

        unless File.exist?(flattened_path)
          Rails.logger.error "pdftk flatten succeeded but output file not found: #{flattened_path}"
          return output
        end

        flattened_path
      end

      private

      def template_path
        form_definition.pdf_path.to_s
      end

      def pdftk_available?
        Utilities::PdftkResolver.available?
      end

      def pdftk_path
        Utilities::PdftkResolver.path
      end

      def fill_with_pdftk(pdf_data)
        pdftk = PdfForms.new(pdftk_path)
        path = output_path

        pdftk.fill_form(
          template_path,
          path,
          pdf_data,
          flatten: false
        )

        update_generation_timestamp
        path
      rescue PdfForms::PdftkError => e
        # pdftk can fail on encrypted PDFs - fall back to HexaPDF
        Rails.logger.warn "pdftk failed (#{e.message}), falling back to HexaPDF"
        fill_with_hexapdf(pdf_data)
      end

      def fill_with_hexapdf(pdf_data)
        require "hexapdf"

        doc = HexaPDF::Document.open(template_path)
        path = output_path

        doc.acro_form&.each_field do |field|
          field_name = field.full_field_name
          next unless pdf_data.key?(field_name)

          value = pdf_data[field_name]
          set_hexapdf_field_value(field, value)
        end

        doc.write(path)
        update_generation_timestamp
        path
      rescue StandardError => e
        Rails.logger.error "HexaPDF fill failed: #{e.message}"
        raise
      end

      def set_hexapdf_field_value(field, value)
        case field.field_type
        when :Btn
          if field.check_box?
            field.field_value = (truthy_value?(value) ? (field.allowed_values.first || :Yes) : nil)
          else
            field.field_value = value.to_sym
          end
        when :Ch, :Tx
          field.field_value = value.to_s
        end
      end

      def build_pdf_data
        form_definition.field_definitions.each_with_object({}) do |field, data|
          value = submission.field_value(field.name)
          next if value.blank? && !field.field_type.in?(%w[checkbox])

          pdf_field_name = resolve_field_name(field)
          formatted_value = format_value(value, field)

          data[pdf_field_name] = formatted_value
        end
      end

      def resolve_field_name(field)
        name = field.pdf_field_name
        return name unless name.include?("{index}")

        # Handle repeating fields - for now, just use index 0
        name.gsub("{index}", "0")
      end

      def format_value(value, field)
        case field.field_type
        when "checkbox"
          truthy_value?(value) ? "Yes" : "Off"
        when "date"
          format_date(value)
        when "currency"
          format_currency(value)
        when "checkbox_group"
          Array(value).join(", ")
        else
          value.to_s
        end
      end

      def format_date(value)
        return "" if value.blank?

        date = value.is_a?(Date) ? value : Date.parse(value.to_s)
        date.strftime("%m/%d/%Y")
      rescue ArgumentError
        value.to_s
      end

      def format_currency(value)
        return "" if value.blank?

        sprintf("%.2f", value.to_f)
      end

      def truthy_value?(value)
        value == true ||
          value == "1" ||
          value == "true" ||
          value == "Yes" ||
          value == "on"
      end
    end
  end
end
