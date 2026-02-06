# frozen_string_literal: true

module Templates
  # Applies quick fill template data to a submission
  class Applier
    attr_reader :template, :submission, :customizations

    # @param template_id [String] the scenario template ID
    # @param submission [Submission] the submission to apply template to
    # @param customizations [Hash] user's answers to template customization questions
    def initialize(template_id:, submission:, customizations: {})
      @template = Loader.instance.find(template_id)
      @submission = submission
      @customizations = customizations.with_indifferent_access
    end

    # Apply the template prefills to the submission
    # @return [Hash] result with :success, :applied_fields, and :errors keys
    def apply
      return error_result("Template not found") unless @template
      return error_result("Submission required") unless @submission
      return error_result("Form definition required") unless @submission.form_definition

      form_code = @submission.form_definition.code
      prefills = find_prefills_for_form(form_code)

      return success_result([]) if prefills.blank?

      applied_fields = apply_prefills(prefills)

      # Track that a template was applied
      mark_template_applied

      success_result(applied_fields)
    end

    # Get tips relevant to this template
    # @return [Array<Hash>] array of tips with :title and :content
    def tips
      @template&.dig(:tips) || []
    end

    # Get related forms for this template
    # @return [Array<Hash>] array of related forms with :code and :reason
    def related_forms
      @template&.dig(:related_forms) || []
    end

    # Get customization questions for this template
    # @return [Array<Hash>] array of questions for the user
    def customization_questions
      @template&.dig(:scenario, :customization) || []
    end

    private

    def find_prefills_for_form(form_code)
      prefills = @template[:prefills] || {}

      # Determine which prefill variant to use based on customizations
      variant_key = determine_variant_key
      variant_prefills = prefills[variant_key.to_sym] || prefills[:default] || {}

      variant_prefills[form_code.to_sym] || variant_prefills[form_code.to_s] || {}
    end

    def determine_variant_key
      # Check customization questions for the variant selector
      questions = customization_questions
      return :default if questions.blank?

      # The first question usually determines the variant
      primary_question = questions.first
      return :default unless primary_question

      question_id = primary_question[:id]
      @customizations[question_id] || :default
    end

    def apply_prefills(prefills)
      applied = []
      current_data = @submission.form_data || {}

      prefills.each do |field_name, value|
        field_name_str = field_name.to_s

        # Only prefill if the field is currently empty or matches placeholder pattern
        if should_apply_field?(current_data[field_name_str], value)
          current_data[field_name_str] = value
          applied << field_name_str
        end
      end

      @submission.update!(form_data: current_data) if applied.any?
      applied
    end

    def should_apply_field?(current_value, new_value)
      # Apply if field is empty
      return true if current_value.blank?

      # Don't overwrite user-entered data
      false
    end

    def mark_template_applied
      metadata = @submission.form_data["_template_metadata"] || {}
      metadata["template_id"] = @template.dig(:scenario, :id)
      metadata["template_name"] = @template.dig(:scenario, :name)
      metadata["applied_at"] = Time.current.iso8601
      metadata["customizations"] = @customizations.to_h

      @submission.update!(
        form_data: @submission.form_data.merge("_template_metadata" => metadata)
      )
    end

    def success_result(applied_fields)
      {
        success: true,
        applied_fields: applied_fields,
        tips: tips,
        related_forms: related_forms,
        errors: []
      }
    end

    def error_result(message)
      {
        success: false,
        applied_fields: [],
        tips: [],
        related_forms: [],
        errors: [ message ]
      }
    end
  end
end
