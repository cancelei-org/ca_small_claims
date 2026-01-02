# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Language Switching", type: :system, js: true do
  before do
    driven_by :chrome
  end

  it "switches to Spanish and back to English" do
    visit root_path

    # Defaults to English
    expect(page).to have_content("California Small Claims Court Forms")

    # Open language switcher
    find("[aria-label='Change language']").click
    click_on "Español"

    # Should be in Spanish
    expect(page).to have_content("Formularios de la Corte de Reclamos Menores de California")
    expect(page).to have_current_path(/locale=es/)

    # Switch back to English
    find("[aria-label='Change language']").click
    click_on "English"

    expect(page).to have_content("California Small Claims Court Forms")
  end

  # SKIPPED: Session persistence needs i18n routing work
  # Re-enable when CASML-FEAT-14 (i18n) session persistence is complete
  it "persists language choice in session", skip: "i18n session persistence not fully implemented" do
    visit root_path(locale: :es)
    expect(page).to have_content("Formularios de la Corte")

    # Navigate to forms using a link that doesn't explicitly have the locale param
    # (Since default_url_options is removed, this tests session persistence)
    click_on "Guías" # workflows in Spanish
    expect(page).to have_content("Guías Paso a Paso")
    # Path should not have locale but content should be Spanish
    expect(page).to have_current_path(workflows_path)
  end
end
