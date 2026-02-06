# frozen_string_literal: true

# Provides common form data access methods for models that store form data
# in a JSON/JSONB column named `form_data`.
#
# @example Including in a model
#   class Submission < ApplicationRecord
#     include FormDataAccessor
#   end
#
# @example Usage
#   submission.field_value("plaintiff_name")  # => "John Doe"
#   submission.update_field("plaintiff_name", "Jane Doe")
#   submission.update_fields({ plaintiff_name: "Jane", defendant_name: "Bob" })
#
module FormDataAccessor
  extend ActiveSupport::Concern

  included do
    # Ensure form_data is initialized as an empty hash if nil
    # Only register callback for ActiveRecord models
    after_initialize :initialize_form_data, if: :new_record? if respond_to?(:after_initialize)
  end

  # Retrieves a single field value from form_data
  #
  # @param field_name [String, Symbol] The name of the field
  # @return [Object, nil] The value of the field, or nil if not present
  def field_value(field_name)
    form_data[field_name.to_s]
  end

  # Retrieves the source/metadata for a field
  #
  # @param field_name [String, Symbol] The name of the field
  # @return [Hash] Metadata for the field (source, original_value, etc.)
  def field_metadata(field_name)
    (form_data["_metadata"] || {})[field_name.to_s] || {}
  end

  # Updates a single field value in form_data with optional metadata
  #
  # @param field_name [String, Symbol] The name of the field
  # @param value [Object] The value to set
  # @param metadata [Hash] Optional metadata (source, etc.)
  # @return [Boolean] true if save was successful
  def update_field(field_name, value, metadata = nil)
    self.form_data = form_data.merge(field_name.to_s => value)

    if metadata
      meta = form_data["_metadata"] || {}
      meta[field_name.to_s] = (meta[field_name.to_s] || {}).merge(metadata.stringify_keys)
      self.form_data["_metadata"] = meta
    end

    after_form_data_update if respond_to?(:after_form_data_update, true)
    save
  end

  # Updates multiple field values in form_data
  #
  # @param new_data [Hash] Hash of field names to values
  # @return [Boolean] true if save was successful
  def update_fields(new_data)
    # Filter out metadata from new_data if passed directly
    metadata = new_data.delete("_metadata") || new_data.delete(:_metadata)

    self.form_data = form_data.merge(new_data.stringify_keys)

    if metadata
      meta = form_data["_metadata"] || {}
      self.form_data["_metadata"] = meta.merge(metadata.stringify_keys)
    end

    after_form_data_update if respond_to?(:after_form_data_update, true)
    save
  end

  # Checks if a field has a value (not blank)
  #
  # @param field_name [String, Symbol] The name of the field
  # @return [Boolean] true if the field has a non-blank value
  def field_present?(field_name)
    field_value(field_name).present?
  end

  # Returns all field names that have values
  #
  # @return [Array<String>] Array of field names with values
  def filled_field_names
    form_data.keys.select { |k| form_data[k].present? }
  end

  # Returns the count of filled fields
  #
  # @return [Integer] Number of fields with values
  def filled_field_count
    filled_field_names.count
  end

  private

  def initialize_form_data
    self.form_data ||= {}
  end
end
