# This file is copied to spec/ when you run 'rails generate rspec:install'
require "spec_helper"
ENV["RAILS_ENV"] ||= "test"
ENV["HTTP_BASIC_AUTH_USERNAME"] = nil
ENV["HTTP_BASIC_AUTH_PASSWORD"] = nil
require_relative "../config/environment"
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "rspec/rails"
require "capybara/rspec"
require "selenium-webdriver"
require "pundit/rspec"
require "pundit/matchers"

# Add additional requires below this line. Rails is not loaded until this point!

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories.
Rails.root.glob("spec/support/**/*.rb").each { |f| require f }

# Checks for pending migrations and applies them before tests are run.
begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

Capybara.register_driver :chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new

  # Point to chromium binary
  options.binary = "/usr/bin/chromium-browser" if File.exist?("/usr/bin/chromium-browser")

  options.add_argument("--window-size=1920,1080")

  # Headless mode
  options.add_argument("--headless=new") unless ENV["HEADFUL"]

  # Docker compatibility
  options.add_argument("--no-sandbox")
  options.add_argument("--disable-dev-shm-usage")

  # Enable browser logs
  options.add_option("goog:loggingPrefs", { browser: "ALL" })

  Capybara::Selenium::Driver.new app, browser: :chrome, options:
end

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_paths = [ Rails.root.join("spec/fixtures") ]

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # Allow exceptions to be raised in request specs for authorization testing
  config.around(:each, :raise_exceptions) do |example|
    original_value = Rails.application.env_config["action_dispatch.show_exceptions"]
    Rails.application.env_config["action_dispatch.show_exceptions"] = :none
    example.run
    Rails.application.env_config["action_dispatch.show_exceptions"] = original_value
  end

  # Run system tests in rack_test by default
  config.before(:each, type: :system) do |example|
    unless example.metadata[:uses_javascript] ||
           example.metadata[:viewport_mobile] ||
           example.metadata[:viewport_tablet] ||
           example.metadata[:viewport_desktop]
      driven_by :rack_test
    end
  end

  # System tests indicating that they use Javascript should be run with headless Chrome
  config.before(:each, :uses_javascript, type: :system) do
    driven_by :chrome
  end

  # Infer spec type from file location
  config.infer_spec_type_from_file_location!

  # Filter lines from Rails gems in backtraces.
  config.filter_rails_from_backtrace!

  Capybara.default_max_wait_time = 5

  config.include ActiveSupport::Testing::TimeHelpers
  config.include ActionView::RecordIdentifier, type: :system
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::ControllerHelpers, type: :helper
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :system
  config.include AbstractController::Translation
end
