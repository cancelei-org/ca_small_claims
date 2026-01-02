# frozen_string_literal: true

module Autofill
  class SuggestionService
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
      return [] if shared_field_key.blank? || @profile.empty?

      suggestions = []

      # Find matching profile field based on shared_key pattern
      profile_field = find_matching_profile_field(shared_field_key)

      suggestions << build_suggestion(profile_field, @profile[profile_field]) if profile_field && @profile[profile_field].present?

      suggestions
    end

    # Check if there are any suggestions available for a field
    def has_suggestions?(shared_field_key)
      suggestions_for(shared_field_key).any?
    end

    private

    def find_matching_profile_field(shared_field_key)
      SHARED_KEY_MAPPINGS.each do |pattern, profile_field|
        return profile_field if shared_field_key.to_s.match?(pattern)
      end
      nil
    end

    def build_suggestion(profile_field, value)
      {
        value: format_value(profile_field, value),
        label: FIELD_LABELS[profile_field] || profile_field.to_s.humanize,
        source: "profile"
      }
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
