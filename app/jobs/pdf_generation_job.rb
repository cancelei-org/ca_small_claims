# frozen_string_literal: true

class PdfGenerationJob < ApplicationJob
  queue_as :pdfs

  def perform(submission_class, submission_id, flattened: false)
    record = submission_class.constantize.find(submission_id)
    path = flattened ? record.generate_flattened_pdf : record.generate_pdf
    record.mark_pdf_generated! if record.respond_to?(:mark_pdf_generated!)
    path
  end
end
