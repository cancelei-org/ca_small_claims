# frozen_string_literal: true

module FormEstimates
  # Estimates time required to complete a form based on field count and complexity.
  #
  # Time estimation formula:
  #   base_time + (fields x time_per_field) + complexity_modifier
  #
  # @example
  #   estimator = FormEstimates::TimeEstimator.new(form_definition)
  #   estimator.estimated_minutes # => 15
  #   estimator.formatted_estimate # => "~15 min"
  #
  class TimeEstimator
    # Base time in minutes for any form (account opening, reading instructions)
    BASE_TIME_MINUTES = 2

    # Average time per field type in minutes
    TIME_PER_FIELD_TYPE = {
      # Quick fields (~30 seconds)
      "text" => 0.5,
      "email" => 0.5,
      "tel" => 0.5,
      "number" => 0.5,
      "checkbox" => 0.3,
      "hidden" => 0,
      "readonly" => 0,

      # Moderate fields (~1 minute)
      "textarea" => 1.5,
      "date" => 0.75,
      "currency" => 0.75,
      "select" => 0.5,
      "radio" => 0.5,
      "checkbox_group" => 1,

      # Complex fields (~2-3 minutes)
      "address" => 2.5,
      "signature" => 1.5,
      "repeating_group" => 3
    }.freeze

    # Complexity modifiers (added to total time)
    COMPLEXITY_MODIFIERS = {
      easy: 0,
      medium: 3,
      complex: 8
    }.freeze

    attr_reader :form_definition

    # @param form_definition [FormDefinition] The form to estimate time for
    def initialize(form_definition)
      @form_definition = form_definition
      @complexity_calculator = ComplexityCalculator.new(form_definition)
    end

    # Calculate estimated time in minutes
    # @return [Integer] Estimated minutes to complete
    def estimated_minutes
      @estimated_minutes ||= calculate_estimated_minutes
    end

    # Get formatted time estimate string
    # @return [String] Formatted estimate like "~15 min" or "~1 hr 20 min"
    def formatted_estimate
      @formatted_estimate ||= format_estimate(estimated_minutes)
    end

    # Get a time range estimate (min-max)
    # @return [Hash] Hash with :min and :max keys
    def time_range
      min = (estimated_minutes * 0.7).round
      max = (estimated_minutes * 1.5).round

      {
        min: [ min, 2 ].max, # At least 2 minutes
        max: max
      }
    end

    # Get formatted time range string
    # @return [String] Formatted range like "10-25 min"
    def formatted_range
      range = time_range
      "#{range[:min]}-#{range[:max]} min"
    end

    # Get time estimate category for quick display
    # @return [Symbol] :quick, :moderate, or :extended
    def time_category
      minutes = estimated_minutes

      if minutes <= 10
        :quick
      elsif minutes <= 30
        :moderate
      else
        :extended
      end
    end

    private

    def calculate_estimated_minutes
      # Start with base time
      total = BASE_TIME_MINUTES

      # Add time for each field based on type
      fields_by_type = @complexity_calculator.fields_by_type
      fields_by_type.each do |field_type, count|
        time_per_field = TIME_PER_FIELD_TYPE.fetch(field_type, 0.5)
        total += count * time_per_field
      end

      # Add complexity modifier
      difficulty = @complexity_calculator.difficulty_level
      total += COMPLEXITY_MODIFIERS.fetch(difficulty, 0)

      # Round to nearest 5 minutes for cleaner display (minimum 5 minutes)
      rounded = (total / 5.0).ceil * 5
      [ rounded, 5 ].max
    end

    def format_estimate(minutes)
      if minutes < 60
        "~#{minutes} min"
      else
        hours = minutes / 60
        remaining_minutes = minutes % 60

        if remaining_minutes.zero?
          hours == 1 ? "~1 hr" : "~#{hours} hrs"
        else
          "~#{hours} hr #{remaining_minutes} min"
        end
      end
    end
  end
end
