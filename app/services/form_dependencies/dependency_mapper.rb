# frozen_string_literal: true

module FormDependencies
  # DependencyMapper loads and queries form dependencies from configuration
  # Provides methods to find related forms, sequences, and navigation paths
  class DependencyMapper
    include Singleton

    CONFIG_PATH = Rails.root.join("config/form_dependencies.yml")

    def initialize
      @config = load_config
    end

    # Get all dependencies for a specific form code
    # @param form_code [String] The form code (e.g., "SC-100")
    # @return [Hash] Dependencies including next, previous, stage, and role
    def dependencies_for(form_code)
      normalized = normalize_code(form_code)
      @config.dig("dependencies", normalized) || {}
    end

    # Get forms that should come before this form
    # @param form_code [String] The form code
    # @return [Array<Hash>] Array of {code:, reason:} hashes
    def previous_forms(form_code)
      deps = dependencies_for(form_code)
      deps["previous"] || []
    end

    # Get forms that typically follow this form
    # @param form_code [String] The form code
    # @return [Array<Hash>] Array of {code:, reason:, required:} hashes
    def next_forms(form_code)
      deps = dependencies_for(form_code)
      deps["next"] || []
    end

    # Get required next forms only
    # @param form_code [String] The form code
    # @return [Array<Hash>] Required next forms
    def required_next_forms(form_code)
      next_forms(form_code).select { |f| f["required"] == true }
    end

    # Get optional next forms
    # @param form_code [String] The form code
    # @return [Array<Hash>] Optional next forms
    def optional_next_forms(form_code)
      next_forms(form_code).reject { |f| f["required"] == true }
    end

    # Get the stage for a form
    # @param form_code [String] The form code
    # @return [String, nil] Stage name or nil
    def stage_for(form_code)
      dependencies_for(form_code)["stage"]
    end

    # Get the role for a form (plaintiff, defendant, or both)
    # @param form_code [String] The form code
    # @return [String, nil] Role or nil
    def role_for(form_code)
      dependencies_for(form_code)["role"]
    end

    # Get stage information
    # @param stage_name [String] The stage name
    # @return [Hash] Stage info including name, description, color, icon
    def stage_info(stage_name)
      @config.dig("stages", stage_name) || {}
    end

    # Get all stages in order
    # @return [Array<Hash>] Stages sorted by order
    def all_stages
      stages = @config["stages"] || {}
      stages.map { |key, info| info.merge("key" => key) }
            .sort_by { |s| s["order"] || 0 }
    end

    # Get forms grouped by stage
    # @return [Hash] Stage key => Array of form codes
    def forms_by_stage
      deps = @config["dependencies"] || {}
      deps.each_with_object({}) do |(code, info), result|
        stage = info["stage"]
        next unless stage

        result[stage] ||= []
        result[stage] << code
      end
    end

    # Get the full sequence for a given sequence name
    # @param sequence_name [String] Sequence identifier
    # @return [Hash] Sequence with stage and forms
    def sequence(sequence_name)
      @config.dig("sequences", sequence_name) || {}
    end

    # Get all sequences
    # @return [Hash] All sequences
    def all_sequences
      @config["sequences"] || {}
    end

    # Build a flowchart structure for a form
    # Shows previous -> current -> next forms with stages
    # @param form_code [String] The form code
    # @return [Hash] Flowchart data structure
    def flowchart_for(form_code)
      normalized = normalize_code(form_code)
      deps = dependencies_for(normalized)
      stage = deps["stage"]

      {
        current: {
          code: normalized,
          stage: stage,
          stage_info: stage_info(stage),
          role: deps["role"]
        },
        previous: previous_forms(normalized).map do |form|
          enrich_form_reference(form)
        end,
        next: next_forms(normalized).map do |form|
          enrich_form_reference(form)
        end,
        stage_flow: build_stage_flow(stage)
      }
    end

    # Get related forms for display (combines previous and next)
    # @param form_code [String] The form code
    # @return [Array<Hash>] Enriched form references
    def related_forms(form_code)
      prev_forms = previous_forms(form_code).map { |f| f.merge("relationship" => "previous") }
      next_forms_list = next_forms(form_code).map { |f| f.merge("relationship" => "next") }

      (prev_forms + next_forms_list).map { |f| enrich_form_reference(f) }
    end

    # Check if forms are in a sequence
    # @param form_codes [Array<String>] Array of form codes
    # @return [Hash, nil] Matching sequence or nil
    def find_sequence_for(form_codes)
      normalized = form_codes.map { |c| normalize_code(c) }

      all_sequences.find do |_name, seq|
        seq_codes = (seq["forms"] || []).map { |f| f["code"] }
        (normalized - seq_codes).empty?
      end
    end

    # Reload configuration from file
    def reload!
      @config = load_config
    end

    private

    def load_config
      return {} unless File.exist?(CONFIG_PATH)

      YAML.load_file(CONFIG_PATH, permitted_classes: [ Symbol ])
    rescue StandardError => e
      Rails.logger.error("Failed to load form dependencies config: #{e.message}")
      {}
    end

    def normalize_code(code)
      code.to_s.upcase.gsub(/\s+/, "")
    end

    def enrich_form_reference(form_ref)
      code = form_ref["code"]
      form_def = FormDefinition.find_by(code: code)

      form_ref.merge(
        "title" => form_def&.title,
        "description" => form_def&.description,
        "exists" => form_def.present?,
        "path" => form_def ? "/forms/#{form_def.to_param}" : nil,
        "stage_info" => stage_info(stage_for(code))
      )
    end

    def build_stage_flow(current_stage)
      return [] unless current_stage

      stages = all_stages
      current_index = stages.find_index { |s| s["key"] == current_stage }
      return stages if current_index.nil?

      stages.map.with_index do |stage, idx|
        stage.merge(
          "status" => if idx < current_index
                        "completed"
                      elsif idx == current_index
                        "current"
                      else
                        "upcoming"
                      end
        )
      end
    end
  end
end
