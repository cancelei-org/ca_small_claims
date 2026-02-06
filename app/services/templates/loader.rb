# frozen_string_literal: true

module Templates
  # Loads and caches quick fill scenario templates from YAML configuration
  class Loader
    include YamlDataLoader

    data_path Rails.root.join("config/templates/scenarios")
    file_pattern "*.yml"

    # Get all available templates
    # @return [Array<Hash>] array of template summaries
    def all
      data.values.map { |t| summary(t) }
    end

    # Get a specific template by ID
    # @param id [String] the scenario ID
    # @return [Hash, nil] the full template or nil if not found
    def find(id)
      data[id.to_s]
    end

    # Get templates by category
    # @param category [String] the category (e.g., "housing", "vehicle")
    # @return [Array<Hash>] array of template summaries
    def by_category(category)
      data.values
          .select { |t| t.dig(:scenario, :category) == category.to_s }
          .map { |t| summary(t) }
    end

    # Get templates matching a claim basis
    # @param claim_basis [String] the claim basis value
    # @return [Array<Hash>] array of matching template summaries
    def for_claim_basis(claim_basis)
      data.values
          .select { |t| t.dig(:scenario, :claim_types)&.include?(claim_basis.to_s) }
          .map { |t| summary(t) }
    end

    private

    def process_file(_file_path, file_data)
      id = file_data.dig(:scenario, :id)
      @data[id] = file_data if id.present?
    end

    def summary(template)
      scenario = template[:scenario] || {}
      {
        id: scenario[:id],
        name: scenario[:name],
        description: scenario[:description],
        icon: scenario[:icon],
        category: scenario[:category],
        claim_types: scenario[:claim_types] || []
      }
    end
  end
end
