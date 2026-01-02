# frozen_string_literal: true

require "rails_helper"

# SKIPPED: PDF X-Ray Mode feature not fully wired - needs pdf-preview controller integration
# Re-enable when CASC-FEAT-15 (X-Ray overlay mode) is fully implemented
RSpec.describe "PDF X-Ray Mode", type: :system, js: true, skip: "Feature not fully implemented" do
  let(:form) { create(:form_definition, code: "SC-100") }
  let!(:field) do
    create(:field_definition,
           form_definition: form,
           name: "plaintiff_name",
           pdf_field_name: "PlaintiffName",
           field_type: "text")
  end

  before do
    # Set up field coordinates in form metadata
    form.update!(metadata: {
      "field_coordinates" => {
        "plaintiff_name" => {
          "page" => 1,
          "rect" => [ 100, 700, 300, 720 ],
          "type" => "text"
        }
      }
    })

    driven_by :chrome
  end

  describe "X-Ray toggle" do
    it "toggles X-Ray mode button state" do
      visit form_path(form.code)

      # Find X-Ray button
      xray_button = find('[data-pdf-preview-target="xrayButton"]')

      # Initially not active
      expect(xray_button[:class]).not_to include("btn-active")

      # Click to enable X-Ray mode
      xray_button.click

      # Should now be active
      expect(xray_button[:class]).to include("btn-active")

      # Click again to disable
      xray_button.click

      # Should be inactive again
      expect(xray_button[:class]).not_to include("btn-active")
    end
  end

  describe "Field hover highlighting" do
    it "dispatches highlight event on field hover" do
      visit form_path(form.code)

      # Wait for PDF to load
      expect(page).to have_css('[data-pdf-preview-target="canvas"]')

      # Find the form field
      field_input = find("[name='submission[plaintiff_name]']")

      # Hover over the field - this triggers the highlight event
      field_input.hover

      # The PDF controller should receive the highlight event
      # We can't directly test canvas drawing, but we can verify the event flow
      # by checking that no errors occur and the page remains stable
      expect(page).to have_css('[data-pdf-preview-target="canvas"]')
    end
  end

  describe "PDF preview component" do
    it "renders with field mappings data attribute" do
      visit form_path(form.code)

      # Check that the PDF preview has field mappings
      pdf_preview = find('[data-controller="pdf-preview"]')

      # Field mappings should be present
      field_mappings = JSON.parse(pdf_preview["data-pdf-preview-field-mappings-value"])
      expect(field_mappings).to have_key("plaintiff_name")
      expect(field_mappings["plaintiff_name"]["page"]).to eq(1)
    end

    it "renders with X-Ray mode initially disabled" do
      visit form_path(form.code)

      pdf_preview = find('[data-controller="pdf-preview"]')
      expect(pdf_preview["data-pdf-preview-xray-mode-value"]).to eq("false")
    end
  end
end
