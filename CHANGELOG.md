# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-01-26

### Added
- **Completion Indicator**: Real-time progress tracking with percentage and time estimates
- **Encouragement System**: Milestone notifications to keep users motivated
- **Legal Term Glossary**: Hover tooltips explaining legal terminology
- **Conditional Fields**: Dynamic field visibility based on user selections
- **Keyboard Navigation**: Full keyboard support for form navigation
- **Address Autocomplete**: ZIP code formatting and address field helpers
- **Form Requirements Modal**: Clear list of what's needed before filing
- **Tutorial System**: First-time user guidance
- **FAQ Integration**: Contextual help and frequently asked questions
- **Next Steps Guidance**: Post-form filing instructions

### Changed
- **Simplified Form UI**: Removed complex real-time PDF preview in favor of simpler download/preview buttons
- **Improved Mobile Experience**: Streamlined bottom sheet with essential actions only
- **Better Test Coverage**: Fixed test isolation issues and improved spec reliability
- **Refactored Helpers**: Split form helpers into focused modules (InputFieldHelper, FieldAccessibilityHelper)
- **Optimized Database Queries**: Added `status_counts` scope to reduce N+1 queries

### Removed
- `pdf_preview_controller.js` - Real-time PDF canvas rendering (~616 lines)
- `pdf_drawer_controller.js` - Mobile slide-in PDF drawer (~93 lines)
- `PdfPreviewComponent` - ViewComponent for PDF preview (~318 lines)
- PDF preview panel and related CSS (~350 lines)
- Total reduction: ~1,300 lines of complex JavaScript/CSS

### Fixed
- Test authentication issues with Warden/Devise integration
- Session corruption in multi-request tests
- Form field_id conflicts with Rails helpers
- Burner log analyzer count expectations
- Semantic search fallback behavior

### Security
- All tests passing (except 14 experimental LLM tests requiring API keys)
- Production-ready security configuration verified

---

## [0.1.0] - 2026-01-13

### Added
- **51+ California Court Forms**: All official Judicial Council small claims forms
- **Guided Workflows**: Step-by-step processes for filing, responding, and collecting
- **Wizard Mode**: Card-by-card form filling with progress tracking
- **Traditional Mode**: All fields visible at once option
- **PDF Generation**: Dual strategy support (fillable PDFs and HTML-to-PDF)
- **Anonymous Sessions**: 72-hour sessions without account requirement
- **Optional Accounts**: Permanent storage for registered users
- **Smart Data Sharing**: Information carries across related forms
- **Auto-Save**: Automatic progress saving as users type
- **Mobile-First Design**: Responsive UI with DaisyUI components
- **Admin Dashboard**: Form management and analytics
- **Feedback System**: User ratings and issue reporting
- **Theme Support**: Light/dark mode with system preference detection
- **Offline Support**: Progressive web app capabilities
- **Voice Input**: Dictation support for form fields
- **Autofill**: Smart suggestions from profile and previous forms
- **Form Validation**: Real-time field validation with error messages
- **Email Notifications**: Form completion and deadline reminders
- **Impersonation**: Admin user switching for support

### Technical
- Rails 8.1 with Hotwire (Turbo + Stimulus)
- Tailwind CSS with DaisyUI component library
- PostgreSQL with Solid Queue/Cache/Cable
- pdftk and Grover/Puppeteer for PDF generation
- Devise authentication with Pundit authorization
- Comprehensive security headers and CSP
- Rate limiting with Rack::Attack
- Health checks with OkComputer
- Docker and Kamal deployment support

---

## Version History

| Version | Date | Highlights |
|---------|------|------------|
| 0.2.0 | 2026-01-26 | Simplified UI, better mobile, improved tests |
| 0.1.0 | 2026-01-13 | Initial release with 51+ forms |
