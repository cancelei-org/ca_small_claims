# frozen_string_literal: true

# Helper methods for rendering input fields with consistent styling
module InputFieldHelper
  # Standard class for text inputs
  def standard_input_class
    "input input-bordered w-full focus:input-primary"
  end

  # Standard class for textareas
  def standard_textarea_class
    "textarea textarea-bordered w-full focus:textarea-primary min-h-[100px]"
  end

  # Standard class for select dropdowns
  def standard_select_class
    "select select-bordered w-full focus:select-primary"
  end

  # Standard class for checkboxes
  def standard_checkbox_class
    "checkbox checkbox-primary"
  end

  # Standard class for radio buttons
  def standard_radio_class
    "radio radio-primary"
  end

  # Build data attributes for form fields
  # @param action [String] The Stimulus action string
  # @return [Hash] Data attributes hash
  def field_data_attributes(action: "input->form#fieldChanged")
    {
      data: {
        action: build_field_action(action)
      }
    }
  end

  # Build the Stimulus action string for a field
  # @param base_action [String] The base action to include
  # @return [String] Complete action string
  def build_field_action(base_action)
    actions = [base_action]

    # Add keyboard navigation for mobile
    actions << "keydown->keyboard-nav#handleKeydown"

    actions.join(" ")
  end

  # Get input mode attribute for a field type
  # @param field_type [String] The type of field
  # @return [String, nil] The inputmode value
  def input_mode_for(field_type)
    case field_type.to_s
    when "email" then "email"
    when "tel" then "tel"
    when "url" then "url"
    when "number", "currency" then "decimal"
    else nil
    end
  end

  # Get autocomplete attribute for a field
  # @param field [FieldDefinition] The field definition
  # @return [String, nil] The autocomplete value
  def autocomplete_for(field)
    case field.name.to_s
    when /email/ then "email"
    when /phone|tel/ then "tel"
    when /name/ then "name"
    when /address|street/ then "street-address"
    when /city/ then "address-level2"
    when /state/ then "address-level1"
    when /zip|postal/ then "postal-code"
    else nil
    end
  end

  # Build common options for input fields
  # @param field [FieldDefinition] The field definition
  # @param submission [Submission] The submission object
  # @param prefix [String, nil] Optional field name prefix
  # @return [Hash] Common options hash
  def common_field_options(field, submission, prefix: nil)
    {
      id: build_field_dom_id(field, prefix),
      class: standard_input_class,
      placeholder: field.placeholder,
      value: submission&.field_value(field.name)
    }.merge(field_data_attributes)
  end

  private

  # Generate unique DOM ID for a field
  # Named to avoid conflict with Rails' built-in field_id helper
  def build_field_dom_id(field, prefix = nil)
    prefix ? "#{prefix}_#{field.name}" : field.name.to_s
  end
end
