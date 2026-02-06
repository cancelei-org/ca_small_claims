# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

California Small Claims Court Forms - a Rails 8.1 application that provides guided, interactive form-filling for California Small Claims Court forms with PDF generation.

**Key capabilities**: 51+ court forms, guided workflows, smart data sharing across forms, auto-save, anonymous 72-hour sessions, optional user accounts.

**Target users**: Self-represented litigants (pro se) filing small claims cases in California courts.

## Quick Start

```bash
# Install dependencies
bundle install && npm install

# Setup database
bin/rails db:create db:migrate db:seed

# Start development server
bin/dev
```

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
| Service | Purpose | Location |
|---------|---------|----------|
| `Forms::BulkImporter` | Import forms from YAML + PDFs | `app/services/forms/` |
| `Pdf::FormFiller` | PDF generation orchestrator | `app/services/pdf/` |
| `Pdf::Strategies::FormFilling` | Fill PDF form fields via pdftk | `app/services/pdf/strategies/` |
| `Pdf::Strategies::HtmlGeneration` | Generate PDF from HTML | `app/services/pdf/strategies/` |
| `Autofill::SuggestionService` | Smart field suggestions | `app/services/autofill/` |
| `FormDependencies::ResolverService` | Form dependency chains | `app/services/form_dependencies/` |
| `LegalTerms::DefinitionService` | Legal term tooltips | `app/services/legal_terms/` |
| `NextSteps::GuidanceService` | Post-form guidance | `app/services/next_steps/` |

### Model Relationships
```
User → Submissions, FormFeedbacks, NotificationPreference
FormDefinition → FieldDefinitions, Submissions, SessionSubmissions
Workflow → WorkflowSteps → FormDefinitions
Courthouse (standalone, for court finder)
```

### Shared Field Keys
Fields with matching `shared_field_key` share data across forms (e.g., plaintiff_name reused in SC-100 and SC-105).

### Form Schemas
YAML definitions in `config/form_schemas/` organized by category:
- `small_claims/plaintiff/` - Plaintiff claim forms (SC-100, SC-103, etc.)
- `small_claims/defendant/` - Defendant response forms
- `small_claims/judgment/` - Judgment and satisfaction forms
- `small_claims/enforcement/` - Wage garnishment, liens
- `small_claims/appeal/` - Appeal forms
- `small_claims/pre_trial/` - Continuance, venue transfer
- `small_claims/service/` - Proof of service forms
- `guardianship/` - Guardianship forms (GC-240, etc.)

### Workflow Definitions
YAML in `config/workflows/` - define multi-step guided processes with data mappings between forms.

## Tech Stack

- **Rails 8.1** + Hotwire (Turbo + Stimulus)
- **Tailwind CSS** + DaisyUI
- **SQLite** (dev/test) / **PostgreSQL** (prod)
- **Devise** (auth) + **Pundit** (authorization)
- **Solid Queue/Cache/Cable** (database-backed infrastructure)
- **pdftk** required for PDF generation
- **Grover/Puppeteer** for HTML-to-PDF (non-fillable forms)

## Prerequisites

pdftk must be installed:
```bash
# Ubuntu/Debian
sudo apt-get install pdftk-java

# macOS
brew install pdftk-java
```

## Email System

### When Users Receive Emails

The application sends emails in the following scenarios:

| Trigger | Email Type | Description |
|---------|-----------|-------------|
| Form completed | `form_submission_confirmation` | Confirmation with next steps |
| PDF ready | `form_download_ready` | Notification that PDF is available |
| User clicks "Send to Email" | `form_pdf_delivery` | PDF attached to email |
| Fee waiver status change | `fee_waiver_status_update` | Approved/denied/pending notification |
| Deadline approaching | `deadline_reminder` | Urgency-based reminders (3/7 days) |

### Email Architecture

```
User Action → Controller → NotificationEmailJob (Solid Queue) → NotificationMailer → SMTP
```

**Key files:**
- `app/mailers/application_mailer.rb` - Base mailer with defaults
- `app/mailers/notification_mailer.rb` - All notification emails
- `app/jobs/notification_email_job.rb` - Async email delivery
- `app/jobs/form_email_job.rb` - PDF attachment delivery
- `app/views/notification_mailer/` - Email templates (HTML + text)

### User Notification Preferences

Users can control which emails they receive via `NotificationPreference`:
- `email_form_submission` (default: true)
- `email_form_download` (default: true)
- `email_deadline_reminders` (default: true)
- `email_fee_waiver_status` (default: true)
- `email_marketing` (default: false)

### Email Configuration

Configure in `.env` (see `example.env`):
```bash
MAILER_FROM_ADDRESS=noreply@yourdomain.com
APP_HOST=yourdomain.com

# Option 1: EMAILIT (recommended)
EMAILIT_API_KEY=your-api-key

# Option 2: SMTP
SMTP_ADDRESS=smtp.example.com
SMTP_PORT=587
SMTP_USERNAME=user
SMTP_PASSWORD=pass
```

## Stimulus Controllers

Key JavaScript controllers in `app/javascript/controllers/`:

| Controller | Purpose |
|------------|---------|
| `wizard_controller.js` | Multi-step form wizard navigation with swipe gestures |
| `form_controller.js` | Form validation, auto-save, and field change tracking |
| `autofill_controller.js` | Smart field suggestions from profile/previous forms |
| `validation_controller.js` | Real-time field validation with error messages |
| `dictation_controller.js` | Voice input support for form fields |
| `searchable_select_controller.js` | Searchable dropdown menus with filtering |
| `bottom_sheet_controller.js` | Mobile action sheets (Save, Download, Email) |
| `modal_controller.js` | Modal dialog management with accessibility |
| `command_bar_controller.js` | Keyboard shortcuts (Cmd+K) |
| `completion_indicator_controller.js` | Real-time progress tracking |
| `encouragement_controller.js` | Milestone notifications and progress feedback |
| `legal_tooltip_controller.js` | Legal term definitions on hover |
| `conditional_field_controller.js` | Show/hide fields based on conditions |
| `address_controller.js` | Address autocomplete and ZIP formatting |
| `keyboard_nav_controller.js` | Keyboard navigation for form fields |

## Admin Panel

Admin interface at `/admin` (requires `admin: true` on User):
- Dashboard with analytics
- Form feedback management
- User management with impersonation
- Submission viewing (read-only)
- Session submissions cleanup

## Key Patterns

### Controller Concerns
- `SessionStorage` - Anonymous session handling
- `PdfHandling` - PDF generation and download
- `FormDisplay` - Form rendering logic
- `FormResponseHandler` - Turbo Stream responses
- `Alerting` - Flash message helpers
- `Impersonation` - Admin user switching

### Model Concerns
- `FormDataAccessor` - JSON form data access
- `ConditionalSupport` - Field visibility conditions
- `Notifiable` - Email notification triggers
- `StatusChecker` - Submission status management

### View Patterns
- Turbo Frames for partial page updates
- Turbo Streams for real-time updates
- ViewComponents for reusable UI (`app/components/`)
- Partials in `app/views/shared/` for common elements

## Environment Variables

See `example.env` for complete list. Critical variables:

| Variable | Required | Description |
|----------|----------|-------------|
| `SECRET_KEY_BASE` | Yes | Rails encryption key |
| `DATABASE_URL` | Production | PostgreSQL connection |
| `PDFTK_PATH` | No | Auto-detected pdftk location |
| `MAILER_FROM_ADDRESS` | No | Email sender address |
| `APP_HOST` | No | Application hostname for emails |

## Deployment

### Docker (Recommended)
```bash
docker build -t ca-small-claims .
docker run -e DATABASE_URL=... -e SECRET_KEY_BASE=... -p 80:80 ca-small-claims
```

### Kamal
```bash
kamal setup    # First deployment
kamal deploy   # Subsequent deployments
```

Configuration in `config/deploy.yml`.

### Health Checks

OkComputer endpoints at `/health`:
- Database connectivity
- Cache store health
- Queue backlog monitoring
- PDF templates directory check

## Testing Strategy

### Test Types
- **Unit tests** (RSpec): Models, services, helpers
- **Request specs**: Controller endpoints
- **System specs**: Full browser integration
- **E2E tests** (Playwright): Mobile and accessibility

### Running Tests
```bash
# Full suite
bin/rails spec

# Specific categories
bin/rails spec spec/models/
bin/rails spec spec/requests/
bin/rails spec spec/system/

# E2E
npm run test:e2e
```

### Test Coverage
Target: 80%+ for core functionality (models, services, controllers)

## Experimental Features

These features are in development and may require additional setup:

### Semantic Search (requires Python + flukebase_connect)
- Location: `app/services/search/form_semantic_search.rb`
- Provides AI-powered form search
- Tests in `spec/services/search/`

### LLM Router (requires API keys)
- Location: `spec/experimental/llm_router_integration_spec.rb`
- Routes queries to appropriate LLM tier
- Requires `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`

## Documentation

Comprehensive guides in `/docs/guides/`:
- `frontend/turbo-guide.md` - Turbo patterns
- `backend/pdf-processing.md` - PDF handling details
- `testing/testing-guide.md` - Testing reference
- `development/development-reference.md` - Daily workflow

Security documentation:
- `docs/SECURITY_AUDIT_2026-01-04.md` - Security audit results
- `docs/PENETRATION_TESTING_CHECKLIST.md` - Pentest checklist
- `VULNERABILITY_DISCLOSURE.md` - Responsible disclosure policy

## Common Tasks

### Adding a New Form
1. Create YAML schema in `config/form_schemas/[category]/[form_code].yml`
2. Add PDF template to `db/seeds/pdf_templates/`
3. Run `bin/rails forms:import[path/to/schema.yml,path/to/pdfs/]`
4. Add to workflow if needed in `config/workflows/`

### Adding a New Email Notification
1. Add method to `app/mailers/notification_mailer.rb`
2. Create template in `app/views/notification_mailer/`
3. Add job handling in `app/jobs/notification_email_job.rb`
4. Add preference column to `NotificationPreference` if user-controllable

### Adding a Stimulus Controller
1. Create file in `app/javascript/controllers/[name]_controller.js`
2. Export from `app/javascript/controllers/index.js`
3. Use in views with `data-controller="[name]"`

## Troubleshooting

### PDF Generation Fails
- Check pdftk is installed: `which pdftk` or `pdftk --version`
- Check template exists: `ls db/seeds/pdf_templates/`
- Check logs for Grover/Puppeteer errors

### Email Not Sending
- Check `MAILER_FROM_ADDRESS` is set
- Check SMTP or EMAILIT credentials
- Check Solid Queue is processing: `bin/rails solid_queue:start`
- Check user has `can_receive_emails?` (not guest, has email)

### Database Issues
- Reset: `bin/rails db:reset`
- Check migrations: `bin/rails db:migrate:status`
- For Solid infrastructure: Check separate database URLs

## File Structure Overview

```
app/
├── components/          # ViewComponents
├── controllers/
│   ├── admin/          # Admin panel controllers
│   ├── api/            # API endpoints
│   └── concerns/       # Controller mixins
├── helpers/            # View helpers
├── javascript/
│   ├── controllers/    # Stimulus controllers
│   └── utils/          # Shared JS utilities
├── jobs/               # Background jobs (Solid Queue)
├── mailers/            # Email mailers
├── models/
│   └── concerns/       # Model mixins
├── policies/           # Pundit authorization
├── services/           # Business logic
│   ├── analytics/      # Analytics services
│   ├── autofill/       # Smart suggestions
│   ├── form_dependencies/
│   ├── form_estimates/
│   ├── form_finder/
│   ├── legal_terms/
│   ├── next_steps/
│   ├── pdf/            # PDF generation
│   └── search/         # Form search
└── views/
    ├── admin/          # Admin templates
    ├── forms/          # Form templates
    │   ├── fields/     # Field partials
    │   └── wizard/     # Wizard components
    ├── layouts/        # Application layouts
    ├── notification_mailer/  # Email templates
    └── shared/         # Shared partials

config/
├── form_schemas/       # Form YAML definitions
├── workflows/          # Workflow YAML definitions
├── legal_terms/        # Legal glossary
├── next_steps/         # Post-form guidance
├── templates/          # Pre-fill templates
└── tutorials/          # User tutorials

db/
├── seeds/              # Seed data
│   └── pdf_templates/  # PDF form templates
└── migrate/            # Database migrations

docs/
└── guides/             # Developer documentation

spec/                   # RSpec tests
tests/e2e/              # Playwright E2E tests
```
