# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Command Bar", type: :system, js: true do
  before do
    driven_by :chrome
    visit root_path
  end

  it "opens with Cmd+K shortcut" do
    # Simulate Cmd+K
    page.driver.browser.action.key_down(:control).send_keys('k').key_up(:control).perform

    expect(page).to have_selector(:modal, "Command Bar")
    expect(page).to have_field(placeholder: t("command_bar.placeholder"))
  end

  it "opens with mobile FAB" do
    # Resize to mobile to see FAB
    page.driver.browser.manage.window.resize_to(375, 812)

    # Wait for FAB to be visible
    expect(page).to have_css("[aria-label='Quick Actions']", visible: true)

    find("[aria-label='Quick Actions']").click

    expect(page).to have_selector(:modal, "Command Bar")
  end

  it "navigates to forms page" do
    page.driver.browser.action.key_down(:control).send_keys('k').key_up(:control).perform

    # Wait for dialog and click
    within_modal "Command Bar" do
      click_on t("command_bar.browse_forms")
    end

    expect(page).to have_current_path(forms_path)
  end

  it "filters results" do
    page.driver.browser.action.key_down(:control).send_keys('k').key_up(:control).perform

    fill_in "Type a command or search...", with: "Theme"

    expect(page).to have_content("Switch Theme")
    expect(page).not_to have_content("Go to Home")
  end
end
