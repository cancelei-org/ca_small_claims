# Development Guide

Welcome to the California Small Claims Court Forms project! This guide will help you set up your development environment and start contributing.

## Environment Setup

### Option 1: Using mise (Recommended)

This project uses [mise](https://mise.jdx.dev/) for environment management.

1. **Install mise:**
   ```bash
   # Arch Linux
   pacman -S mise

   # macOS
   brew install mise

   # Other
   curl https://mise.run | sh
   ```

2. **Enable mise in your shell:**
   ```bash
   # Add to ~/.zshrc or ~/.bashrc
   eval "$(mise activate zsh)"  # or bash
   ```

3. **Install tools and dependencies:**
   ```bash
   cd ca-small-claims
   mise install
   mise run setup
   ```

4. **Start development:**
   ```bash
   mise run dev
   ```

### Option 2: Manual Setup

**Prerequisites:**
- Ruby 3.4+ (`rbenv` or `asdf` recommended)
- Node.js 20+
- PostgreSQL 14+ (or SQLite for simple local dev)
- pdftk-java (`sudo apt install pdftk-java` or `brew install pdftk-java`)

```bash
# Install Ruby dependencies
bundle install

# Install JavaScript dependencies
npm install

# Set up database
cp example.env .env
bin/rails db:setup

# Start development server
bin/dev
```

## Common Tasks

| Task | Command |
|------|---------|
| Start dev server | `bin/dev` or `mise run dev` |
| Run all tests | `bin/rails spec` |
| Run specific test | `bin/rails spec spec/models/user_spec.rb` |
| JavaScript tests | `npm test` |
| E2E tests | `npm run test:e2e` |
| Ruby linting | `bin/rubocop -a` |
| JS linting | `npm run js-lint-fix` |
| Rails console | `bin/rails console` |
| Database reset | `bin/rails db:reset` |

## Project Architecture

```
app/
├── controllers/
│   ├── forms_controller.rb       # Form display and submission
│   ├── workflows_controller.rb   # Multi-step workflows
│   └── admin/                    # Admin panel controllers
├── javascript/
│   ├── controllers/              # Stimulus controllers
│   └── utils/                    # Shared utilities
├── models/
│   ├── form_definition.rb        # Form metadata
│   ├── submission.rb             # User form data
│   └── workflow.rb               # Workflow definitions
├── services/
│   ├── pdf/                      # PDF generation
│   ├── autofill/                 # Smart suggestions
│   └── forms/                    # Form import/export
└── views/
    ├── forms/                    # Form templates
    └── workflows/                # Workflow templates

config/
├── form_schemas/                 # YAML form definitions
└── workflows/                    # YAML workflow definitions
```

## Adding a New Form

1. **Create the YAML schema:**
   ```bash
   # config/form_schemas/small_claims/plaintiff/sc-999.yml
   ```

   ```yaml
   form:
     code: SC-999
     title: "Example Form Title"
     category: plaintiff
     pdf_filename: sc999.pdf
     fillable: true

   sections:
     plaintiff_info:
       title: "Plaintiff Information"
       fields:
         - name: plaintiff_name
           pdf_field_name: "TextField1"
           type: text
           label: "Your Name"
           required: true
           shared_field_key: plaintiff_name  # Enables data sharing
   ```

2. **Add the PDF template:**
   ```bash
   cp your-form.pdf db/seeds/pdf_templates/sc999.pdf
   ```

3. **Import the form:**
   ```bash
   bin/rails forms:import
   ```

4. **Extract PDF field names (if needed):**
   ```bash
   bin/rails forms:extract_fields[SC-999]
   ```

## Testing Guidelines

### Running Tests

```bash
# All Ruby tests
bin/rails spec

# Specific category
bin/rails spec spec/models/
bin/rails spec spec/requests/
bin/rails spec spec/system/

# Single file
bin/rails spec spec/models/user_spec.rb

# JavaScript unit tests
npm test

# E2E with Playwright
npm run test:e2e

# E2E with browser visible
npm run test:e2e:ui
```

### Writing Tests

- **Model specs**: Test validations, scopes, and methods
- **Request specs**: Test controller actions and responses
- **System specs**: Test full user flows with browser
- **Service specs**: Test business logic in isolation

Example request spec:
```ruby
RSpec.describe "Forms", type: :request do
  let(:form) { create(:form_definition, code: "SC-100") }

  describe "GET /forms/:code" do
    it "displays the form" do
      get form_path(form.code)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(form.title)
    end
  end
end
```

## Code Style

### Ruby
- Follow [Ruby Style Guide](https://rubystyle.guide/)
- Run `bin/rubocop -a` before committing
- Use service objects for complex business logic
- Keep controllers thin

### JavaScript
- Use ES6+ features
- Follow Stimulus conventions for controllers
- Run `npm run js-lint-fix` before committing
- Prefer `data-action` over inline event handlers

### CSS
- Use Tailwind utility classes
- Use DaisyUI components where appropriate
- Avoid custom CSS unless necessary

## Git Workflow

1. **Create a feature branch:**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes and commit:**
   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   ```

3. **Run tests and linting:**
   ```bash
   bin/rails spec && bin/rubocop && npm run js-lint
   ```

4. **Push and create a PR:**
   ```bash
   git push origin feature/your-feature-name
   ```

### Commit Message Format

Use conventional commits:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `refactor:` Code refactoring
- `test:` Adding tests
- `chore:` Maintenance

## Debugging

### Rails Console
```bash
bin/rails console
```

```ruby
# Find a form
form = FormDefinition.find_by(code: "SC-100")

# Check submission data
submission = Submission.last
submission.form_data

# Test PDF generation
Pdf::FormFiller.new(form, submission.form_data).generate
```

### Browser DevTools

Stimulus controllers expose their state:
```javascript
// In browser console
const wizard = document.querySelector('[data-controller="wizard"]')
const controller = Stimulus.getControllerForElementAndIdentifier(wizard, 'wizard')
controller.currentStepValue  // Current step index
```

### Logs

```bash
# Development logs
tail -f log/development.log

# Test logs
tail -f log/test.log

# Filter for specific controller
grep FormsController log/development.log
```

## Helpful Resources

- [CLAUDE.md](CLAUDE.md) - Detailed architecture documentation
- [Rails Guides](https://guides.rubyonrails.org/)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)
- [Tailwind CSS](https://tailwindcss.com/docs)
- [DaisyUI Components](https://daisyui.com/components/)

## Getting Help

- Check existing issues on GitHub
- Ask questions in discussions
- Review CLAUDE.md for architecture details
