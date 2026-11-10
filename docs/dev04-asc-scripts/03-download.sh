#!/usr/bin/env bash
#
# ASC Project ? DEV04 download helper ? SCRIPT 3 (the DOWNLOAD)
#
# Downloads the generated zips from the DEV04 download surface
# (e.g. https://dev04.dev.bizmates.jp/20261201_PRE_(DEV04_ASC_20260611_161907).zip).
#
# Authentication: the site SOMETIMES asks for credentials. This script:
#   1. tries each URL first WITHOUT credentials (or with ones you already gave);
#   2. on HTTP 401, prompts once for username/password (hidden input), then
#      reuses them for every remaining URL in the same run;
#   3. checks that what came back is really a zip (not an HTML login page).
# Credentials are never put on the command line (so they don't show in the
# process list) and are never written to disk.
#
# Usage:
#   bash 03-download.sh URL [URL ...]
#   bash 03-download.sh -f urls.txt            # one URL per line (# comments ok)
#   bash 03-download.sh -r dev04-asc-report-YYYYMMDD_HHMMSS.txt
#                                              # the report from 02-move.sh: every
#                                              # https://... .zip line is downloaded
# Options (env vars):
#   DOWNLOAD_DIR=./downloads   where files are saved (default ./downloads)
#   DEV04_USER / DEV04_PASS    credentials to use up front (skips the prompt)
#   FORCE=1                    re-download even if the file already exists
#   CONNECT_TIMEOUT=20         seconds to wait for the server to answer

set -uo pipefail   # no -e: one failed URL must not stop the rest.

DOWNLOAD_DIR="${DOWNLOAD_DIR:-./downloads}"
FORCE="${FORCE:-0}"
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-20}"
AUTH_USER="${DEV04_USER:-}"
AUTH_PASS="${DEV04_PASS:-}"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[WARN] $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }

command -v curl >/dev/null 2>&1 || die "curl is not installed."

usage() { sed -n '2,/^set -uo/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d'; exit 1; }

# ----------------------------------------------------------------------------
# Collect URLs
# ----------------------------------------------------------------------------
URLS=()
while [ $# -gt 0 ]; do
  case "$1" in
    -f) [ -f "${2:-}" ] || die "URL file not found: ${2:-}"
        while IFS= read -r line; do
          line="${line%%#*}"; line="$(echo "$line" | tr -d '\r' | xargs)"
          [ -n "$line" ] && URLS+=("$line")
        done < "$2"; shift 2;;
    -r) [ -f "${2:-}" ] || die "Report file not found: ${2:-}"
        while IFS= read -r line; do URLS+=("$line"); done \
          < <(tr -d '\r' < "$2" | grep -oE 'https?://[^[:space:]]+\.zip')
        shift 2;;
    -h|--help) usage;;
    *)  URLS+=("$1"); shift;;
  esac
done
[ "${#URLS[@]}" -gt 0 ] || usage

mkdir -p "${DOWNLOAD_DIR}" || die "Cannot create ${DOWNLOAD_DIR}"

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
# Decode %XX in the URL's last path segment to get the real filename
# (e.g. ..._PRE_%28DEV04..%29.zip -> ..._PRE_(DEV04..).zip).
filename_from_url() {
  local name="${1%%\?*}"; name="${name##*/}"
  printf '%b' "${name//%/\\x}"
}

prompt_credentials() {
  if [ ! -t 0 ]; then
    die "Server asked for authentication but there is no terminal to prompt on. Set DEV04_USER and DEV04_PASS."
  fi
  echo "" >&2
  echo "The server is asking for authentication." >&2
  read -r -p "  Username: " AUTH_USER < /dev/tty
  read -r -s -p "  Password: " AUTH_PASS < /dev/tty; echo "" >&2
  [ -n "${AUTH_USER}" ] || die "No username given."
}

# Escape a value for curl's config-file syntax ("..." with \ and " escaped).
curl_quote() { local v="${1//\\/\\\\}"; v="${v//\"/\\\"}"; printf '"%s"' "$v"; }

# Run curl. Credentials (if any) go through a config on stdin, not argv.
# Prints the HTTP status code; body is written to $2.
fetch() {
  local url="$1" out="$2"
  local cfg=""
  if [ -n "${AUTH_USER}" ]; then
    cfg="user = $(curl_quote "${AUTH_USER}:${AUTH_PASS}")"
  fi
  printf '%s\n' "$cfg" | curl --config - \
    --globoff --location --anyauth \
    --connect-timeout "${CONNECT_TIMEOUT}" --retry 2 --retry-delay 3 \
    --silent --show-error \
    --output "$out" --write-out '%{http_code}' \
    "$url" 2>"${out}.err"
}

# A zip starts with "PK" (50 4B).
is_zip() { [ -s "$1" ] && [ "$(head -c 2 "$1" | od -An -c | tr -d ' ')" = "PK" ]; }

# ----------------------------------------------------------------------------
# Download loop
# ----------------------------------------------------------------------------
ok=0; skipped=0; failed=0
for url in "${URLS[@]}"; do
  name="$(filename_from_url "$url")"
  dest="${DOWNLOAD_DIR}/${name}"
  tmp="${dest}.part"

  if [ -f "$dest" ] && [ "${FORCE}" != "1" ]; then
    log "skip (already downloaded): ${name}"
    skipped=$((skipped+1)); continue
  fi

  log "download ${name}"
  code="$(fetch "$url" "$tmp")"

  # Asked for credentials? Prompt once, then retry this URL.
  if [ "$code" = "401" ]; then
    if [ -n "${AUTH_USER}" ]; then
      warn "${name}: credentials were rejected (HTTP 401). Enter them again."
    fi
    prompt_credentials
    code="$(fetch "$url" "$tmp")"
  fi

  case "$code" in
    200)
      if is_zip "$tmp"; then
        mv "$tmp" "$dest"; rm -f "${tmp}.err"
        log "  saved ${dest} ($(du -h "$dest" | cut -f1))"
        ok=$((ok+1))
      elif grep -qiE '<html|<form|login|password' "$tmp" 2>/dev/null; then
        warn "${name}: got an HTML page instead of a zip ? this looks like a LOGIN FORM (cookie/SSO login), not a password popup."
        warn "  Log in once in your browser, or ask how DEV04 downloads are authorised. Saved the page as ${tmp}.html for inspection."
        mv "$tmp" "${tmp}.html"; rm -f "${tmp}.err"; failed=$((failed+1))
      else
        warn "${name}: downloaded, but the file is not a valid zip. Kept as ${tmp}."
        rm -f "${tmp}.err"; failed=$((failed+1))
      fi
      ;;
    401) warn "${name}: still HTTP 401 ? wrong username/password."; rm -f "$tmp" "${tmp}.err"; failed=$((failed+1));;
    403) warn "${name}: HTTP 403 Forbidden ? your IP/VPN may not be allowed."; rm -f "$tmp" "${tmp}.err"; failed=$((failed+1));;
    404) warn "${name}: HTTP 404 ? file not on the server (check the exact name/timestamp)."; rm -f "$tmp" "${tmp}.err"; failed=$((failed+1));;
    000) warn "${name}: could not reach the server: $(tail -n 1 "${tmp}.err" 2>/dev/null)"
         warn "  If this is a timeout, connect to the VPN / office network first."
         rm -f "$tmp" "${tmp}.err"; failed=$((failed+1));;
    *)   warn "${name}: unexpected HTTP ${code}: $(tail -n 1 "${tmp}.err" 2>/dev/null)"; rm -f "$tmp" "${tmp}.err"; failed=$((failed+1));;
  esac
done

echo ""
log "DONE. Downloaded: ${ok}, Skipped: ${skipped}, Failed: ${failed}. Folder: ${DOWNLOAD_DIR}"
[ "$failed" -eq 0 ]
