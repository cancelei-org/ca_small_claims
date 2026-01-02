# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Smart Autofill", type: :system, js: true do
  let(:form) { create(:form_definition, code: "SC-100") }
  let!(:field) { create(:field_definition, form_definition: form, name: "full_name", shared_field_key: "full_name") }
  let(:user) { create(:user, full_name: "Alice Magic") }

  before do
    driven_by :chrome
    login_as(user, scope: :user)
  end

  it "shows magic fill button and fills field via dropdown" do
    visit form_path(form.code)

    # Check for magic wand button
    expect(page).to have_content("Magic Fill")

    # Click to open dropdown
    click_on "Magic Fill"

    # Wait for dropdown to appear and click the suggestion
    within(".autofill-dropdown") do
      expect(page).to have_content("From your profile")
      expect(page).to have_content("Alice Magic")
      find(".autofill-option", text: "Alice Magic").click
    end

    # Check if field is filled
    expect(find("[name='submission[full_name]']").value).to eq("Alice Magic")

    # Check for toast
    expect(page).to have_content("Magic fill applied!")
  end
end
