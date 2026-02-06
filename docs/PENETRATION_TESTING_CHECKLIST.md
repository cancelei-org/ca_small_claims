# Penetration Testing Checklist

This checklist covers common security tests for the California Small Claims Court Forms application.

## 1. Authentication & Authorization
- [ ] Verify that all admin routes require admin privileges.
- [ ] Test for session hijacking and fixation.
- [ ] Check if user can access other users' submissions via ID guessing (IDOR).
- [ ] Verify that guest tokens are sufficiently random and cannot be guessed.
- [ ] Test password reset flow for vulnerabilities.

## 2. Input Validation & Injection
- [ ] Test all form fields for Cross-Site Scripting (XSS).
- [ ] Check for SQL injection in search and filter parameters.
- [ ] Verify that PDF generation does not allow command injection (pdftk).
- [ ] Test for Mass Assignment in all controllers.
- [ ] Check for CSV injection in analytics exports.

## 3. Data Protection
- [ ] Verify that sensitive fields are encrypted at rest (User profile).
- [ ] Check if session cookies have `Secure`, `HttpOnly`, and `SameSite=Lax` flags.
- [ ] Ensure HTTPS is enforced for all requests.
- [ ] Verify that PII is not leaked in application logs.

## 4. Rate Limiting & DoS
- [ ] Test Rack::Attack throttling for login attempts.
- [ ] Verify rate limiting for API endpoints.
- [ ] Test for potential resource exhaustion in PDF generation.

## 5. Information Disclosure
- [ ] Check for sensitive information in `robots.txt`.
- [ ] Verify that development/debug info is not shown in production error pages.
- [ ] Check for exposed `.git` or configuration files.

## 6. Business Logic
- [ ] Verify that form completion percentage is calculated correctly.
- [ ] Test workflow state transitions for consistency.
- [ ] Ensure that anonymous sessions expire correctly after 72 hours.
