# frozen_string_literal: true

# PDF Preview Component
# Renders a live PDF preview panel with auto-refresh capability
#
# Usage:
#   <%= render PdfPreviewComponent.new(form_definition: @form_definition) %>
#
class PdfPreviewComponent < ViewComponent::Base
  attr_reader :form_definition, :auto_refresh, :debounce_delay, :variant

  # @param form_definition [FormDefinition] The form to preview
  # @param auto_refresh [Boolean] Enable auto-refresh on form changes (default: true)
  # @param debounce_delay [Float] Debounce delay in seconds (default: 0.3)
  # @param variant [String] Unique identifier when multiple instances on same page (default: "desktop")
  def initialize(form_definition:, auto_refresh: true, debounce_delay: 0.3, variant: "desktop")
    @form_definition = form_definition
    @auto_refresh = auto_refresh
    @debounce_delay = debounce_delay
    @variant = variant
  end

  def preview_url
    helpers.preview_form_path(form_definition.code)
  end

  def download_url
    helpers.download_form_path(form_definition.code)
  end

  def form_code
    form_definition.code
  end

  def form_title
    form_definition.title
  end

  private

  def data_attributes
    {
      data_controller: "pdf-preview",
      data_pdf_preview_url_value: preview_url,
      data_pdf_preview_debounce_delay_value: debounce_delay,
      data_pdf_preview_auto_refresh_value: auto_refresh,
      data_pdf_preview_field_mappings_value: form_definition.field_coordinates.to_json,
      data_pdf_preview_xray_mode_value: false
    }
  end
end
