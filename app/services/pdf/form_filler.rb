# frozen_string_literal: true

module Pdf
  class FormFiller
    attr_reader :submission

    def initialize(submission)
      @submission = submission
      @form_definition = submission.form_definition
    end

    def generate
      strategy.generate
    end

    def generate_flattened
      strategy.generate_flattened
    end

    private

    def strategy
      @strategy ||= if @form_definition.fillable?
        Strategies::FormFilling.new(@submission)
      else
        Strategies::HtmlGeneration.new(@submission)
      end
    end
  end
end
