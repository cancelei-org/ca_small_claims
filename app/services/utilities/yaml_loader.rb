# frozen_string_literal: true

module Utilities
  # Centralizes YAML loading with consistent security options and error handling.
  # Provides safe defaults for loading schema files and other YAML configurations.
  #
  # @example Basic usage
  #   Utilities::YamlLoader.load_file("config/form_schemas/sc100.yml")
  #   # => { form: { code: "SC-100", ... }, sections: { ... } }
  #
  # @example Loading with custom options
  #   Utilities::YamlLoader.load_file(path, symbolize_names: false)
  #   # => { "form" => { "code" => "SC-100", ... } }
  #
  # @example Safe loading with error handling
  #   result = Utilities::YamlLoader.safe_load_file(path)
  #   if result[:success]
  #     data = result[:data]
  #   else
  #     error = result[:error]
  #   end
  #
  class YamlLoader
    # Default permitted classes for YAML.safe_load
    DEFAULT_PERMITTED_CLASSES = [ Symbol, Date, Time, DateTime ].freeze

    # Default options for YAML loading
    DEFAULT_OPTIONS = {
      symbolize_names: true,
      permitted_classes: DEFAULT_PERMITTED_CLASSES
    }.freeze

    class LoadError < StandardError; end

    class << self
      # Loads a YAML file with safe defaults
      #
      # @param file_path [String, Pathname] Path to the YAML file
      # @param options [Hash] Options to override defaults
      # @option options [Boolean] :symbolize_names (true) Convert keys to symbols
      # @option options [Array<Class>] :permitted_classes Classes allowed in YAML
      # @return [Hash] Parsed YAML content
      # @raise [LoadError] If file cannot be read or parsed
      def load_file(file_path, **options)
        opts = DEFAULT_OPTIONS.merge(options)

        content = File.read(file_path)
        parse(content, **opts)
      rescue Errno::ENOENT => e
        raise LoadError, "File not found: #{file_path}"
      rescue Errno::EACCES => e
        raise LoadError, "Permission denied: #{file_path}"
      rescue Psych::SyntaxError => e
        raise LoadError, "YAML syntax error in #{file_path}: #{e.message}"
      end

      # Safely loads a YAML file, returning a result hash instead of raising
      #
      # @param file_path [String, Pathname] Path to the YAML file
      # @param options [Hash] Options to override defaults
      # @return [Hash] Result hash with :success, :data, and optionally :error
      def safe_load_file(file_path, **options)
        data = load_file(file_path, **options)
        { success: true, data: data }
      rescue LoadError, StandardError => e
        { success: false, error: e.message, data: nil }
      end

      # Parses a YAML string with safe defaults
      #
      # @param content [String] YAML content
      # @param options [Hash] Options to override defaults
      # @return [Hash, Array, nil] Parsed YAML content
      def parse(content, **options)
        opts = DEFAULT_OPTIONS.merge(options)

        YAML.safe_load(
          content,
          permitted_classes: opts[:permitted_classes],
          symbolize_names: opts[:symbolize_names]
        )
      rescue Psych::SyntaxError => e
        raise LoadError, "YAML syntax error: #{e.message}"
      end

      # Safely parses a YAML string, returning a result hash
      #
      # @param content [String] YAML content
      # @param options [Hash] Options to override defaults
      # @return [Hash] Result hash with :success, :data, and optionally :error
      def safe_parse(content, **options)
        data = parse(content, **options)
        { success: true, data: data }
      rescue LoadError, StandardError => e
        { success: false, error: e.message, data: nil }
      end

      # Loads all YAML files from a directory (non-recursive)
      #
      # @param dir_path [String, Pathname] Path to the directory
      # @param options [Hash] Options for loading each file
      # @return [Hash] Hash of filename => parsed content (or error)
      def load_directory(dir_path, **options)
        pattern = File.join(dir_path, "*.yml")

        Dir.glob(pattern).each_with_object({}) do |file, hash|
          basename = File.basename(file, ".yml")
          result = safe_load_file(file, **options)

          hash[basename] = result[:success] ? result[:data] : { error: result[:error] }
        end
      end

      # Loads all YAML files recursively from a directory
      #
      # @param dir_path [String, Pathname] Path to the directory
      # @param options [Hash] Options for loading each file
      # @option options [Array<String>] :exclude Patterns to exclude (e.g., ["_shared/"])
      # @return [Hash] Hash of relative_path => parsed content (or error)
      def load_directory_recursive(dir_path, **options)
        exclude_patterns = options.delete(:exclude) || []
        pattern = File.join(dir_path, "**", "*.yml")

        Dir.glob(pattern).each_with_object({}) do |file, hash|
          # Skip files matching exclude patterns
          next if exclude_patterns.any? { |p| file.include?(p) }

          # Use relative path as key
          relative_path = file.sub("#{dir_path}/", "").sub(".yml", "")
          result = safe_load_file(file, **options)

          hash[relative_path] = result[:success] ? result[:data] : { error: result[:error] }
        end
      end

      # Validates that a file contains valid YAML
      #
      # @param file_path [String, Pathname] Path to the YAML file
      # @return [Boolean] true if valid YAML
      def valid?(file_path)
        safe_load_file(file_path)[:success]
      end
    end

    # Instance methods for dependency injection patterns

    def load_file(file_path, **options)
      self.class.load_file(file_path, **options)
    end

    def safe_load_file(file_path, **options)
      self.class.safe_load_file(file_path, **options)
    end

    def parse(content, **options)
      self.class.parse(content, **options)
    end

    def safe_parse(content, **options)
      self.class.safe_parse(content, **options)
    end

    def load_directory(dir_path, **options)
      self.class.load_directory(dir_path, **options)
    end

    def load_directory_recursive(dir_path, **options)
      self.class.load_directory_recursive(dir_path, **options)
    end

    delegate :valid?, to: :class
  end
end
