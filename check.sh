#!/usr/bin/env bash
# AssurePort Security Check — composite action entrypoint.
# Passive, read-only posture snapshot of a domain the caller owns, using
# AssurePort's free public intel API. No secrets, no auth, no mutation.
set -uo pipefail

DOMAIN="${APRT_DOMAIN:?domain input is required}"
API="${APRT_API_BASE:-https://api.assureport.com}"
API="${API%/}"
FAIL_GRADE="${APRT_FAIL_GRADE:-}"

# Strip any scheme/path the user may have pasted — endpoints take a bare host.
HOST="$(printf '%s' "$DOMAIN" | sed -E 's#^https?://##; s#/.*$##')"
URL="https://${HOST}"

echo "AssurePort Security Check → ${HOST}"

# curl one endpoint; echo the JSON body, or '' on any transport error.
# $1 = path incl. query. Short timeouts so a slow target can't hang CI.
fetch() {
  curl -fsS --max-time 25 -H 'Accept: application/json' \
       -A 'assureport-security-check (github-action)' \
       "${API}${1}" 2>/dev/null || true
}

# Pull the first present field from a JSON blob, trying several candidate keys.
# $1 = json, rest = candidate jq paths. Prints '' if none resolve to a scalar.
pick() {
  local json="$1"; shift
  [ -z "$json" ] && { printf ''; return; }
  local p val
  for p in "$@"; do
    val="$(printf '%s' "$json" | jq -r "($p) // empty" 2>/dev/null)"
    if [ -n "$val" ] && [ "$val" != "null" ]; then printf '%s' "$val"; return; fi
  done
  printf ''
}

row() { printf '| %s | %s | %s |\n' "$1" "$2" "$3"; }

HEADERS_JSON="$(fetch "/api/intel/headers?url=$(printf '%s' "$URL" | jq -sRr @uri)")"
SSL_JSON="$(fetch "/api/intel/ssl?host=${HOST}")"
AUTH_JSON="$(fetch "/api/intel/auth-surface?host=${HOST}")"
EMAIL_JSON="$(fetch "/api/intel/email-auth?host=${HOST}")"
DNSSEC_JSON="$(fetch "/api/intel/dnssec?host=${HOST}")"
HSTS_JSON="$(fetch "/api/intel/hsts?host=${HOST}")"

HEADERS_GRADE="$(pick "$HEADERS_JSON" '.grade' '.score' '.rating')"
SSL_SUM="$(pick "$SSL_JSON" '.grade' '.summary' '.status' '.valid')"
AUTH_SUM="$(pick "$AUTH_JSON" '.mfaSummary' '.summary')"
AUTH_SSO="$(printf '%s' "$AUTH_JSON" | jq -r '[.ssoProviders[]?.provider] | unique | join(", ") // empty' 2>/dev/null)"
EMAIL_SUM="$(pick "$EMAIL_JSON" '.summary' '.dmarc.status' '.status')"
DNSSEC_SUM="$(pick "$DNSSEC_JSON" '.status' '.summary' '.enabled')"
HSTS_SUM="$(pick "$HSTS_JSON" '.status' '.summary' '.preloaded' '.eligible')"

na() { [ -n "$1" ] && printf '%s' "$1" || printf '— (see full report)'; }

REPORT_FILE="$(mktemp)"
{
  echo "## 🛡️ AssurePort Security Check — \`${HOST}\`"
  echo
  echo "Passive, read-only posture snapshot via AssurePort's free tools."
  echo
  echo "| Check | Signal | Detail |"
  echo "|---|---|---|"
  row "Security headers" "$(na "$HEADERS_GRADE")" "HTTP response-header hardening"
  row "TLS / certificate" "$(na "$SSL_SUM")" "Transport security"
  row "SSO / MFA surface" "$(na "$AUTH_SUM")" "$( [ -n "$AUTH_SSO" ] && printf 'Providers: %s' "$AUTH_SSO" || printf 'Login identity posture' )"
  row "Email auth (SPF/DKIM/DMARC)" "$(na "$EMAIL_SUM")" "Spoofing resistance"
  row "DNSSEC" "$(na "$DNSSEC_SUM")" "DNS integrity"
  row "HSTS" "$(na "$HSTS_SUM")" "Forced-HTTPS / preload"
  echo
  echo "> These are **surface-level** checks. A real attacker goes deeper — "
  echo "> OWASP Top 10, auth/BOLA, SSRF, business logic, with working proof-of-concept."
  echo
  echo "### 🔍 Get the full picture"
  echo "Run a full **AI-powered penetration test** on \`${HOST}\` — exploit-verified"
  echo "findings mapped to GDPR / ISO 27001 / SOC 2, built & hosted in the EU:"
  echo
  echo "**→ https://assureport.com**  ·  Free surface preview & 15 free tools: https://assureport.com/tools.html"
  echo
  echo "<sub>Passive checks on a domain you own. Not affiliated with GitHub. Powered by [AssurePort](https://assureport.com).</sub>"
} > "$REPORT_FILE"

# Always write the job's step summary.
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then cat "$REPORT_FILE" >> "$GITHUB_STEP_SUMMARY"; fi
echo "----- report -----"; cat "$REPORT_FILE"; echo "------------------"

# Optionally comment on the PR (best-effort; never fails the build on its own).
if [ "${APRT_COMMENT_PR:-true}" = "true" ] && [ -n "${GH_EVENT_PATH:-}" ] && [ -f "${GH_EVENT_PATH}" ]; then
  PR_NUMBER="$(jq -r '.pull_request.number // empty' "${GH_EVENT_PATH}" 2>/dev/null)"
  if [ -n "$PR_NUMBER" ] && [ -n "${GH_TOKEN:-}" ] && [ -n "${GH_REPO:-}" ]; then
    BODY="$(jq -Rs '{body: .}' < "$REPORT_FILE")"
    curl -fsS --max-time 25 -X POST \
      -H "Authorization: Bearer ${GH_TOKEN}" \
      -H 'Accept: application/vnd.github+json' \
      -H 'X-GitHub-Api-Version: 2022-11-28' \
      "https://api.github.com/repos/${GH_REPO}/issues/${PR_NUMBER}/comments" \
      -d "$BODY" >/dev/null 2>&1 \
      && echo "Posted PR comment on #${PR_NUMBER}." \
      || echo "PR comment skipped (needs 'permissions: pull-requests: write')."
  fi
fi

# Optional gate: fail when the headers grade is worse than the threshold.
if [ -n "$FAIL_GRADE" ] && [ -n "$HEADERS_GRADE" ]; then
  gnum() { case "$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]' | cut -c1)" in
    A) echo 5;; B) echo 4;; C) echo 3;; D) echo 2;; E) echo 1;; F) echo 0;; *) echo 9;; esac; }
  if [ "$(gnum "$HEADERS_GRADE")" -lt "$(gnum "$FAIL_GRADE")" ]; then
    echo "::error::Security-headers grade ${HEADERS_GRADE} is below the required ${FAIL_GRADE}."
    exit 1
  fi
fi

exit 0
