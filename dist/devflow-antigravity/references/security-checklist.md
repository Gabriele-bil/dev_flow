# Security Checklist

Stack-agnostic. Use alongside `devflow-beautify` security axis and adapter data/auth skill.
Stack-specific checks in active `ADAPTER.md` → **Technology skills**.

## Pre-Commit

- [ ] No secrets in committed code (`git diff --cached | grep -i "password\|secret\|api_key\|token"`)
- [ ] `.gitignore` covers: `.env`, `.env.local`, `*.pem`, `*.key`, generated credential files
- [ ] `.env.example` uses placeholder values only

## Authentication

- [ ] Passwords hashed with bcrypt (≥12 rounds), scrypt, or argon2 — never plain or MD5/SHA1
- [ ] Session tokens: `httpOnly`, `secure`, short max-age
- [ ] Rate limiting on auth endpoints
- [ ] Password reset tokens: time-limited (≤1 hour), single-use, invalidated on use
- [ ] JWT validated: signature, expiration, issuer

## Authorization

- [ ] Every protected operation checks authentication
- [ ] Every resource access checks ownership/role (prevents IDOR)
- [ ] Admin operations require role verification — not just login check
- [ ] API keys scoped to minimum permissions

## Input Validation

- [ ] All user/external input validated at system boundaries before use in logic, storage, or queries
- [ ] Validation uses allowlists, not denylists
- [ ] String lengths constrained (min/max)
- [ ] File uploads: type restricted, size limited, content verified
- [ ] Queries parameterized — no string concatenation into SQL or query languages
- [ ] Output encoded for context (HTML, URL, JSON) — use framework auto-escaping

## Data Protection

- [ ] Sensitive fields excluded from API/log responses (`passwordHash`, `resetToken`, etc.)
- [ ] Secrets not in logs, analytics events, or crash reports
- [ ] All external communication over HTTPS/TLS
- [ ] PII encrypted at rest if required by regulation

## Error Handling

```json
// Production: generic error, no internals
{ "error": { "code": "INTERNAL_ERROR", "message": "Something went wrong" } }

// NEVER expose in production:
{ "error": err.message, "stack": err.stack, "query": err.sql }
```

## Dependency Security

```bash
# Audit (Node)
npm audit --audit-level=high

# Audit (Dart/Flutter)
dart pub audit

# Audit (Angular/npm)
npm audit --audit-level=high
```

## OWASP Top 10 Quick Reference

| # | Vulnerability | Prevention |
| --- | --------------- | ------------ |
| 1 | Broken Access Control | Auth + ownership check on every operation |
| 2 | Cryptographic Failures | HTTPS, strong hashing, no secrets in code |
| 3 | Injection | Parameterized queries, input validation at boundaries |
| 4 | Insecure Design | Threat modeling, spec-driven development |
| 5 | Security Misconfiguration | Minimal permissions, audit deps, no default creds |
| 6 | Vulnerable Components | `npm audit` / `dart pub audit`, keep deps updated |
| 7 | Auth Failures | Strong passwords, rate limiting, session management |
| 8 | Data Integrity Failures | Verify deps/artifacts, signed releases |
| 9 | Logging Failures | Log security events; never log secrets |
| 10 | SSRF | Validate/allowlist URLs, restrict outbound requests |
