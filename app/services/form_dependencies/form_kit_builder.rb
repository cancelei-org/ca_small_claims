# frozen_string_literal: true

module FormDependencies
  # FormKitBuilder generates form kit recommendations based on user context
  # and provides access to predefined form bundles
  class FormKitBuilder
    include Singleton

    CONFIG_PATH = Rails.root.join("config/form_dependencies.yml")

    def initialize
      @config = load_config
    end

    # Get all available form kits
    # @return [Array<Hash>] Array of kit configurations
    def all_kits
      kits = @config["form_kits"] || {}
      kits.map { |key, kit| build_kit(key, kit) }
    end

    # Get a specific form kit by key
    # @param kit_key [String] The kit identifier
    # @return [Hash, nil] Kit configuration or nil
    def kit(kit_key)
      kit_config = @config.dig("form_kits", kit_key)
      return nil unless kit_config

      build_kit(kit_key, kit_config)
    end

    # Get kits for a specific role (plaintiff, defendant, or both)
    # @param role [String] The role
    # @return [Array<Hash>] Matching kits
    def kits_for_role(role)
      all_kits.select { |k| k[:role] == role || k[:role] == "both" }
    end

    # Get kits for a specific stage
    # @param stage [String] The stage name
    # @return [Array<Hash>] Matching kits
    def kits_for_stage(stage)
      all_kits.select { |k| k[:stage] == stage }
    end

    # Get recommended kits based on a current form
    # @param form_code [String] The current form code
    # @return [Array<Hash>] Recommended kits
    def recommended_kits_for(form_code)
      mapper = DependencyMapper.instance
      stage = mapper.stage_for(form_code)
      role = mapper.role_for(form_code)

      # Find kits that match the current context
      all_kits.select do |kit|
        # Kit matches if:
        # 1. Contains the current form, OR
        # 2. Is for a subsequent stage with matching role
        kit_contains_form?(kit, form_code) ||
          (kit_follows_stage?(kit, stage) && kit_matches_role?(kit, role))
      end.first(3)
    end

    # Get a kit that contains a specific form
    # @param form_code [String] The form code
    # @return [Hash, nil] Kit containing the form or nil
    def kit_containing(form_code)
      normalized = form_code.to_s.upcase
      all_kits.find do |kit|
        kit[:forms].any? { |f| f[:code] == normalized }
      end
    end

    # Build a custom kit from a list of form codes
    # @param form_codes [Array<String>] Array of form codes
    # @param name [String] Custom kit name
    # @return [Hash] Custom kit structure
    def build_custom_kit(form_codes, name: "Custom Kit")
      forms = form_codes.map.with_index do |code, idx|
        form_def = FormDefinition.find_by(code: code.upcase)
        {
          code: code.upcase,
          title: form_def&.title || code,
          description: form_def&.description,
          required: true,
          order: idx + 1,
          exists: form_def.present?,
          path: form_def ? "/forms/#{form_def.to_param}" : nil
        }
      end

      {
        key: "custom",
        name: name,
        description: "Custom form collection",
        icon: "collection",
        forms: forms,
        form_count: forms.count,
        estimated_time: estimate_time(forms.count),
        completion_percentage: 0
      }
    end

    # Calculate kit completion based on user submissions
    # @param kit_key [String] The kit identifier
    # @param user [User, nil] The user (optional)
    # @param session_id [String, nil] Session ID for anonymous users
    # @return [Hash] Completion stats
    def kit_completion(kit_key, user: nil, session_id: nil)
      kit_config = kit(kit_key)
      return nil unless kit_config

      form_codes = kit_config[:forms].pluck(:code)
      completed = []

      form_codes.each do |code|
        form_def = FormDefinition.find_by(code: code)
        next unless form_def

        submission = find_submission(form_def, user, session_id)
        completed << code if submission&.completion_percentage.to_i >= 80
      end

      {
        total: form_codes.count,
        completed: completed.count,
        percentage: form_codes.any? ? (completed.count.to_f / form_codes.count * 100).round : 0,
        completed_forms: completed,
        remaining_forms: form_codes - completed
      }
    end

    # Get featured kits for home page
    # @param limit [Integer] Maximum number of kits
    # @return [Array<Hash>] Featured kits
    def featured_kits(limit: 4)
      # Prioritize: complete_filing, defendant_response, judgment_collection
      priority = %w[complete_filing defendant_response judgment_collection pre_trial]

      priority.take(limit).filter_map { |key| kit(key) }
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

    def build_kit(key, kit_config)
      forms = (kit_config["forms"] || []).map do |form|
        form_def = FormDefinition.find_by(code: form["code"])
        {
          code: form["code"],
          title: form_def&.title || form["code"],
          description: form_def&.description,
          required: form["required"] != false,
          order: form["order"] || 0,
          note: form["note"],
          exists: form_def.present?,
          path: form_def ? "/forms/#{form_def.to_param}" : nil
        }
      end.sort_by { |f| f[:order] }

      stage_info = DependencyMapper.instance.stage_info(kit_config["stage"])

      {
        key: key,
        name: kit_config["name"],
        description: kit_config["description"],
        icon: kit_config["icon"],
        stage: kit_config["stage"],
        stage_info: stage_info,
        role: kit_config["role"],
        recommended_for: kit_config["recommended_for"] || [],
        forms: forms,
        form_count: forms.count,
        required_form_count: forms.count { |f| f[:required] },
        estimated_time: kit_config["estimated_time"],
        important_deadline: kit_config["important_deadline"]
      }
    end

    def kit_contains_form?(kit, form_code)
      normalized = form_code.to_s.upcase
      kit[:forms].any? { |f| f[:code] == normalized }
    end

    def kit_follows_stage?(kit, current_stage)
      return false unless kit[:stage] && current_stage

      stages = DependencyMapper.instance.all_stages
      current_order = stages.find { |s| s["key"] == current_stage }&.dig("order") || 0
      kit_order = stages.find { |s| s["key"] == kit[:stage] }&.dig("order") || 0

      kit_order > current_order
    end

    def kit_matches_role?(kit, role)
      return true if kit[:role] == "both" || role == "both"

      kit[:role] == role
    end

    def find_submission(form_def, user, session_id)
      if user
        form_def.submissions.find_by(user_id: user.id)
      elsif session_id
        form_def.session_submissions.find_by(session_id: session_id)
      end
    end

    def estimate_time(form_count)
      base_time = 15 # minutes per form
      total = form_count * base_time
      "#{total}-#{total + 15} minutes"
    end
  end
end
