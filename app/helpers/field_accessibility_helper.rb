# frozen_string_literal: true

# Helper methods for field accessibility (ARIA attributes, error handling)
module FieldAccessibilityHelper
  # Generate ARIA attributes for form fields
  # Ensures proper accessibility for screen readers
  def field_aria_attributes(field, prefix: nil, errors: nil)
    attrs = {
      aria: {
        describedby: field_describedby(field, prefix, errors)
      }
    }

    if field_has_error?(field, errors)
      attrs[:aria][:invalid] = true
    end

    if field.required?
      attrs[:aria][:required] = true
      attrs[:required] = true
    end

    attrs
  end

  # Check if a field has validation errors
  def field_has_error?(field, errors)
    return false if errors.blank?

    error_key = field.name.to_sym
    errors.respond_to?(:key?) && errors.key?(error_key)
  end

  # Generate the error container element for a field
  def field_error_container(field, prefix: nil)
    content_tag(:p,
                "",
                id: field_error_id(field, prefix: prefix),
                class: "field-error text-error text-sm mt-1 hidden",
                aria: { live: "polite" })
  end

  # Generate unique ID for field error element
  def field_error_id(field, prefix: nil)
    base = prefix ? "#{prefix}_#{field.name}" : field.name
    "#{base}-error"
  end

  # Generate unique ID for field help text element
  def field_help_id(field, prefix: nil)
    base = prefix ? "#{prefix}_#{field.name}" : field.name
    "#{base}-help"
  end

  private

  # Build the aria-describedby value
  def field_describedby(field, prefix, errors)
    ids = []
    ids << field_help_id(field, prefix: prefix) if field.help_text.present?
    ids << field_error_id(field, prefix: prefix) if field_has_error?(field, errors)
    ids.presence&.join(" ")
  end
end
