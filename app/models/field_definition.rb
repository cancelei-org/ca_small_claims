# frozen_string_literal: true

class FieldDefinition < ApplicationRecord
  include ConditionalSupport

  belongs_to :form_definition

  validates :name, presence: true, uniqueness: { scope: :form_definition_id }
  validates :pdf_field_name, presence: true
  validates :field_type, presence: true, inclusion: { in: %w[
    text textarea tel email date currency number
    checkbox checkbox_group radio select
    signature repeating_group address hidden readonly
  ] }

  scope :required, -> { where(required: true) }
  scope :in_section, ->(section) { where(section: section) }
  scope :by_position, -> { order(:position) }
  scope :on_page, ->(page) { where(page_number: page) }

  def repeatable?
    repeating_group.present?
  end

  def has_options?
    options.present? && options.any?
  end

  def width_class
    case width
    when "half" then "w-full md:w-1/2"
    when "third" then "w-full md:w-1/3"
    when "quarter" then "w-full md:w-1/4"
    when "two_thirds" then "w-full md:w-2/3"
    else "w-full"
    end
  end

  def input_type
    case field_type
    when "tel" then "tel"
    when "email" then "email"
    when "currency" then "number"
    when "date" then "date"
    else "text"
    end
  end

  def component_name
    "Forms::#{field_type.camelize}FieldComponent"
  end

  # Transforms conditions from YAML format to JS controller format
  # YAML format: { "show_when" => { "field" => "name", "value" => "val" } }
  # JS format: [{ "field" => "name", "operator" => "equals", "value" => "val" }]
  #
  # @return [Array<Hash>] Array of condition objects for the JS controller
  def conditions_for_js
    return [] unless conditions.present?

    result = []

    # Handle show_when condition
    if (show_when = conditions["show_when"] || conditions[:show_when])
      result << normalize_condition(show_when, "equals")
    end

    # Handle hide_when condition (inverts the operator)
    if (hide_when = conditions["hide_when"] || conditions[:hide_when])
      result << normalize_condition(hide_when, "not_equals")
    end

    # Handle array of conditions
    if conditions.is_a?(Array)
      conditions.each do |cond|
        result << normalize_condition(cond, "equals")
      end
    end

    result.compact
  end

  private

  def normalize_condition(condition, default_operator)
    return nil unless condition.is_a?(Hash)

    field = condition["field"] || condition[:field]
    return nil unless field.present?

    {
      "field" => field,
      "operator" => condition["operator"] || condition[:operator] || default_operator,
      "value" => condition["value"] || condition[:value]
    }
  end
end
