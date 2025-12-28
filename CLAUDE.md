# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

California Small Claims Court Forms - a Rails 8.1 application that provides guided, interactive form-filling for California Small Claims Court forms with PDF generation.

**Key capabilities**: 51+ court forms, guided workflows, smart data sharing across forms, auto-save, anonymous 72-hour sessions, optional user accounts.

## Commands

### Development
```bash
bin/dev                              # Start dev server (Rails + Tailwind watch)
bin/rails server                     # Rails server only
```

### Database
```bash
bin/rails db:create db:migrate db:seed   # Full setup
bin/rails db:reset                        # Drop, create, migrate, seed
```

### Testing
```bash
bin/rails spec                            # All RSpec tests
bin/rails spec spec/models/user_spec.rb  # Single spec file
bin/rails spec spec/models/              # Directory of specs
npm test                                  # Jest (JavaScript unit tests)
npm run test:e2e                         # Playwright E2E tests
npm run test:e2e:ui                      # E2E with browser UI
```

### Linting
```bash
bin/rubocop                    # Ruby linting
bin/rubocop -a                 # Ruby auto-fix
npm run js-lint                # ESLint
npm run js-lint-fix            # ESLint auto-fix
bin/brakeman                   # Security scan
bin/bundler-audit              # Dependency audit
```

### Custom Tasks
```bash
bin/rails forms:import[metadata_path,pdf_dir]  # Bulk import forms
bin/rails forms:extract_fields[form_code]      # Extract PDF field names
```

## Architecture

### Data Flow
```
Anonymous User → SessionSubmission (72hr expiry) → [signup] → Submission (permanent)
Registered User → Submission (persistent)
```

### PDF Generation (Dual Strategy)
- **Fillable PDFs**: `Pdf::Strategies::FormFilling` uses pdftk/HexaPDF
- **Non-fillable PDFs**: `Pdf::Strategies::HtmlGeneration` uses Grover/Puppeteer
- Strategy selection handled by `Pdf::FormFiller`

### Key Service Objects
- `Forms::BulkImporter` - Import forms from YAML + PDFs
- `Pdf::FormFiller` - PDF generation orchestrator
- `Workflows::Engine` - Workflow state machine
- `Sessions::StorageManager` - Anonymous session handling

### Model Relationships
```
User → Submissions, FormFeedbacks
FormDefinition → FieldDefinitions, Submissions, SessionSubmissions
Workflow → WorkflowSteps → FormDefinitions
```

### Shared Field Keys
Fields with matching `shared_field_key` share data across forms (e.g., plaintiff_name reused in SC-100 and SC-105).

### Form Schemas
YAML definitions in `config/form_schemas/small_claims/` organized by category:
- `plaintiff/`, `defendant/`, `judgment/`, `enforcement/`, `appeal/`, `pre_trial/`, `service/`

### Workflow Definitions
YAML in `config/workflows/` - define multi-step guided processes with data mappings between forms.

## Tech Stack

- **Rails 8.1** + Hotwire (Turbo + Stimulus)
- **Tailwind CSS** + DaisyUI
- **SQLite** (dev/test) / **PostgreSQL** (prod)
- **Devise** (auth) + **Pundit** (authorization)
- **Solid Queue/Cache/Cable** (database-backed infrastructure)
- **pdftk** required for PDF generation

## Prerequisites

pdftk must be installed:
```bash
# Ubuntu/Debian
sudo apt-get install pdftk-java

# macOS
brew install pdftk-java
```

## Documentation

Comprehensive guides in `/docs/guides/`:
- `frontend/turbo-guide.md` - Turbo patterns
- `backend/pdf-processing.md` - PDF handling details
- `testing/testing-guide.md` - Testing reference
- `development/development-reference.md` - Daily workflow
