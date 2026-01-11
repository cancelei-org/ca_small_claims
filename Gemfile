source "https://rubygems.org"

ruby File.read(".ruby-version").strip

# Core Rails
gem "bootsnap", require: false
gem "dotenv-rails", require: "dotenv/load"
gem "foreman"
gem "pg"
gem "puma"
gem "rails", "~> 8.1.1"
gem "sqlite3", "~> 2.0"  # For development/test
gem "thruster"

# Health checks and monitoring
gem "okcomputer"
gem "propshaft"
gem "sentry-rails"
gem "sentry-ruby"

# Security and rate limiting
gem "rack-attack"
gem "rack-canonical-host"

# Tailwind CSS for Rails
gem "tailwindcss-rails"

# Hotwire's SPA-like page accelerator
gem "turbo-rails"

# Hotwire's modest JavaScript framework
gem "stimulus-rails"

# TurboBoost Commands for reactive server-side commands
gem "turbo_boost-commands", "~> 0.3"

# Use JavaScript with ESM import maps
gem "importmap-rails"

# Use Active Storage variants
gem "image_processing", "~> 1.2"

# Protect against accidentally slow migrations
gem "strong_migrations"

# PDF Processing (specific to ca_small_claims)
gem "pdf-forms", "~> 1.5"          # Fill PDF forms with pdftk
gem "combine_pdf", "~> 1.0"        # Merge/manipulate PDFs
gem "hexapdf", "~> 1.0"            # PDF parsing (for XFA forms)
gem "grover", "~> 1.1"             # HTML to PDF via Chrome/Puppeteer (for non-fillable forms)
gem "aws-sdk-s3", "~> 1.143"       # S3 storage for PDF templates

# Authentication
gem "devise", "~> 4.9"

# Authorization
gem "pundit"

# UI Components
gem "view_component"
gem "simple_form", "~> 5.3"
gem "pagy", "~> 43.2"

# Background jobs with database-backed queue
gem "mission_control-jobs"
gem "solid_queue"

# Database-backed ActionCable adapter
gem "solid_cable"

# Database-backed cache
gem "solid_cache"

# FriendlyId for human-readable URLs
gem "friendly_id", "~> 5.5"

# Ransack for object-based searching
gem "ransack"

# HTTP requests
gem "httparty"

# JWT for secure token generation
gem "jwt"

# Windows does not include zoneinfo files
gem "tzinfo-data", platforms: %i[windows jruby]

# Deploy this application anywhere as a Docker container
gem "kamal", require: false

group :development do
  # Code annotation
  gem "annotaterb", require: false
  gem "chusaku", require: false

  gem "letter_opener"

  # Use console on exceptions pages
  gem "web-console"

  # Security and code quality
  gem "brakeman", require: false
  gem "overcommit", require: false
  gem "rubocop", require: false
  gem "rubocop-capybara", require: false
  gem "rubocop-factory_bot", require: false
  gem "rubocop-performance", require: false
  gem "rubocop-rails", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-rspec_rails", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development, :test do
  gem "bullet"
  gem "factory_bot_rails"
  gem "faker"
  gem "pry-byebug"
  gem "pry-rails"
  gem "rspec-rails", "~> 7.0"

  # ERB linting
  gem "erb_lint", require: false

  # Security auditing
  gem "bundler-audit", require: false

  gem "debug", platforms: %i[mri windows], require: "debug/prelude"
end

group :test do
  # Use system testing
  gem "capybara"
  gem "selenium-webdriver"

  gem "axe-matchers"
  gem "lighthouse-matchers"
  gem "rails-controller-testing"
  gem "simplecov", require: false
  gem "simplecov-lcov", require: false

  # HTTP mocking and testing
  gem "vcr"
  gem "webmock"

  # Time manipulation for time-based tests
  gem "timecop"

  # Cleaner test matchers
  gem "shoulda-matchers"

  # Pundit policy matchers
  gem "pundit-matchers"

  # PDF content verification
  gem "pdf-reader"
end
