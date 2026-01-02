# frozen_string_literal: true

module Utilities
  # Centralizes pdftk executable resolution and availability checking.
  # Used by PDF processing services to locate the pdftk binary.
  #
  # @example Basic usage
  #   Utilities::PdftkResolver.available?  # => true
  #   Utilities::PdftkResolver.path        # => "/usr/bin/pdftk"
  #
  # @example With environment override
  #   ENV["PDFTK_PATH"] = "/custom/path/pdftk"
  #   Utilities::PdftkResolver.path  # => "/custom/path/pdftk"
  #
  class PdftkResolver
    # Common installation paths for pdftk, in order of preference
    SEARCH_PATHS = %w[
      /usr/bin/pdftk
      /usr/local/bin/pdftk
      /snap/bin/pdftk
      /usr/bin/pdftk-java
      /usr/bin/pdftk.pdftk-java
      /usr/local/bin/pdftk-java
    ].freeze

    class << self
      # Returns the path to the pdftk executable
      #
      # @return [String] Path to pdftk, or "pdftk" if not found (relies on PATH)
      def path
        @path ||= resolve_path
      end

      # Checks if pdftk is available on the system
      #
      # @return [Boolean] true if pdftk is available and executable
      def available?
        @available ||= check_availability
      end

      # Clears the cached path and availability (useful for testing)
      def reset!
        @path = nil
        @available = nil
      end

      # Returns detailed information about pdftk availability
      #
      # @return [Hash] Information about pdftk status
      def info
        {
          available: available?,
          path: path,
          version: available? ? version : nil,
          source: path_source
        }
      end

      # Returns the pdftk version string if available
      #
      # @return [String, nil] Version string or nil if not available
      def version
        return nil unless available?

        output = `#{path} --version 2>&1`.strip
        match = output.match(/pdftk\s+([\d.]+)/i)
        match ? match[1] : output.lines.first&.strip
      rescue StandardError
        nil
      end

      private

      def resolve_path
        # First, check for environment override
        env_path = ENV.fetch("PDFTK_PATH", nil)
        return env_path if env_path.present? && executable?(env_path)

        # Search common installation paths
        found_path = SEARCH_PATHS.find { |p| executable?(p) }
        return found_path if found_path

        # Fall back to which command
        which_path = `which pdftk 2>/dev/null`.strip.presence
        return which_path if which_path && executable?(which_path)

        # Try pdftk-java as alternative
        which_java_path = `which pdftk-java 2>/dev/null`.strip.presence
        return which_java_path if which_java_path && executable?(which_java_path)

        # Last resort: return "pdftk" and rely on PATH
        "pdftk"
      end

      def check_availability
        # Try the resolved path
        return true if executable?(path) && path != "pdftk"

        # Check if pdftk is in PATH
        system("which pdftk > /dev/null 2>&1") ||
          system("which pdftk-java > /dev/null 2>&1")
      end

      def executable?(path)
        return false if path.blank?

        File.exist?(path) && File.executable?(path)
      end

      def path_source
        env_path = ENV.fetch("PDFTK_PATH", nil)
        return :environment if env_path.present? && executable?(env_path)

        found_path = SEARCH_PATHS.find { |p| executable?(p) }
        return :search_path if found_path

        which_result = `which pdftk 2>/dev/null`.strip.presence
        return :which if which_result && executable?(which_result)

        :fallback
      end
    end

    # Instance methods for dependency injection patterns

    delegate :path, to: :class

    delegate :available?, to: :class

    delegate :info, to: :class

    delegate :version, to: :class
  end
end
