# frozen_string_literal: true

require "axe/rspec"

RSpec.shared_context "accessibility", type: :system do
  def expect_page_to_be_accessible
    # Skip checking hidden elements and color-contrast (false positives in headless)
    expect(page).to be_accessible.skipping("aria-hidden-focus", "color-contrast")
  end

  def expect_element_to_be_accessible(selector)
    expect(find(selector)).to be_accessible
  end
end

RSpec.configure do |config|
  config.include_context "accessibility", type: :system
end
