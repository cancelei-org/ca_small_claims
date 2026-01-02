# frozen_string_literal: true

module Forms
  # Service to filter form fields for wizard mode
  # Supports skipping fields that already have data for authenticated users
  # Preserves conditional field dependencies
  class FieldFilterService
    attr_reader :form_definition, :submission, :user

    def initialize(form_definition, submission, user = nil)
      @form_definition = form_definition
      @submission = submission
      @user = user
    end

    # Returns fields suitable for wizard mode display
    # @param skip_filled [Boolean] Skip fields with existing data (authenticated users only)
    # @return [Array<FieldDefinition>] Ordered array of visible fields
    def wizard_fields(skip_filled: false)
      fields = visible_fields

      fields = fields.reject { |field| field_has_value?(field) } if skip_filled && user.present?

      # Ensure conditional trigger fields are included even if filtered out
      ensure_conditional_triggers(fields)
    end

    # Returns count of fields that would be shown in wizard
    def wizard_field_count(skip_filled: false)
      wizard_fields(skip_filled: skip_filled).count
    end

    # Returns fields that have been filled (for progress tracking)
    def filled_fields
      visible_fields.select { |field| field_has_value?(field) }
    end

    # Returns fields that are still empty
    def empty_fields
      visible_fields.reject { |field| field_has_value?(field) }
    end

    private

    def visible_fields
      @visible_fields ||= form_definition
        .field_definitions
        .by_position
        .reject { |f| hidden_field_type?(f) }
    end

    def hidden_field_type?(field)
      %w[hidden readonly].include?(field.field_type)
    end

    def field_has_value?(field)
      return false unless submission

      value = submission.field_value(field.name)
      value.present? && value.to_s.strip.present?
    end

    # Ensures fields that trigger conditional logic are included
    # even if they would otherwise be filtered out
    def ensure_conditional_triggers(fields)
      return fields if fields.empty?

      trigger_field_names = collect_trigger_field_names(fields)
      return fields if trigger_field_names.empty?

      # Find any trigger fields that were filtered out
      field_ids = fields.map(&:id)
      missing_triggers = form_definition
        .field_definitions
        .where(name: trigger_field_names.to_a)
        .where.not(id: field_ids)

      # Combine and sort by position (global order matching PDF form layout)
      (fields + missing_triggers.to_a).sort_by { |f| f.position.to_i }
    end

    def collect_trigger_field_names(fields)
      trigger_names = Set.new

      fields.each do |field|
        next unless field.conditional?

        # conditions is a Hash like { "show_when" => { "field" => "some_field", "value" => true } }
        extract_trigger_fields_from_conditions(field.conditions, trigger_names)
      end

      trigger_names
    end

    # Recursively extracts field names from conditions hash
    def extract_trigger_fields_from_conditions(conditions, trigger_names)
      return unless conditions.is_a?(Hash)

      conditions.each do |key, value|
        if key.to_s == "field" && value.is_a?(String)
          trigger_names << value
        elsif value.is_a?(Hash)
          extract_trigger_fields_from_conditions(value, trigger_names)
        elsif value.is_a?(Array)
          value.each do |item|
            extract_trigger_fields_from_conditions(item, trigger_names) if item.is_a?(Hash)
          end
        end
      end
    end
  end
end
