# PDF Templates Reference

This directory contains **sample** PDF templates for reference purposes only.

## Purpose

These PDFs serve as:
- Examples for developers to inspect PDF structure
- Reference for field names and form layout
- Local development without S3 access

## Production Usage

⚠️ **The application uses S3 for all PDF templates in development and production.**

- **Storage**: IDRIVE S3 (bucket: `casmallclaims`)
- **Environment prefixes**: `development/templates/`, `production/templates/`
- **Full template set**: 1,493 PDFs uploaded to S3
- **Local cache**: Templates downloaded to `tmp/cached_templates/` (24hr TTL)

## Sample Forms Included

| Form Code | Description | Category |
|-----------|-------------|----------|
| SC-100 | Plaintiff's Claim | Small Claims |
| SC-105 | Defendant's Claim | Small Claims |
| SC-120 | Defendant's Answer | Small Claims |
| EJ-100 | Abstract of Judgment | Enforcement |
| EJ-130 | Writ of Execution | Enforcement |

## Getting Full Templates

To access all 1,493 PDF templates:

```bash
# Enable S3 storage (in .env)
USE_S3_STORAGE=true

# Download templates on-demand
bin/rails runner "FormDefinition.first.pdf_path"

# Or download specific template
bin/rails "s3:download_template[sc100.pdf]"
```

## Local Development Without S3

If you need to work offline:

```bash
# Disable S3 in .env
USE_S3_STORAGE=false

# Copy templates from S3 cache to lib/pdf_templates/
cp -r tmp/cached_templates/* lib/pdf_templates/
```

Note: `lib/pdf_templates/` is gitignored. Templates stored in S3 only.
