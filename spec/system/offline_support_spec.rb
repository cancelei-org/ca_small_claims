# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Offline Support", type: :system, js: true do
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

    # Check IndexedDB for saved data (uses ca_small_claims_offline database, form_submissions store)
    # Wait for async IndexedDB save to complete
    sleep 0.5

    # Read from IndexedDB using a promise-based approach
    data = page.evaluate_async_script(<<~JS)
      var callback = arguments[arguments.length - 1];
      var request = indexedDB.open('ca_small_claims_offline', 1);
      request.onsuccess = function(event) {
        var db = event.target.result;
        var transaction = db.transaction(['form_submissions'], 'readonly');
        var store = transaction.objectStore('form_submissions');
        var getRequest = store.get(window.location.pathname);
        getRequest.onsuccess = function() {
          callback(JSON.stringify(getRequest.result));
        };
        getRequest.onerror = function() {
          callback(null);
        };
      };
      request.onerror = function() {
        callback(null);
      };
    JS

    expect(data).to include("Offline User")

    # Go back online
    page.driver.browser.network_conditions = { offline: false, latency: 0, download_throughput: -1, upload_throughput: -1 }
    page.execute_script("window.dispatchEvent(new Event('online'))")

    # Wait for sync (saved status)
    expect(page).to have_content("Saved", wait: 5)
  end
end
