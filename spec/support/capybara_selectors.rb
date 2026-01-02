# frozen_string_literal: true

Capybara.add_selector(:modal) do
  label "DaisyUI Modal"
  xpath do |name|
    XPath.descendant(:dialog)[XPath.attr(:class).contains("modal")][XPath.descendant(:h3)[XPath.string.contains(name)]]
  end
end

Capybara.add_selector(:alert) do
  label "DaisyUI Alert"
  xpath do |type|
    # type can be success, error, warning, info
    clazz = type ? "alert-#{type}" : "alert"
    XPath.descendant(:div)[XPath.attr(:class).contains(clazz)]
  end
end

Capybara.add_selector(:toast) do
  label "DaisyUI Toast"
  xpath do |text|
    XPath.descendant(:div)[XPath.attr(:class).contains("toast")][XPath.string.contains(text)]
  end
end

Capybara.add_selector(:badge) do
  label "DaisyUI Badge"
  xpath do |text|
    XPath.descendant(:span)[XPath.attr(:class).contains("badge")][XPath.string.contains(text)]
  end
end

module CapybaraDslHelpers
  def within_modal(name, &block)
    within(:modal, name, &block)
  end

  def within_alert(type = nil, &block)
    within(:alert, type, &block)
  end
end

RSpec.configure do |config|
  config.include CapybaraDslHelpers, type: :system
end
