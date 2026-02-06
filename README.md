# California Small Claims Court Forms

A free, open-source web application helping self-represented litigants fill out California Small Claims Court forms with guided wizards and automatic PDF generation.

## Why This App?

Filing a small claims case shouldn't require a lawyer. This application provides:

- **Plain English Guidance**: Legal terms explained in tooltips as you fill forms
- **Smart Workflows**: Step-by-step guides for common scenarios (filing, responding, collecting)
- **Time Savings**: Information entered once carries forward to related forms
- **Court-Ready PDFs**: Generate properly filled forms ready for filing

## Features

### Form Filling Experience
- **51+ California Court Forms**: All official Judicial Council small claims forms
- **Wizard Mode**: Card-by-card guided experience with progress tracking
- **Traditional Mode**: All fields visible at once for experienced users
- **Real-time Validation**: Instant feedback on required fields and formatting
- **Auto-Save**: Progress saved automatically as you type
- **Completion Tracking**: Visual progress indicator with time estimates

### Smart Features
- **Autofill Suggestions**: Reuse information from your profile and previous forms
- **Field Help**: Contextual help explaining what each field requires
- **Legal Term Glossary**: Hover over legal terms for plain-English definitions
- **Conditional Fields**: Only shows fields relevant to your situation
- **Voice Input**: Dictation support for faster form filling (mobile)

### Accessibility & Mobile
- **Fully Responsive**: Works on phones, tablets, and desktops
- **Keyboard Navigation**: Complete the entire form without a mouse
- **Screen Reader Support**: ARIA labels and live announcements
- **Dark Mode**: System-aware theme switching
- **Offline Support**: Continue working even without internet

### Privacy & Security
- **Anonymous Access**: Use without creating an account (72-hour sessions)
- **Optional Accounts**: Create an account to save forms permanently
- **No Data Selling**: Your information is never shared or sold
- **Secure by Default**: HTTPS, CSP, rate limiting, and session protection

## Quick Start

### Using Docker (Recommended)

```bash
# Clone the repository
git clone https://github.com/yourusername/ca-small-claims.git
cd ca-small-claims

# Build and start
docker compose up -d

# Set up the database
docker compose exec web bin/rails db:setup

# Visit http://localhost:3001
```

### Local Development

**Prerequisites:**
- Ruby 3.4+
- Node.js 20+
- pdftk (`sudo apt install pdftk-java` or `brew install pdftk-java`)

```bash
# Install dependencies
bundle install && npm install

# Set up database
bin/rails db:setup

# Start development server
bin/dev

# Visit http://localhost:3000
```

## Usage Guide

### 1. Choose Your Path

**Guided Workflows** - Best for first-time filers:
- "I want to sue someone" → Filing a Claim workflow
- "Someone is suing me" → Responding to a Claim workflow
- "I won, now what?" → Collecting a Judgment workflow

**Individual Forms** - If you know which form you need:
- Browse all 51+ forms by category
- Search by form number (e.g., "SC-100")
- Filter by plaintiff/defendant/judgment forms

### 2. Fill Out Your Form

- Toggle between **Wizard** (step-by-step) and **Traditional** (all fields) modes
- Required fields are marked with a red asterisk
- Click the help icon next to any field for guidance
- Your progress auto-saves every few seconds

### 3. Download Your PDF

- Click **Download PDF** when complete
- Use **Preview** to review before downloading
- **Send to Email** to receive a copy in your inbox

### 4. File with the Court

- Print your completed forms
- Make the required number of copies
- File at your local courthouse or online (where available)

## Supported Forms

| Category | Forms | Description |
|----------|-------|-------------|
| **Filing a Claim** | SC-100, SC-103, SC-104A | Plaintiff's claim and supporting documents |
| **Responding** | SC-120, SC-120A | Defendant's response forms |
| **Service** | SC-104, POS-030 | Proof of service documents |
| **Judgment** | SC-130, SC-132, SC-133 | Judgment and satisfaction forms |
| **Enforcement** | SC-134, WG-001 | Wage garnishment and liens |
| **Appeals** | SC-140, SC-141 | Appeal and stay of enforcement |
| **Pre-Trial** | SC-150, CIV-110 | Continuance and venue change |
| **Guardianship** | GC-240+ | Guardianship-related forms |

## Tech Stack

- **Backend**: Ruby on Rails 8.1, PostgreSQL
- **Frontend**: Hotwire (Turbo + Stimulus), Tailwind CSS, DaisyUI
- **PDF Generation**: pdftk, Grover/Puppeteer
- **Infrastructure**: Solid Queue, Solid Cache, Solid Cable
- **Authentication**: Devise with optional accounts
- **Deployment**: Docker, Kamal

## Environment Variables

Copy `example.env` to `.env` and configure:

| Variable | Required | Description |
|----------|----------|-------------|
| `SECRET_KEY_BASE` | Yes | Rails encryption key |
| `DATABASE_URL` | Production | PostgreSQL connection string |
| `MAILER_FROM_ADDRESS` | No | Email sender address |
| `APP_HOST` | No | Application hostname |
| `PDFTK_PATH` | No | Path to pdftk (auto-detected) |

See `example.env` for all available options.

## Testing

```bash
# Ruby tests
bin/rails spec

# JavaScript tests
npm test

# End-to-end tests
npm run test:e2e

# All linting
bin/rubocop && npm run js-lint
```

## Deployment

### With Kamal (Recommended)

```bash
# First deployment
kamal setup

# Subsequent deployments
kamal deploy
```

### With Docker

```bash
docker build -t ca-small-claims .
docker run -e DATABASE_URL=... -e SECRET_KEY_BASE=... -p 80:80 ca-small-claims
```

### Health Checks

The application exposes health endpoints at `/health`:
- Database connectivity
- Cache store health
- Background job queue status
- PDF template availability

## Contributing

We welcome contributions! See [DEVELOPMENT.md](DEVELOPMENT.md) for setup instructions.

**Ways to contribute:**
- Add support for other states' court forms
- Improve accessibility
- Add translations (Spanish support in progress)
- Report bugs or suggest features
- Improve documentation

### Adding New Forms

1. Create YAML schema in `config/form_schemas/`
2. Add PDF template to `db/seeds/pdf_templates/`
3. Run `bin/rails forms:import`

See `CLAUDE.md` for detailed architecture documentation.

## Security

- Report vulnerabilities via [VULNERABILITY_DISCLOSURE.md](VULNERABILITY_DISCLOSURE.md)
- Security audit results in `docs/SECURITY_AUDIT_2026-01-04.md`
- Penetration testing checklist in `docs/PENETRATION_TESTING_CHECKLIST.md`

## License

This project is open source under the [MIT License](LICENSE).

## Disclaimer

This application helps users fill out California Small Claims Court forms. It is **not legal advice**. For questions about your legal rights or the court process, consult a qualified attorney or visit:

- [California Courts Self-Help Center](https://selfhelp.courts.ca.gov/)
- [Small Claims Court Information](https://www.courts.ca.gov/selfhelp-smallclaims.htm)
- [Find Your Local Court](https://www.courts.ca.gov/find-my-court.htm)

## Acknowledgments

- California Judicial Council for the official court forms
- The open-source community for the amazing tools that make this possible
