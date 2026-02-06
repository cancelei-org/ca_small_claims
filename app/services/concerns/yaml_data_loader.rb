# frozen_string_literal: true

# Provides common YAML data loading functionality for singleton services.
# Includes singleton pattern, lazy loading, and reload capability.
#
# @example
#   class Templates::Loader
#     include YamlDataLoader
#
#     data_path Rails.root.join("config/templates/scenarios")
#     file_pattern "*.yml"
#
#     private
#
#     def process_file(file_path, data)
#       id = data.dig(:scenario, :id)
#       @data[id] = data if id.present?
#     end
#   end
#
module YamlDataLoader
  extend ActiveSupport::Concern

  included do
    include Singleton
  end

  class_methods do
    # Configure the data path for YAML files
    # @param path [Pathname, String] the path to the YAML files
    def data_path(path)
      @data_path = path
    end

    # Configure the file pattern to match
    # @param pattern [String] glob pattern (default: "*.yml")
    def file_pattern(pattern = "*.yml")
      @file_pattern = pattern
    end

    # Get the configured data path
    def configured_data_path
      @data_path
    end

    # Get the configured file pattern
    def configured_file_pattern
      @file_pattern || "*.yml"
    end
  end

  def initialize
    @data = {}
    @loaded = false
  end

  # Ensure data is loaded before accessing
  def ensure_loaded
    load_data unless @loaded
  end

  # Reload data from files
  def reload!
    @data = {}
    @loaded = false
    load_data
  end

  # Check if data has been loaded
  def loaded?
    @loaded
  end

  protected

  # Access the loaded data hash
  def data
    ensure_loaded
    @data
  end

  private

  def load_data
    return if @loaded

    path = self.class.configured_data_path
    pattern = self.class.configured_file_pattern

    return unless path

    Dir.glob(path.join(pattern)).each do |file|
      load_yaml_file(file)
    end

    after_load if respond_to?(:after_load, true)

    @loaded = true
  end

  def load_yaml_file(file_path)
    data = YAML.load_file(file_path, symbolize_names: true, permitted_classes: [ Symbol ])
    process_file(file_path, data)
  rescue StandardError => e
    Rails.logger.error("Failed to load YAML file #{file_path}: #{e.message}")
  end

  # Override this method to process each loaded file
  # @param file_path [String] path to the file
  # @param data [Hash] the parsed YAML data
  def process_file(file_path, data)
    # Default implementation stores by filename without extension
    key = File.basename(file_path, ".*")
    @data[key] = data
  end
end
