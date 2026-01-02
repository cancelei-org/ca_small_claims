# frozen_string_literal: true

require "rails_helper"

RSpec.describe PdfPreviewComponent, type: :component do
  let(:form_definition) { create(:form_definition, code: "SC-100", title: "Test Form") }

    it "renders the preview panel" do
      render_inline(described_class.new(form_definition: form_definition))

      expect(page).to have_content("Live Preview")
      expect(page).to have_css("canvas")
      expect(page).to have_link("Download")
      expect(page).to have_css("[data-controller='pdf-preview']")
    end

    it "renders with correct form information" do
      render_inline(described_class.new(form_definition: form_definition))

      expect(page).to have_css("[aria-label*='SC-100']")
    end
    it "handles auto_refresh option" do
    render_inline(described_class.new(form_definition: form_definition, auto_refresh: false))
    expect(page).to have_css("[data-pdf-preview-auto-refresh-value='false']")
  end
end
