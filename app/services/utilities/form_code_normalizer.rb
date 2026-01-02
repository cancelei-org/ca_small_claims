# frozen_string_literal: true

module Utilities
  # Centralizes form code normalization logic for consistent handling
  # across the application. Converts various input formats to canonical
  # form codes (e.g., "sc100" -> "SC-100", "FL-300A" -> "FL-300A").
  #
  # @example Basic usage
  #   Utilities::FormCodeNormalizer.normalize("sc100")    # => "SC-100"
  #   Utilities::FormCodeNormalizer.normalize("FL-300A")  # => "FL-300A"
  #   Utilities::FormCodeNormalizer.normalize("dv109")    # => "DV-109"
  #
  # @example Extracting from filename
  #   Utilities::FormCodeNormalizer.from_filename("sc100.pdf")  # => "SC-100"
  #   Utilities::FormCodeNormalizer.from_filename("/path/to/fl300a.pdf")  # => "FL-300A"
  #
  class FormCodeNormalizer
    # Normalizes a form code to the canonical format: PREFIX-NUMBER[SUFFIX]
    # Examples: SC-100, FL-300A, DV-109
    #
    # @param code [String, nil] The raw form code to normalize
    # @return [String] The normalized form code
    def self.normalize(code)
      return "" if code.blank?

      code = code.to_s.strip

      # Already has hyphen - just upcase and clean
      return code.upcase.gsub(/[^A-Z0-9-]/, "") if code.include?("-")

      # Remove any non-alphanumeric characters and extract components
      clean_code = code.gsub(/[^A-Za-z0-9]/, "")

      # Match pattern: letters + numbers + optional letters (e.g., sc100, fl300a)
      match = clean_code.match(/^([A-Za-z]+)(\d+)([A-Za-z]*)$/i)
      return code.upcase unless match

      prefix = match[1].upcase
      number = match[2]
      suffix = match[3].upcase

      "#{prefix}-#{number}#{suffix}"
    end

    # Extracts and normalizes a form code from a filename
    #
    # @param filename [String] The filename (with or without path)
    # @return [String] The normalized form code
    def self.from_filename(filename)
      return "" if filename.blank?

      basename = File.basename(filename.to_s, ".*")
      normalize(basename)
    end

    # Converts a normalized form code to a filename-safe format
    # (lowercase, no hyphens)
    #
    # @param code [String] The form code
    # @return [String] The filename-safe version (e.g., "sc100")
    def self.to_filename(code)
      normalize(code).downcase.delete("-")
    end

    # Extracts just the prefix portion of a form code
    #
    # @param code [String] The form code
    # @return [String, nil] The prefix (e.g., "SC" from "SC-100")
    def self.extract_prefix(code)
      return nil if code.blank?

      normalized = normalize(code)
      match = normalized.match(/^([A-Z]+)/)
      match&.[](1)
    end

    # Extracts just the numeric portion of a form code
    #
    # @param code [String] The form code
    # @return [Integer] The number portion (e.g., 100 from "SC-100")
    def self.extract_number(code)
      normalized = normalize(code)
      match = normalized.match(/(\d+)/)
      match ? match[1].to_i : 0
    end

    # Instance method for convenience when used as a dependency
    delegate :normalize, to: :class

    delegate :from_filename, to: :class

    delegate :to_filename, to: :class

    delegate :extract_prefix, to: :class

    delegate :extract_number, to: :class
  end
end
