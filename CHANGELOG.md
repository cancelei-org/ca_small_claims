# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Comprehensive documentation of experimental features in CLAUDE.md
- CHANGELOG.md for tracking project changes

### Changed
- Updated experimental features documentation to include all unwired controllers

### Documented (Quarantined - Not Removed)
The following experimental features exist in the codebase but are not wired to the UI.
They are documented in CLAUDE.md rather than removed to preserve future development options:

**Stimulus Controllers (unwired):**
- `dictation_controller.js` - Voice dictation for form fields
- `conditional_controller.js` - Conditional field visibility
- `autofill_controller.js` - Auto-populate from previous submissions
- `validation_controller.js` - Enhanced client-side validation
- `input_format_controller.js` - Auto-format inputs (phone, SSN)
- `pull_refresh_controller.js` - Mobile pull-to-refresh gesture
- `repeating_controller.js` - Repeating field groups
- `download_controller.js` - Enhanced download handling
- `form_controller.js` - Base form behavior
- `profile_controller.js` - User profile interactions
- `offline_indicator_controller.js` - PWA offline indicator (wired but hidden)

**Skipped Tests:**
- `spec/system/offline_support_spec.rb` - Offline feature messaging not finalized
- `spec/system/language_switching_spec.rb:33` - i18n session persistence not fully implemented
- `spec/system/pdf_xray_spec.rb` - PDF X-Ray feature not fully implemented

**Services (implemented but not integrated):**
- `app/services/autofill/` - Autofill service directory

### Security
- No security issues identified in experimental code review

---

## [0.1.0] - Pre-release (Development)

### Added
- 51+ California Small Claims Court forms
- Guided workflow system with multi-form support
- PDF generation with dual strategy (fillable + HTML generation)
- Anonymous 72-hour sessions with optional user accounts
- Smart data sharing across forms via shared_field_key
- Auto-save functionality
- Mobile-responsive design with DaisyUI components
- Admin dashboard for form management
- Feedback system with star ratings
- Theme customization (light/dark modes)
