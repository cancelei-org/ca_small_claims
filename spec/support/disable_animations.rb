# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:each, type: :system) do
    # Disable animations/transitions for faster, more stable tests
    disable_animations_css = <<~CSS
      *, *::before, *::after {
        transition: none !important;
        animation: none !important;
      }
    CSS

    # Inject style tag into the page
    page.driver.browser.execute_cdp(
      "Page.addScriptToEvaluateOnNewDocument",
      source: "const style = document.createElement('style');
               style.type = 'text/css';
               style.innerHTML = `#{disable_animations_css}`;
               document.head.appendChild(style);"
    ) if page.driver.browser.respond_to?(:execute_cdp)
  end
end
