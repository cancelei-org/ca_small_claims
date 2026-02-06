# frozen_string_literal: true

module Utilities
  # Loads and provides access to pre-form requirements configuration
  class FormRequirementService
    include Singleton

    CONFIG_PATH = Rails.root.join("config", "form_requirements.yml")

    def initialize
      @config = Utilities::YamlLoader.load_file(CONFIG_PATH)
    end

    # Get requirements for a form
    def for_form(form_code)
      form_config = @config.dig(:forms, form_code.to_sym) || @config[:default_form_requirements]

      {
        title: form_config[:title],
        description: form_config[:description],
        estimated_time: form_config[:estimated_time],
        categories: build_categories(form_config[:requirements]),
        defaults: @config[:defaults]
      }
    end

    private

    def build_categories(requirements_config)
      return [] unless requirements_config

      @config[:categories].map do |key, cat_config|
        items = requirements_config[key]
        next nil unless items&.any?

        {
          key: key,
          label: cat_config[:label],
          icon: cat_config[:icon],
          description: cat_config[:description],
          items: items
        }
      end.compact
    end
  end
end
