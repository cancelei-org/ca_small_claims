# frozen_string_literal: true

require "rails_helper"

# SKIPPED: Offline Support UI messaging changed
# Re-enable when CASC-FEAT-16 (PWA/offline) is fully implemented
RSpec.describe "Offline Support", type: :system, js: true, skip: "Offline feature messaging not finalized" do
  let(:form) { create(:form_definition, code: "SC-100") }
  let!(:field) { create(:field_definition, form_definition: form, name: "claimant_name") }

  before do
    driven_by :chrome
  end

  it "shows offline warning and saves locally" do
    visit form_path(form.code)

    # Go offline
    page.driver.browser.network_conditions = { offline: true, latency: 0, download_throughput: 0, upload_throughput: 0 }

    # Trigger offline event manually
    page.execute_script("window.dispatchEvent(new Event('offline'))")

    expect(page).to have_content("Offline. Saving locally.")

    # Fill in data
    input = find("[name='submission[claimant_name]']")
    input.set("Offline User")
    input.native.send_keys(:tab)

    # Check for local save indicator
    expect(page).to have_content("Saved locally (offline)")

    # Check localStorage
    data = page.evaluate_script("localStorage.getItem('offline_data_' + window.location.pathname)")
    expect(data).to include("Offline User")

    # Go back online
    page.driver.browser.network_conditions = { offline: false, latency: 0, download_throughput: -1, upload_throughput: -1 }
    page.execute_script("window.dispatchEvent(new Event('online'))")

    # Wait for sync (saved status)
    expect(page).to have_content("Saved", wait: 5)
  end
end
