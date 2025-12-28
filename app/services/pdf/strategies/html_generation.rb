# frozen_string_literal: true

module Pdf
  module Strategies
    class HtmlGeneration < Base
      def generate
        ensure_output_directory

        # If we have an HTML template, render it
        # Otherwise, copy the original PDF (for INFO/static forms)
        if html_template_exists?
          generate_from_html
        else
          copy_original_pdf
        end
      end

      private

      def generate_from_html
        html_content = render_template
        pdf_data = generate_pdf_from_html(html_content)

        File.binwrite(output_path, pdf_data)
        update_generation_timestamp

        output_path
      end

      def copy_original_pdf
        # For non-fillable forms without HTML templates (INFO sheets, etc.),
        # just copy the original PDF since there's nothing to fill
        original_path = form_definition.pdf_path.to_s

        unless File.exist?(original_path)
          raise "Original PDF not found: #{original_path}"
        end

        FileUtils.cp(original_path, output_path)
        update_generation_timestamp

        output_path
      end

      def html_template_exists?
        form_definition.html_template_exists?
      end

      def render_template
        ApplicationController.render(
          template: html_template_path,
          layout: "pdf_templates/layouts/court_form",
          assigns: template_assigns
        )
      end

      def html_template_path
        # Convert form code like "INT-200" to "int200"
        normalized_code = form_definition.code.downcase.gsub("-", "")
        "pdf_templates/small_claims/#{normalized_code}"
      end

      def template_assigns
        {
          submission: submission,
          form_definition: form_definition,
          form_data: submission.form_data || {},
          field_definitions: form_definition.field_definitions,
          form_code: form_definition.code,
          form_title: form_definition.title
        }
      end

      def generate_pdf_from_html(html)
        Grover.new(
          html,
          format: "Letter",
          margin: {
            top: "0.5in",
            bottom: "0.5in",
            left: "0.75in",
            right: "0.75in"
          },
          print_background: true,
          prefer_css_page_size: true,
          display_url: false,
          emulate_media: "print"
        ).to_pdf
      end
    end
  end
end
