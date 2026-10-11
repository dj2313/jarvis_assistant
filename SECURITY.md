# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x     | Yes       |
| < 1.0   | No        |

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

Instead, use **GitHub Private Vulnerability Reporting**:
`https://github.com/dj2313/jarvis_assistant/security/advisories/new`

Include:
- Description and impact
- Steps to reproduce (without real API keys)
- Affected version/commit

We aim to acknowledge within 72 hours.

## Scope Notes

- Never commit `.env` or API keys. All secrets load via `flutter_dotenv`.
- The app requests microphone, location, and notification permissions at runtime — each is optional and degrades gracefully.
- Supabase tables must have Row Level Security enabled (see `PROJECT_AUDIT.md`).
