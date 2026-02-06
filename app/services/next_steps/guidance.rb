# frozen_string_literal: true

module NextSteps
  class Guidance
    include Singleton

    GUIDANCE_PATH = Rails.root.join("config/next_steps/guidance.yml")

    def initialize
      @config = load_config
    end

    # Get guidance for a specific form
    def for_form(form_definition, submission = nil)
      code = form_definition.is_a?(String) ? form_definition : form_definition.code
      category = form_definition.is_a?(String) ? nil : form_definition.category&.slug

      # Try form-specific guidance first
      guidance = form_guidance(code)

      # Fall back to category guidance
      guidance ||= category_guidance(category) if category

      # Fall back to default
      guidance ||= default_guidance

      # Process conditional steps based on submission data
      process_conditionals(guidance, submission)
    end

    # Get related forms for a form
    def related_forms_for(form_definition, submission = nil)
      guidance = for_form(form_definition, submission)
      related = guidance[:related_forms] || []

      # Filter by conditionals
      related.select do |form_ref|
        next true unless form_ref[:conditional]

        evaluate_conditional(form_ref[:conditional], submission)
      end.map do |form_ref|
        form = FormDefinition.find_by(code: form_ref[:code])
        next nil unless form

        {
          form: form,
          reason: form_ref[:reason]
        }
      end.compact
    end

    def reload!
      @config = load_config
    end

    private

    def load_config
      return {} unless File.exist?(GUIDANCE_PATH)

      YAML.load_file(GUIDANCE_PATH, permitted_classes: [ Symbol ])
    rescue StandardError => e
      Rails.logger.error("Failed to load next steps config: #{e.message}")
      {}
    end

    def form_guidance(code)
      form_config = @config.dig("forms", code)
      return nil unless form_config

      build_guidance(form_config)
    end

    def category_guidance(category_slug)
      category_config = @config.dig("categories", category_slug)
      return nil unless category_config

      default = @config["default"] || {}

      build_guidance(
        default.merge(category_config) { |_key, old, new| new.presence || old }
      )
    end

    def default_guidance
      build_guidance(@config["default"] || {})
    end

    def build_guidance(config)
      {
        title: config["title"] || "What Happens Next?",
        intro: config["intro"] || "Here's what to do after completing your form:",
        steps: (config["steps"] || []).map { |s| build_step(s) },
        related_forms: config["related_forms"] || [],
        resources: (config["resources"] || []).map { |r| build_resource(r) }
      }.with_indifferent_access
    end

    def build_step(step_config)
      {
        id: step_config["id"],
        title: step_config["title"],
        description: step_config["description"],
        icon: step_config["icon"] || "check",
        required: step_config["required"] != false,
        important: step_config["important"] == true,
        link: step_config["link"],
        conditional: step_config["conditional"]
      }.with_indifferent_access
    end

    def build_resource(resource_config)
      {
        title: resource_config["title"],
        url: resource_config["url"],
        description: resource_config["description"]
      }.with_indifferent_access
    end

    def process_conditionals(guidance, submission)
      return guidance unless submission

      guidance[:steps] = guidance[:steps].select do |step|
        next true unless step[:conditional]

        evaluate_conditional(step[:conditional], submission)
      end

      guidance
    end

    def evaluate_conditional(conditional, submission)
      return true unless submission && conditional

      # Simple conditional evaluation
      # Supports: "field_name", "!field_name"
      if conditional.start_with?("!")
        field_name = conditional[1..]
        !submission.field_value(field_name).present?
      else
        submission.field_value(conditional).present?
      end
    rescue StandardError
      true
    end
  end
end
