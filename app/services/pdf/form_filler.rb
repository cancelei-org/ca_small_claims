# frozen_string_literal: true

module Pdf
  class FormFiller
    CACHE_TTL = 10.seconds

    attr_reader :submission

    def initialize(submission)
      @submission = submission
      @form_definition = submission.form_definition
    end

    def generate
      cached_generate { strategy.generate }
    end

    def generate_flattened
      # Flattened PDFs are for download, always generate fresh
      strategy.generate_flattened
    end

    private

    def cached_generate
      cache_key = submission.pdf_cache_key

      # Try to get from cache first
      cached_pdf = Rails.cache.read(cache_key)
      if cached_pdf && submission.pdf_cache_valid?
        Rails.logger.debug { "PDF cache hit for submission #{submission.id}" }
        return cached_pdf
      end

      # Generate fresh PDF
      Rails.logger.debug { "PDF cache miss for submission #{submission.id}, generating..." }
      pdf_data = yield

      # Cache the result
      Rails.cache.write(cache_key, pdf_data, expires_in: CACHE_TTL)
      submission.mark_pdf_generated!

      pdf_data
    end

    def strategy
      @strategy ||= if @form_definition.fillable?
        Strategies::FormFilling.new(@submission)
      else
        Strategies::HtmlGeneration.new(@submission)
      end
    end
  end
end
