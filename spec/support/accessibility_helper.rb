# frozen_string_literal: true

require "axe/rspec"

# Default rules to skip:
# - aria-hidden-focus: false positives in headless browser
# - color-contrast: unreliable in headless browser
# - region: third-party embeds (YouTube, etc.) have internal content we can't control
SKIPPED_ACCESSIBILITY_RULES = %w[aria-hidden-focus color-contrast region].freeze

RSpec.shared_context "accessibility", type: :system do
  def expect_page_to_be_accessible
    expect(page).to be_accessible.skipping(*SKIPPED_ACCESSIBILITY_RULES)
  end

  def expect_element_to_be_accessible(selector)
    expect(find(selector)).to be_accessible.skipping(*SKIPPED_ACCESSIBILITY_RULES)
  end
end

RSpec.configure do |config|
  config.include_context "accessibility", type: :system
end
