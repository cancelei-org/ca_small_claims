# frozen_string_literal: true

module FormEstimates
  # Calculates form complexity based on field count, types, and requirements.
  #
  # Complexity levels:
  # - :easy (1-10 fields) - Simple forms with basic text fields
  # - :medium (11-25 fields) - Moderate forms with some complex fields
  # - :complex (26+ fields) - Complex forms with many fields or complex types
  #
  # @example
  #   calculator = FormEstimates::ComplexityCalculator.new(form_definition)
  #   calculator.difficulty_level # => :medium
  #   calculator.difficulty_label # => "Medium"
  #   calculator.complexity_score # => 18
  #
  class ComplexityCalculator
    # Field type weights - complex fields are weighted higher
    FIELD_TYPE_WEIGHTS = {
      # Simple fields (weight 1)
      "text" => 1,
      "email" => 1,
      "tel" => 1,
      "number" => 1,
      "checkbox" => 1,
      "hidden" => 0,
      "readonly" => 0,

      # Moderate complexity (weight 2)
      "textarea" => 2,
      "date" => 2,
      "currency" => 2,
      "select" => 2,
      "radio" => 2,
      "checkbox_group" => 2,

      # High complexity (weight 3)
      "address" => 3,
      "signature" => 3,
      "repeating_group" => 3
    }.freeze

    # Thresholds for complexity levels based on weighted score
    EASY_THRESHOLD = 15
    MEDIUM_THRESHOLD = 40

    # Labels for human-readable display
    DIFFICULTY_LABELS = {
      easy: "Easy",
      medium: "Medium",
      complex: "Complex"
    }.freeze

    attr_reader :form_definition

    # @param form_definition [FormDefinition] The form to calculate complexity for
    def initialize(form_definition)
      @form_definition = form_definition
      @fields = form_definition.field_definitions
    end

    # Calculate the overall complexity score
    # @return [Integer] Weighted complexity score
    def complexity_score
      @complexity_score ||= calculate_complexity_score
    end

    # Determine the difficulty level
    # @return [Symbol] :easy, :medium, or :complex
    def difficulty_level
      @difficulty_level ||= calculate_difficulty_level
    end

    # Get human-readable difficulty label
    # @return [String] "Easy", "Medium", or "Complex"
    def difficulty_label
      DIFFICULTY_LABELS[difficulty_level]
    end

    # Get total field count (excluding hidden/readonly)
    # @return [Integer]
    def total_fields
      @total_fields ||= visible_fields.count
    end

    # Get required field count
    # @return [Integer]
    def required_fields_count
      @required_fields_count ||= visible_fields.where(required: true).count
    end

    # Get breakdown of fields by type
    # @return [Hash<String, Integer>] Field type counts
    def fields_by_type
      @fields_by_type ||= visible_fields.group(:field_type).count
    end

    # Get count of complex field types
    # @return [Integer]
    def complex_fields_count
      complex_types = %w[address signature repeating_group]
      visible_fields.where(field_type: complex_types).count
    end

    private

    def visible_fields
      @visible_fields ||= @fields.where.not(field_type: %w[hidden readonly])
    end

    def calculate_complexity_score
      score = 0

      # Add weighted score for each field type
      fields_by_type.each do |field_type, count|
        weight = FIELD_TYPE_WEIGHTS.fetch(field_type, 1)
        score += count * weight
      end

      # Add bonus for required fields (they require more attention)
      score += (required_fields_count * 0.5).round

      # Add bonus for many sections (navigation complexity)
      section_count = @fields.distinct.pluck(:section).compact.count
      score += section_count if section_count > 3

      score
    end

    def calculate_difficulty_level
      score = complexity_score

      if score <= EASY_THRESHOLD
        :easy
      elsif score <= MEDIUM_THRESHOLD
        :medium
      else
        :complex
      end
    end
  end
end
