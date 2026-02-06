# frozen_string_literal: true

module FormDisplay
  extend ActiveSupport::Concern

  private

  # Load form display data for rendering form fields
  # Requires @form_definition to be set before calling
  # Sets @sections and @field_definitions for views
  def load_form_display_data
    return unless @form_definition

    @sections ||= @form_definition.sections
    @field_definitions ||= @form_definition.field_definitions.by_position
  end

  # Load form display data from a submission
  # @param submission [Submission] The submission to load form data from
  def load_form_display_from_submission(submission)
    return unless submission

    @form_definition = submission.form_definition
    load_form_display_data
  end

  # Safe accessor for field definitions (handles nil form_definition)
  # @return [Array<FieldDefinition>] The field definitions or empty array
  def safe_field_definitions
    @form_definition&.field_definitions&.by_position || []
  end
end
