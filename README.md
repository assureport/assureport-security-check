# 🛡️ AssurePort Security Check

[![GitHub Marketplace](https://img.shields.io/badge/Marketplace-AssurePort%20Security%20Check-orange?logo=github)](https://github.com/marketplace)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Powered by AssurePort](https://img.shields.io/badge/powered%20by-AssurePort-E14B2E)](https://assureport.com)

**Catch the easy security wins before an attacker does — straight from your CI.**

A free GitHub Action that runs a **passive, read-only** security-posture snapshot of a
domain **you own**, using [AssurePort](https://assureport.com)'s public tools. It checks the
boring-but-critical stuff that quietly ships broken, and (optionally) leaves the summary as a
pull-request comment so the whole team sees it on every change.

No secrets. No credentials. No scanning of other people's systems. Just a quick hygiene read
of your own front door.

---

## What it checks

| Check | What it tells you |
|---|---|
| **Security headers** | CSP, HSTS, X-Frame-Options & friends — response-header hardening, graded A–F |
| **TLS / certificate** | Transport security and certificate health |
| **SSO / MFA surface** | Which identity providers (Okta, Azure AD, Auth0, Keycloak…) and MFA signals your login exposes |
| **Email auth** | SPF / DKIM / DMARC — how spoofable your domain is |
| **DNSSEC** | Whether your DNS answers can be forged |
| **HSTS** | Forced-HTTPS and preload eligibility |

> These are **surface-level** checks. They are not a penetration test — they tell you what's
> obviously exposed, not what a determined attacker could chain together.

## Quickstart

```yaml
# .github/workflows/security-check.yml
name: Security Check
on:
  pull_request:
  schedule:
    - cron: '0 6 * * 1'   # every Monday, 06:00 UTC
permissions:
  contents: read
  pull-requests: write     # only needed for the PR comment
jobs:
  assureport:
    runs-on: ubuntu-latest
    steps:
      - uses: YOUR-ORG/assureport-security-check@v1
        with:
          domain: example.com          # ← a domain YOU own
          # comment-pr: true            # default
          # fail-on-headers-grade: 'C'  # optional: fail the build below grade C
```

## Inputs

| Input | Required | Default | Description |
|---|---|---|---|
| `domain` | ✅ | — | The domain **you own** to check (e.g. `example.com`). Passive, read-only. |
| `api-base` | — | `https://api.assureport.com` | AssurePort public API base URL. |
| `comment-pr` | — | `true` | Post the report as a PR comment (needs `pull-requests: write`). The step summary is always written. |
| `fail-on-headers-grade` | — | `''` | Fail the job when the security-headers grade is worse than this letter (A–F). Empty = never fail. |

## Authorisation & privacy

Run this **only against a domain you own or are explicitly authorised to test.** Every check is
a passive, unauthenticated `GET` — the same requests a browser makes when it loads your site —
so it never attempts logins, never sends payloads, and never touches anyone else's systems.
Nothing is stored beyond AssurePort's standard anonymous request log.

---

## Want the full picture?

Surface checks find the front-door basics. A real assessment goes deep: OWASP Top 10,
authentication & access-control (BOLA/IDOR), SSRF, business-logic flaws — each with a working,
exploit-verified proof-of-concept, and every finding mapped to **GDPR / ISO 27001 / SOC 2 /
PCI-DSS**.

**AssurePort** runs that assessment with AI agents, built and hosted entirely in the **EU**.

### → [Start at assureport.com](https://assureport.com)
- 🧰 **15 free tools** (incl. the ones this Action uses): https://assureport.com/tools.html
- 🔍 Free anonymous **surface preview** of your site — no signup
- 🛡️ Full AI penetration test when you're ready

---

<sub>MIT-licensed. Not affiliated with or endorsed by GitHub. Powered by [AssurePort](https://assureport.com).</sub>
