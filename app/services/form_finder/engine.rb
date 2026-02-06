# frozen_string_literal: true

module FormFinder
  class Engine
    STEPS = %i[role situation details recommendations].freeze
    TOTAL_STEPS = STEPS.length

    attr_reader :state

    def initialize(session_state = nil)
      @state = session_state || default_state
    end

    def start
      @state = default_state
      self
    end

    def current_step
      STEPS[@state[:step] - 1]
    end

    def current_step_number
      @state[:step]
    end

    def total_steps
      TOTAL_STEPS
    end

    def progress
      {
        current: @state[:step],
        total: TOTAL_STEPS,
        percentage: ((@state[:step] - 1).to_f / TOTAL_STEPS * 100).round
      }
    end

    def answers
      @state[:answers].dup
    end

    def advance(new_answers = {})
      # Merge new answers first
      @state[:answers].merge!(normalize_answers(new_answers))

      # Then check if we can advance
      return false unless can_advance?

      @state[:step] += 1 unless at_final_step?

      # Skip details step if not needed
      skip_details_step_if_not_needed

      true
    end

    def go_back
      return false if at_first_step?

      @state[:step] -= 1

      # Skip details step backwards if not needed
      skip_details_step_backwards_if_not_needed

      true
    end

    def restart
      start
    end

    def at_first_step?
      @state[:step] == 1
    end

    def at_final_step?
      @state[:step] == TOTAL_STEPS
    end

    def can_advance?
      case current_step
      when :role
        @state[:answers][:role].present?
      when :situation
        @state[:answers][:situation].present?
      when :details
        true # Details are optional
      when :recommendations
        false # Can't advance past recommendations
      else
        false
      end
    end

    def needs_details_step?
      role = @state[:answers][:role]
      situation = @state[:answers][:situation]

      # Only plaintiff/new_case and defendant/counter_claim need details
      (role == "plaintiff" && situation == "new_case") ||
        (role == "defendant" && situation == "counter_claim")
    end

    def to_session
      @state.deep_dup
    end

    private

    def default_state
      {
        step: 1,
        answers: {
          role: nil,
          situation: nil,
          multiple_parties: false,
          needs_fee_waiver: false
        }
      }.with_indifferent_access
    end

    def normalize_answers(answers)
      answers.transform_values do |value|
        case value
        when "true", "1" then true
        when "false", "0" then false
        else value
        end
      end.with_indifferent_access
    end

    def skip_details_step_if_not_needed
      return unless current_step == :details && !needs_details_step?

      @state[:step] += 1
    end

    def skip_details_step_backwards_if_not_needed
      return unless current_step == :details && !needs_details_step?

      @state[:step] -= 1
    end
  end
end
