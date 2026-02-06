# frozen_string_literal: true

module Pdf
  module Strategies
    class GenerationError < StandardError; end
    class TemplateNotFoundError < GenerationError; end

    class Base
      attr_reader :submission, :form_definition

      def initialize(submission)
        @submission = submission
        @form_definition = submission.form_definition
      end

      def generate
        raise NotImplementedError, "#{self.class} must implement #generate"
      end

      def generate_flattened
        # Default: same as generate (HTML-based PDFs are already "flat")
        generate
      end

      protected

      def output_path
        timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
        filename = "#{form_definition.code}_#{submission.id}_#{timestamp}.pdf"
        Rails.root.join("tmp", "generated_pdfs", filename).to_s
      end

      def ensure_output_directory
        dir = Rails.root.join("tmp", "generated_pdfs")
        FileUtils.mkdir_p(dir) unless File.directory?(dir)
      end

      def update_generation_timestamp
        submission.update(pdf_generated_at: Time.current)
      end
    end
  end
end
