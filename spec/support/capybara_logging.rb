# frozen_string_literal: true

RSpec.configure do |config|
  config.after(:each, type: :system) do |example|
    if example.exception && page.driver.browser.respond_to?(:logs)
      begin
        logs = page.driver.browser.logs.get(:browser)
        if logs.any?
          puts "\n--- BROWSER CONSOLE LOGS ---"
          logs.each do |log|
            # Colorize based on level if possible, or just plain text
            puts "[#{log.level}] #{log.message}"
          end
          puts "----------------------------\n"
        end
      rescue StandardError => e
        puts "Failed to capture browser logs: #{e.message}"
      end
    end
  end
end
