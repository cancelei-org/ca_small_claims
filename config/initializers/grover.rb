# frozen_string_literal: true

Grover.configure do |config|
  config.options = {
    format: "Letter",
    margin: {
      top: "0.5in",
      bottom: "0.5in",
      left: "0.75in",
      right: "0.75in"
    },
    print_background: true,
    prefer_css_page_size: true,
    display_url: false,
    emulate_media: "print",
    wait_until: "networkidle0",
    # Chrome launch args for headless mode
    launch_args: [ "--no-sandbox", "--disable-setuid-sandbox" ],
    # Use system Chrome/Chromium instead of puppeteer's bundled version
    executable_path: ENV.fetch("CHROMIUM_PATH") { "/usr/bin/google-chrome" }
  }
end
