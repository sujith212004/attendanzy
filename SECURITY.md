# Attendanzy - Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 2.x.x   | :white_check_mark: |
| 1.x.x   | :x:                |

## Reporting a Vulnerability

We take security seriously at Attendanzy. If you discover a security vulnerability, please follow these steps:

### Do NOT
- Open a public GitHub issue for security vulnerabilities
- Disclose the vulnerability publicly before it has been addressed

### Do
1. **Email us directly** at security@attendanzy.com (replace with your actual security email)
2. Include the following information:
   - Type of vulnerability (e.g., XSS, SQL Injection, Authentication bypass)
   - Steps to reproduce the vulnerability
   - Potential impact of the vulnerability
   - Any suggestions for fixing the issue

### What to Expect
- **Acknowledgment**: We will acknowledge receipt of your report within 48 hours
- **Assessment**: We will assess the vulnerability and determine its severity within 7 days
- **Resolution**: We aim to resolve critical vulnerabilities within 30 days
- **Disclosure**: We will coordinate with you on public disclosure after the fix is deployed

### Bug Bounty
We currently do not have a formal bug bounty program, but we appreciate and acknowledge security researchers who responsibly disclose vulnerabilities.

## Security Measures

### Backend Security
- **Helmet.js**: HTTP security headers
- **Rate Limiting**: Protection against brute force and DDoS attacks
- **Input Validation**: Express-validator for request validation
- **NoSQL Injection Prevention**: express-mongo-sanitize
- **XSS Protection**: xss-clean middleware
- **CORS**: Configured whitelist for allowed origins
- **JWT**: Secure token-based authentication

### Frontend Security
- **Secure Storage**: Sensitive data encrypted in secure storage
- **Certificate Pinning**: SSL certificate validation
- **Input Sanitization**: User input sanitization before API calls

### Infrastructure Security
- **HTTPS**: All communications encrypted with TLS
- **Environment Variables**: Secrets stored in environment variables
- **Docker**: Containerized deployment with security best practices
- **CI/CD**: Automated security scanning in pipeline

## Security Best Practices for Contributors

1. Never commit sensitive data (API keys, passwords, tokens)
2. Keep dependencies updated
3. Follow the principle of least privilege
4. Use parameterized queries for database operations
5. Validate and sanitize all user inputs
6. Use secure coding practices

## Contact

For security concerns, please contact:
- Email: security@attendanzy.com
- Response time: Within 48 hours
