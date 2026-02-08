# CI/CD Pipeline Documentation for Attendanzy

## Overview

This document describes the CI/CD pipeline and security measures implemented for the Attendanzy project.

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Repository                         │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                     GitHub Actions Triggers                      │
│  • Push to main/develop                                         │
│  • Pull Requests                                                │
│  • Release Tags (v*.*.*)                                        │
│  • Scheduled (Weekly security scans)                            │
└─────────────────────────────────────────────────────────────────┘
                                │
                ┌───────────────┴───────────────┐
                ▼                               ▼
┌─────────────────────────┐     ┌─────────────────────────┐
│    Backend Pipeline      │     │   Frontend Pipeline      │
│  ┌───────────────────┐  │     │  ┌───────────────────┐  │
│  │ Security Scan     │  │     │  │ Analyze & Lint    │  │
│  │ • npm audit       │  │     │  │ • dart format     │  │
│  │ • Snyk scan       │  │     │  │ • flutter analyze │  │
│  └─────────┬─────────┘  │     │  └─────────┬─────────┘  │
│            ▼            │     │            ▼            │
│  ┌───────────────────┐  │     │  ┌───────────────────┐  │
│  │ Lint & Quality    │  │     │  │ Run Tests         │  │
│  │ • ESLint          │  │     │  │ • flutter test    │  │
│  │ • Secret scan     │  │     │  │ • Code coverage   │  │
│  └─────────┬─────────┘  │     │  └─────────┬─────────┘  │
│            ▼            │     │            ▼            │
│  ┌───────────────────┐  │     │  ┌───────────────────┐  │
│  │ Build & Test      │  │     │  │ Build Android     │  │
│  │ • Unit tests      │  │     │  │ • APK             │  │
│  │ • Integration     │  │     │  │ • App Bundle      │  │
│  └─────────┬─────────┘  │     │  └─────────┬─────────┘  │
│            ▼            │     │            ▼            │
│  ┌───────────────────┐  │     │  ┌───────────────────┐  │
│  │ Docker Build      │  │     │  │ Build iOS         │  │
│  │ • Build image     │  │     │  │ • IPA (no sign)   │  │
│  │ • Push to hub     │  │     │  └───────────────────┘  │
│  └───────────────────┘  │     │                         │
└─────────────────────────┘     └─────────────────────────┘
                │                               │
                └───────────────┬───────────────┘
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Deployment                               │
│  • Staging Environment (develop branch)                         │
│  • Production Environment (main branch)                         │
│  • Firebase App Distribution (APK)                              │
└─────────────────────────────────────────────────────────────────┘
```

## Workflow Files

| File | Purpose | Trigger |
|------|---------|---------|
| `backend-ci.yml` | Backend CI/CD | Push/PR to backend/ |
| `frontend-ci.yml` | Frontend CI/CD | Push/PR to frontend/ |
| `security-scan.yml` | Security scanning | Push/PR + Weekly schedule |
| `release.yml` | Release automation | Version tags |
| `pr-check.yml` | PR validation | Pull requests |

## Security Measures

### 1. Backend Security

#### Middleware Stack
```javascript
// Production security middleware
app.use(helmet());           // HTTP security headers
app.use(rateLimiter());      // Rate limiting
app.use(cors());             // CORS whitelist
app.use(mongoSanitize());    // NoSQL injection prevention
app.use(xss());              // XSS protection
app.use(hpp());              // HTTP Parameter Pollution prevention
```

#### Rate Limiting
- **General API**: 100 requests per 15 minutes per IP
- **Auth Routes**: 10 requests per hour per IP

#### Security Headers (Helmet.js)
- Content-Security-Policy
- X-Frame-Options: DENY
- X-Content-Type-Options: nosniff
- Strict-Transport-Security
- X-XSS-Protection

### 2. CI/CD Security Scanning

| Tool | Purpose |
|------|---------|
| **npm audit** | Node.js vulnerability scanning |
| **Snyk** | Dependency vulnerability detection |
| **TruffleHog** | Secret detection in code |
| **Gitleaks** | Git history secret scanning |
| **CodeQL** | Static code analysis |
| **Semgrep** | SAST scanning |
| **Trivy** | Container vulnerability scanning |

### 3. Dependency Management

**Dependabot** is configured to:
- Check for updates weekly
- Create PRs for security patches
- Group updates by type
- Ignore major version updates for critical packages

## Required GitHub Secrets

Configure these secrets in your GitHub repository settings:

### Backend Deployment
| Secret | Description |
|--------|-------------|
| `DOCKER_USERNAME` | Docker Hub username |
| `DOCKER_PASSWORD` | Docker Hub password/token |
| `SNYK_TOKEN` | Snyk API token (optional) |

### Frontend Deployment
| Secret | Description |
|--------|-------------|
| `FIREBASE_APP_ID` | Firebase App ID |
| `FIREBASE_SERVICE_CREDENTIALS` | Firebase service account JSON |
| `ANDROID_KEYSTORE_BASE64` | Base64 encoded keystore |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_KEY_ALIAS` | Key alias |

## Local Development

### Install Security Dependencies
```bash
cd backend
npm install
```

### Run Security Checks Locally
```bash
# Lint code
npm run lint

# Check vulnerabilities
npm run audit

# Fix vulnerabilities
npm run audit:fix
```

### Run with Docker
```bash
# Build image
npm run docker:build

# Run container
npm run docker:run
```

## Branch Protection Rules

Configure these in GitHub repository settings:

### Main Branch
- ✅ Require pull request reviews
- ✅ Require status checks to pass
- ✅ Require branches to be up to date
- ✅ Require signed commits (recommended)
- ✅ Include administrators

### Required Status Checks
- `security-scan / dependency-scan`
- `backend-check`
- `frontend-check`

## Deployment Environments

### Staging
- Branch: `develop`
- Auto-deploy: Yes
- URL: staging.attendanzy.com (configure)

### Production
- Branch: `main`
- Auto-deploy: Yes (after approval)
- URL: attendanzy.com (configure)

## Versioning

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

### Creating a Release
```bash
# Create and push a tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

This triggers the release workflow which:
1. Creates a GitHub release
2. Builds and uploads Android APK/AAB
3. Builds and pushes Docker image

## Monitoring & Alerts

### GitHub Security Tab
- Dependabot alerts
- Code scanning alerts
- Secret scanning alerts

### Recommended Integrations
- Sentry (Error tracking)
- DataDog/New Relic (APM)
- PagerDuty (Incident management)

## Troubleshooting

### Pipeline Failures

1. **Security scan failures**
   - Check `npm audit` output
   - Update vulnerable packages
   - Add to ignore list if false positive

2. **Build failures**
   - Check Node.js/Flutter versions
   - Clear caches and rebuild

3. **Docker build failures**
   - Verify Dockerfile syntax
   - Check base image availability

### Common Issues

| Issue | Solution |
|-------|----------|
| Rate limit exceeded | Wait or use authenticated requests |
| Secret not found | Add secret to repository settings |
| Build cache issues | Clear GitHub Actions cache |
