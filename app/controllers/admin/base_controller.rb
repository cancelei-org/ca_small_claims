# frozen_string_literal: true

module Admin
  class BaseController < ApplicationController
    include Admin::AuditLoggable
    before_action :authenticate_user!
    before_action :authorize_admin!

    layout "admin"

    private

    def authorize_admin!
      raise Pundit::NotAuthorizedError unless AdminPolicy.new(current_user, nil).access?
    end

    # Safely parse date string, returning nil for invalid formats
    # Prevents ArgumentError from malformed date inputs
    # @param date_string [String] The date string to parse
    # @return [Date, nil] Parsed date or nil if invalid
    def safe_parse_date(date_string)
      return nil if date_string.blank?

      Date.parse(date_string)
    rescue ArgumentError, TypeError
      nil
    end

    # Sanitize admin notes to prevent log injection and enforce limits
    # @param notes [String] Raw notes from params
    # @param max_length [Integer] Maximum allowed length
    # @return [String, nil] Sanitized notes
    def sanitize_admin_notes(notes, max_length: 2000)
      return nil if notes.blank?

      # Truncate to max length
      sanitized = notes.to_s.truncate(max_length)
      # Remove control characters that could be used for log injection
      sanitized = sanitized.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")
      # Strip leading/trailing whitespace
      sanitized.strip.presence
    end

    # Validate and extract integer IDs from bulk action params
    # Prevents injection of non-integer values
    # @param ids_param [Array, String, nil] The ids parameter from params
    # @return [Array<Integer>] Array of valid integer IDs
    def validate_bulk_ids(ids_param)
      return [] if ids_param.blank?

      # Handle both array and comma-separated string
      ids = ids_param.is_a?(Array) ? ids_param : ids_param.to_s.split(",")

      # Convert to integers, rejecting non-numeric values
      ids.map do |id|
        Integer(id, 10)
      rescue ArgumentError, TypeError
        nil
      end.compact.uniq
    end
  end
end
