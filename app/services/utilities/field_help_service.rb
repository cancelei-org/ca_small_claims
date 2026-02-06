# frozen_string_literal: true

module Utilities
  # Provides access to field-specific help, examples, and validation messages.
  # Loads configuration from config/field_help.yml.
  class FieldHelpService
    include Singleton

    CONFIG_PATH = Rails.root.join("config", "field_help.yml")

    def initialize
      @config = Utilities::YamlLoader.load_file(CONFIG_PATH)
    end

    # Get help info for a field
    # @param field [FieldDefinition, String] The field definition or field name/key
    # @param field_type [String, Symbol, nil] The field type (if first param is a string)
    # @return [Hash] Help info (example, format_hint, help_text, faq_anchor, help_url)
    def help_for(field, field_type: nil)
      key = field.is_a?(String) ? field : field.name
      type = field.is_a?(String) ? field_type&.to_s : field.field_type

      # Start with type defaults
      info = @config.dig(:field_types, type&.to_sym) || {}

      # Merge key-specific overrides
      key_info = @config.dig(:field_keys, key&.to_sym) || {}
      info.merge(key_info)
    end

    # Get user-friendly error message for a technical validation error
    # @param technical_message [String] The technical error message
    # @return [String] A friendly error message
    def friendly_error(technical_message)
      @config.dig(:error_messages, technical_message.to_sym) || technical_message
    end

    # Get common mistakes and retry suggestions for a field or type
    # @param key_or_type [String, Symbol] The field name or type
    # @return [Array<Hash>] List of { mistake: "...", suggestion: "..." }
    def retry_suggestions(key_or_type)
      @config.dig(:common_mistakes, key_or_type&.to_sym) || []
    end

    # Get FAQ anchor for a field
    # @param field_key [String, Symbol] The field name/key
    # @return [String, nil] The FAQ anchor
    def faq_anchor(field_key)
      @config.dig(:faq_mappings, field_key&.to_sym) || help_for(field_key.to_s)[:faq_anchor]
    end

    # Get the entire config (for passing to JS)
    def config
      @config
    end

    class << self
      delegate :help_for, :friendly_error, :retry_suggestions, :faq_anchor, :config, to: :instance
    end
  end
end
