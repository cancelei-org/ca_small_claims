# Security Audit Report
**Date**: 2026-01-04
**Auditor**: Claude Code
**Tools**: Brakeman 7.1.1, Bundler-Audit

## Executive Summary

A comprehensive security audit was performed on the California Small Claims Court Forms application. The audit identified **5 medium-confidence security warnings** and **0 dependency vulnerabilities**.

### Overall Assessment: **MODERATE RISK**
- ✅ No dependency vulnerabilities
- ⚠️ 5 security warnings requiring attention
- ✅ Rails 8.1.1 with automatic HTML escaping enabled
- ✅ CSRF protection enabled

---

## Detailed Findings

### 1. Mass Assignment Vulnerabilities (2 instances)

**Severity**: Medium
**Risk**: User could potentially inject unauthorized fields into database

#### Issue 1.1: Forms Controller
- **File**: `app/controllers/forms_controller.rb:144`
- **Code**: `params.require(:submission).permit!.to_h`
- **Impact**: Allows any parameters to be mass-assigned to Submission model

**Recommendation**:
```ruby
# BEFORE (Insecure)
def submission_params
  params.require(:submission).permit!.to_h
end

# AFTER (Secure)
def submission_params
  # Define explicit field list from form definition
  permitted_fields = @form_definition.field_definitions.pluck(:name)
  params.require(:submission).permit(permitted_fields).to_h
end
```

#### Issue 1.2: Workflows Controller
- **File**: `app/controllers/workflows_controller.rb:90`
- **Code**: `params.require(:submission).permit!.to_h`
- **Impact**: Same as above

**Recommendation**: Apply the same fix as Issue 1.1

**Priority**: **HIGH** - This should be addressed immediately as it's a direct controller vulnerability

---

### 2. SQL Injection Vulnerability (1 instance)

**Severity**: Medium
**Risk**: Potential SQL injection through dynamic CASE statement

- **File**: `app/services/form_finder/recommender.rb:190`
- **Code**:
```ruby
Arel.sql("CASE code #{codes.map.with_index { |c, i| "WHEN '#{c}' THEN #{i}" }.join(" ")} END")
```

**Issue**: Form codes are interpolated directly into SQL without sanitization

**Current Risk Assessment**:
- Codes come from internal YAML configuration files
- Not directly user-controlled
- However, best practice is to sanitize anyway

**Recommendation**:
```ruby
# BEFORE (Potentially vulnerable)
def load_forms(codes)
  return [] if codes.empty?

  FormDefinition.where(code: codes).order(Arel.sql(
    "CASE code #{codes.map.with_index { |c, i| "WHEN '#{c}' THEN #{i}" }.join(" ")} END"
  ))
end

# AFTER (Secure)
def load_forms(codes)
  return [] if codes.empty?

  # Sanitize codes to prevent SQL injection
  sanitized_cases = codes.map.with_index do |code, i|
    sanitized_code = ActiveRecord::Base.connection.quote(code)
    "WHEN #{sanitized_code} THEN #{i}"
  end.join(" ")

  FormDefinition.where(code: codes).order(Arel.sql("CASE code #{sanitized_cases} END"))
end
```

**Priority**: **MEDIUM** - Not immediately exploitable but should be fixed

---

### 3. Command Injection Vulnerabilities (2 instances)

**Severity**: Medium
**Risk**: Potential command injection through system calls

#### Issue 3.1: Schema Comparator
- **File**: `app/services/schema/comparator.rb:71`
- **Code**: `` `docker-compose -f #{"docker-compose.burner.yml"} exec -T #{instance} bin/rails runner "puts File.read('db/schema.rb')" 2>/dev/null` ``
- **Issue**: Variable `instance` is interpolated into shell command

**Current Risk Assessment**:
- Only used in development/debugging tools
- `instance` variable should be validated

**Recommendation**:
```ruby
# Add validation before executing command
def read_remote_schema(instance)
  # Validate instance name (alphanumeric and hyphens only)
  raise ArgumentError, "Invalid instance name" unless instance =~ /\A[a-zA-Z0-9\-_]+\z/

  # Use array form to avoid shell injection
  result = Open3.capture3(
    "docker-compose", "-f", "docker-compose.burner.yml",
    "exec", "-T", instance,
    "bin/rails", "runner", "puts File.read('db/schema.rb')"
  )
  result[0]  # stdout
end
```

#### Issue 3.2: PDFtk Resolver
- **File**: `app/services/utilities/pdftk_resolver.rb:65`
- **Code**: `` `#{path} --version 2>&1` ``
- **Issue**: Variable `path` is interpolated into shell command

**Current Risk Assessment**:
- Only used internally to check PDFtk installation
- Path should be validated before use

**Recommendation**:
```ruby
# Add validation
def check_version(path)
  # Validate path is absolute and exists
  raise ArgumentError, "Invalid path" unless File.file?(path)

  # Use array form or validate path
  `#{Shellwords.escape(path)} --version 2>&1`
end
```

**Priority**: **LOW** - These are internal development/utility tools not exposed to users

---

## Security Best Practices Review

### ✅ Implemented Correctly
1. **CSRF Protection**: Enabled by default in Rails 8.1
2. **HTML Escaping**: Automatic HTML escaping enabled
3. **Authentication**: Devise properly configured
4. **Authorization**: Pundit policies in place
5. **Secure Headers**: Content Security Policy configured
6. **Session Security**: Secure session storage using database
7. **SQL Injection Protection**: ActiveRecord parameterization used throughout (except 1 case noted)
8. **Dependency Security**: All gems up to date with no known vulnerabilities

### ⚠️ Areas for Improvement
1. **Mass Assignment**: Need explicit permit lists (2 occurrences)
2. **SQL Injection**: One instance of string interpolation in SQL
3. **Command Injection**: Two instances in development tools

---

## Recommended Actions

### Immediate (Within 1 week)
1. ✅ **Fix Mass Assignment** - Replace `permit!` with explicit field lists
   - Priority: HIGH
   - Files: `forms_controller.rb`, `workflows_controller.rb`
   - Estimated time: 1 hour

### Short-term (Within 1 month)
2. ✅ **Fix SQL Injection** - Add sanitization to dynamic CASE statement
   - Priority: MEDIUM
   - File: `form_finder/recommender.rb`
   - Estimated time: 30 minutes

3. ✅ **Add Input Validation** - Validate inputs to command execution
   - Priority: LOW
   - Files: `schema/comparator.rb`, `utilities/pdftk_resolver.rb`
   - Estimated time: 1 hour

### Long-term (Ongoing)
4. ✅ **Regular Security Audits** - Run Brakeman and bundler-audit monthly
5. ✅ **Security Training** - Review OWASP Top 10 for Rails
6. ✅ **Penetration Testing** - Consider professional security assessment before production

---

## Compliance Notes

For production deployment, especially with sensitive legal documents:
- ✅ Ensure HTTPS is enforced
- ✅ Implement rate limiting (Rack::Attack configured)
- ✅ Enable audit logging for admin actions
- ✅ Configure secure session cookies
- ✅ Implement data encryption at rest for sensitive fields
- ✅ Add security headers (CSP, X-Frame-Options, etc.)
- ⚠️ Consider adding penetration testing
- ⚠️ Implement vulnerability disclosure policy

---

## Appendix: Scan Details

### Brakeman Scan
- **Version**: 7.1.1
- **Rails Version**: 8.1.1
- **Scan Date**: 2026-01-04
- **Duration**: 2.05 seconds
- **Files Scanned**:
  - Controllers: 20
  - Models: 11
  - Templates: 79
- **Checks Run**: 77 security checks
- **Errors**: 0
- **Security Warnings**: 5

### Bundler-Audit Scan
- **Database Version**: ruby-advisory-db (updated 2025-12-23)
- **Advisories**: 1036 advisories checked
- **Vulnerabilities Found**: 0
- **Result**: ✅ All dependencies secure

---

## Sign-off

This security audit provides a snapshot of the application's security posture as of 2026-01-04. Regular security reviews should be conducted, especially:
- Before major releases
- After significant code changes
- Monthly as part of DevOps process
- After any security incidents

**Next Review Date**: 2026-02-04
