# frozen_string_literal: true

module Autofill
  class SuggestionService
    MAX_PREVIOUS_SUBMISSIONS = 3

    # Maps shared_field_key patterns to user profile fields
    # The key is a regex pattern, value is the profile field symbol
    SHARED_KEY_MAPPINGS = {
      # Name fields
      /name$/i => :full_name,

      # Address fields
      /street|address$/i => :address,
      /city$/i => :city,
      /state$/i => :state,
      /zip|postal/i => :zip_code,

      # Contact fields
      /phone|tel/i => :phone,
      /email$/i => :email,

      # Date fields
      /dob|date_of_birth|birthdate/i => :date_of_birth
    }.freeze

    # Human-readable labels for profile fields
    FIELD_LABELS = {
      full_name: "Your name",
      address: "Your address",
      city: "Your city",
      state: "Your state",
      zip_code: "Your ZIP code",
      phone: "Your phone",
      email: "Your email",
      date_of_birth: "Your date of birth"
    }.freeze

    def initialize(user)
      @user = user
      @profile = user&.profile_for_autofill || {}
    end

    # Returns suggestions for a given shared_field_key
    # @param shared_field_key [String] the field's shared key (e.g., "plaintiff:name")
    # @return [Array<Hash>] array of suggestion hashes with :value, :label, :source keys
    def suggestions_for(shared_field_key)
      return [] if shared_field_key.blank?
      return [] if @user.nil?
      return [] if autofill_disabled?

      suggestions = []

      # 1. Add profile-based suggestion
      profile_field = find_matching_profile_field(shared_field_key)
      suggestions << build_profile_suggestion(profile_field, @profile[profile_field]) if profile_field && @profile[profile_field].present?

      # 2. Add suggestions from previous submissions with same shared_field_key
      previous_values = values_from_previous_submissions(shared_field_key)
      previous_values.each do |value|
        # Avoid duplicates with profile suggestion
        next if suggestions.any? { |s| s[:value] == value }

        suggestions << build_previous_submission_suggestion(shared_field_key, value)
      end

      suggestions.first(5) # Limit total suggestions
    end

    # Check if there are any suggestions available for a field
    def has_suggestions?(shared_field_key)
      suggestions_for(shared_field_key).any?
    end

    # Check if autofill is disabled for this user
    def autofill_disabled?
      return false unless @user.respond_to?(:autofill_enabled)

      @user.autofill_enabled == false
    end

    private

    def find_matching_profile_field(shared_field_key)
      SHARED_KEY_MAPPINGS.each do |pattern, profile_field|
        return profile_field if shared_field_key.to_s.match?(pattern)
      end
      nil
    end

    def build_profile_suggestion(profile_field, value)
      {
        value: format_value(profile_field, value),
        label: FIELD_LABELS[profile_field] || profile_field.to_s.humanize,
        source: "profile"
      }
    end

    def build_previous_submission_suggestion(shared_field_key, value)
      # Extract a human-friendly label from the shared_field_key
      # e.g., "plaintiff:name" -> "Previous: plaintiff name"
      readable_key = shared_field_key.to_s.tr("_:", " ").titleize
      {
        value: value.to_s,
        label: "Previous: #{readable_key}",
        source: "previous_submission"
      }
    end

    def values_from_previous_submissions(shared_field_key)
      return [] unless @user

      # Query submissions that have this shared_field_key populated
      # Look in form_data JSON for matching values
      @user.submissions
           .where.not(form_data: nil)
           .order(updated_at: :desc)
           .limit(MAX_PREVIOUS_SUBMISSIONS * 2) # Fetch more to filter duplicates
           .filter_map { |submission| extract_value_for_key(submission, shared_field_key) }
           .uniq
           .first(MAX_PREVIOUS_SUBMISSIONS)
    end

    def extract_value_for_key(submission, shared_field_key)
      return nil unless submission.form_data.is_a?(Hash)

      # Try direct match first
      value = submission.form_data[shared_field_key.to_s]
      return value if value.present?

      # Try finding a field with matching shared_field_key in the form definition
      return nil unless submission.form_definition

      submission.form_definition.field_definitions.each do |field_def|
        next unless field_def.shared_field_key == shared_field_key.to_s

        field_value = submission.form_data[field_def.name]
        return field_value if field_value.present?
      end

      nil
    end

    def format_value(profile_field, value)
      case profile_field
      when :date_of_birth
        value.respond_to?(:strftime) ? value.strftime("%m/%d/%Y") : value.to_s
      else
        value.to_s
      end
    end
  end
end
