# Testing Guide

**Last Updated**: January 6, 2026
**Document Type**: Guide
**Audience**: All developers

---

## Overview

This project uses RSpec for Ruby testing and Jest for JavaScript testing.

### Current Test Statistics

| Metric | Value |
|--------|-------|
| Total RSpec Examples | 1,241 |
| Test Coverage | 65.04% |
| System Tests | 38 |
| Model Tests | 250+ |
| Request/Controller Tests | 150+ |
| Service Tests | 100+ |

### CI/CD Integration

Tests run automatically on:
- Pull requests to any branch
- Pushes to `main` branch

CI pipeline includes:
- Security scanning (Brakeman, bundler-audit)
- Code linting (RuboCop)
- RSpec tests with coverage reporting
- Playwright E2E tests (Mobile Chrome & Safari)

### Test Types

| Type | Directory | Purpose |
|------|-----------|---------|
| Model | `spec/models/` | Unit tests for models |
| Request | `spec/requests/` | Controller/API tests |
| System | `spec/system/` | End-to-end browser tests |
| Component | `spec/components/` | ViewComponent tests |
| Service | `spec/services/` | Service object tests |
| Policy | `spec/policies/` | Authorization tests |
| JavaScript | `spec/javascript/` | Stimulus controller tests |
| E2E | `tests/` | Playwright E2E tests |

---

## Running Tests

### RSpec (Ruby)

```bash
# Run all tests
bundle exec rspec

# Run specific file
bundle exec rspec spec/models/user_spec.rb

# Run specific line
bundle exec rspec spec/models/user_spec.rb:10

# Run by tag
bundle exec rspec --tag focus

# Run with coverage
COVERAGE=true bundle exec rspec

# Run failed tests only
bundle exec rspec --only-failures
```

### Jest (JavaScript)

```bash
# Run all tests
npm test

# Watch mode
npm run watch-tests

# Run specific file
npm test -- spec/javascript/controllers/form_controller.spec.js
```

### Playwright (E2E)

```bash
# Run all E2E tests
npm run test:e2e

# Run with UI
npm run test:e2e:ui

# Debug mode
npm run test:e2e:debug
```

---

## Test Structure

### RSpec Example

```ruby
require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
  end

  describe "#full_name" do
    let(:user) { build(:user, first_name: "John", last_name: "Doe") }

    it "returns combined name" do
      expect(user.full_name).to eq("John Doe")
    end
  end
end
```

### Jest Example

```javascript
import { Application } from '@hotwired/stimulus';
import FormController from 'controllers/form_controller';

describe('FormController', () => {
  let application;

  beforeEach(() => {
    application = Application.start();
    application.register('form', FormController);
  });

  it('validates required fields', () => {
    document.body.innerHTML = `
      <form data-controller="form">
        <input data-form-target="field" required>
      </form>
    `;
    // assertions...
  });
});
```

---

## Factories

Use FactoryBot for test data:

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    email { Faker::Internet.email }
    password { "password123" }

    trait :admin do
      role { :admin }
    end
  end
end

# Usage in specs
let(:user) { create(:user) }
let(:admin) { create(:user, :admin) }
```

---

## Test Helpers

### Authentication

```ruby
# In request specs
sign_in(user)

# In system specs
login_as(user)
```

### Time Manipulation

```ruby
# Freeze time
freeze_time do
  expect(Time.current).to eq(Time.current)
end

# Travel to specific time
travel_to(1.week.ago) do
  # code here
end
```

### HTTP Mocking

```ruby
# Using VCR
VCR.use_cassette("api_call") do
  response = ExternalApi.fetch_data
end

# Using WebMock
stub_request(:get, "https://api.example.com/data")
  .to_return(body: { result: "success" }.to_json)
```

---

## Coverage

SimpleCov generates coverage reports:

```bash
# Run with coverage
COVERAGE=true bundle exec rspec

# View report
open coverage/index.html
```

### Coverage Thresholds

**Primary Code (Controllers, Models, Services)**
- Target: 90%+ coverage
- Current: Focus areas for improvement

**Secondary Code (Helpers, Components, Policies)**
- Target: 80%+ coverage

**Per-file Minimum**: 50%

### Running Coverage Report

```bash
# Generate detailed coverage report
COVERAGE=true bundle exec rspec

# Open HTML report in browser
open coverage/index.html

# Check coverage summary
cat coverage/.last_run.json
```

---

## Best Practices

1. **One assertion per test** (when practical)
2. **Use descriptive test names**
3. **Follow Arrange-Act-Assert pattern**
4. **Use factories over fixtures**
5. **Mock external services**
6. **Keep tests fast and isolated**
