#!/usr/bin/env bash
#
# ASC Project - DEV04 download helper - SCRIPT 3, version 2 (multi-file DOWNLOAD)
#
# Downloads many zips from the DEV04 download surface in one run. The list of
# links can come from a text file, a JSON file, an env file or the command line.
# Only links are downloaded: any other text (e.g. "May data:") is skipped, but
# it is remembered as a LABEL for the links under it (shown in the log/summary,
# and used as a sub-folder with --group).
#
# Authentication: the site SOMETIMES asks for credentials. For every link this
# script first tries WITHOUT credentials (or with the ones already given); on
# HTTP 401 it prompts once (hidden password) and reuses them for the rest of the
# run. It also checks that each .zip is really a zip, not an HTML login page.
# Credentials are never put on the command line and never written to disk.
#
# Usage:
#   bash 03-download-v2.sh                       # uses the default files below
#   bash 03-download-v2.sh -i links.txt          # any text: links are picked out
#   bash 03-download-v2.sh -i links.json         # JSON (format below)
#   bash 03-download-v2.sh -e my.env             # settings/credentials/links from an env file
#   bash 03-download-v2.sh URL [URL ...]         # links on the command line
#   (-i can be repeated; all sources are combined, duplicates removed)
#
# Default files (next to this script), used when no -i/-e/URL is given:
#   03-download.env         settings + credentials (git-ignored: *.env)
#   03-download.links.json  if present, else 03-download.links.txt
#
# Options:
#   -i, --links FILE   text or JSON file with links (repeatable)
#   -e, --env FILE     env file (keys below). Read as data, never executed.
#   -o, --out DIR      download folder (default ./downloads)
#   --group            save each label's files in its own sub-folder
#   --dry-run          list what would be downloaded; download nothing
#   --force            re-download files that already exist
#   --no-check         skip the "is the server reachable?" check
#   -h, --help         show this help
#
# Env file keys (KEY=value, one per line, # comments ok):
#   DEV04_USER, DEV04_PASS   credentials (skip the prompt)
#   DOWNLOAD_DIR             download folder
#   LINKS_FILE               a links file (text or JSON), relative to the env file
#   LINKS                    links separated by spaces or commas
#   GROUP=1, FORCE=1, CONNECT_TIMEOUT=20
#
# JSON formats accepted:
#   ["https://...zip", "https://...zip"]
#   {"May data": ["https://...", "https://..."], "June data": [ ... ]}
#   {"download_dir": "./downloads", "group": true,
#    "links": ["https://...", {"url": "https://...", "label": "May data", "name": "may-pre.zip"}]}
#
# Exit code: 0 = everything downloaded or already there, 1 = something failed.

set -uo pipefail   # no -e: one failed link must not stop the rest.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
log()  { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[WARN] $*" >&2; }
die()  { echo "[ERROR] $*" >&2; exit 1; }
usage() { sed -n '2,/^set -uo/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d'; exit "${1:-1}"; }

command -v curl >/dev/null 2>&1 || die "curl is not installed."
command -v python3 >/dev/null 2>&1 || die "python3 is needed to read the links."

DOWNLOAD_DIR="${DOWNLOAD_DIR:-./downloads}"
FORCE="${FORCE:-0}"; GROUP="${GROUP:-0}"; DRY=0; CHECK=1
CONNECT_TIMEOUT="${CONNECT_TIMEOUT:-20}"
AUTH_USER="${DEV04_USER:-}"; AUTH_PASS="${DEV04_PASS:-}"
LINK_FILES=(); ENV_FILES=(); CLI_LINKS=(); OUT_SET=""; CLI_GROUP=0; CLI_FORCE=0

while [ $# -gt 0 ]; do
  case "$1" in
    -i|--links) [ -n "${2:-}" ] || die "-i needs a file"; LINK_FILES+=("$2"); shift 2;;
    -e|--env)   [ -n "${2:-}" ] || die "-e needs a file"; ENV_FILES+=("$2"); shift 2;;
    -o|--out)   OUT_SET="${2:-}"; shift 2;;
    --group)    CLI_GROUP=1; shift;;
    --dry-run)  DRY=1; shift;;
    --force)    CLI_FORCE=1; shift;;
    --no-check) CHECK=0; shift;;
    -h|--help)  usage 0;;
    -*)         die "Unknown option: $1 (see --help)";;
    *)          CLI_LINKS+=("$1"); shift;;
  esac
done

if [ "${#LINK_FILES[@]}" -eq 0 ] && [ "${#ENV_FILES[@]}" -eq 0 ] && [ "${#CLI_LINKS[@]}" -eq 0 ]; then
  [ -f "$SCRIPT_DIR/03-download.env" ] && ENV_FILES+=("$SCRIPT_DIR/03-download.env")
fi

# ---- Env files: parsed as KEY=value data (never sourced/executed) ----------
ENV_LINKS=""
for ef in "${ENV_FILES[@]}"; do
  [ -f "$ef" ] || die "Env file not found: $ef"
  ef_dir="$(cd "$(dirname "$ef")" && pwd)"
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(printf '%s' "$line" | tr -d '\r')"
    case "$line" in ''|\#*) continue;; esac
    line="${line#export }"
    key="${line%%=*}"; val="${line#*=}"
    key="$(echo "$key" | xargs)"
    [ "$key" = "$line" ] && continue
    val="${val#"${val%%[![:space:]]*}"}"; val="${val%"${val##*[![:space:]]}"}"
    if [ "${#val}" -ge 2 ]; then
      first="${val:0:1}"; lastc="${val: -1}"
      if { [ "$first" = '"' ] && [ "$lastc" = '"' ]; } || { [ "$first" = "'" ] && [ "$lastc" = "'" ]; }; then
        val="${val:1:${#val}-2}"
      fi
    fi
    case "$key" in
      DEV04_USER) AUTH_USER="$val";;
      DEV04_PASS) AUTH_PASS="$val";;
      DOWNLOAD_DIR) DOWNLOAD_DIR="$val";;
      LINKS_FILE) case "$val" in /*|~*) LINK_FILES+=("${val/#\~/$HOME}");; *) LINK_FILES+=("$ef_dir/$val");; esac;;
      LINKS) ENV_LINKS="$ENV_LINKS $val";;
      GROUP) GROUP="$val";; FORCE) FORCE="$val";; CONNECT_TIMEOUT) CONNECT_TIMEOUT="$val";;
      *) warn "env file $ef: unknown key '$key' ignored";;
    esac
  done < "$ef"
done

if [ "${#LINK_FILES[@]}" -eq 0 ] && [ -z "$ENV_LINKS" ] && [ "${#CLI_LINKS[@]}" -eq 0 ]; then
  if   [ -f "$SCRIPT_DIR/03-download.links.json" ]; then LINK_FILES+=("$SCRIPT_DIR/03-download.links.json")
  elif [ -f "$SCRIPT_DIR/03-download.links.txt" ];  then LINK_FILES+=("$SCRIPT_DIR/03-download.links.txt")
  else usage 1; fi
fi
[ -n "$OUT_SET" ] && DOWNLOAD_DIR="$OUT_SET"
DOWNLOAD_DIR="${DOWNLOAD_DIR/#\~/$HOME}"

# ---- Collect links -> LABELS[], URLS[], NAMES[] (deduplicated) -------------
LABELS=(); URLS=(); NAMES=()
parsed="$(python3 - "${LINK_FILES[@]}" <<'PY'
import json, re, sys
URL = re.compile(r'https?://[^\s<>"]+')
SEP = "\x1f"
out, seen, group_flag = [], set(), None

def emit(label, url, name=""):
    url = url.strip().rstrip('.,;')
    if not URL.fullmatch(url) or url in seen:
        return
    seen.add(url); out.append(SEP.join(["L", label or "", url, name or ""]))

def from_text(text):
    label = ""
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        found = URL.findall(line)
        if found:
            for u in found:
                emit(label, u)
        else:
            label = line.rstrip(":").strip()

def from_json(data, label=""):
    global group_flag
    if isinstance(data, str):
        emit(label, data)
    elif isinstance(data, list):
        for x in data:
            from_json(x, label)
    elif isinstance(data, dict):
        if "url" in data:
            emit(data.get("label", label), data["url"], data.get("name", ""))
            return
        if "download_dir" in data:
            out.append(SEP.join(["D", str(data["download_dir"])]))
        if "group" in data:
            group_flag = bool(data["group"])
        handled = False
        for key in ("links", "urls"):
            if key in data:
                from_json(data[key], label); handled = True
        if "groups" in data and isinstance(data["groups"], dict):
            for k, v in data["groups"].items():
                from_json(v, k)
            handled = True
        if not handled:
            for k, v in data.items():
                if k in ("download_dir", "group"):
                    continue
                from_json(v, k)

for path in sys.argv[1:]:
    try:
        text = open(path, encoding="utf-8-sig").read()
    except OSError as e:
        print(SEP.join(["E", "cannot read %s: %s" % (path, e)])); continue
    s = text.lstrip()
    if path.lower().endswith(".json") or s.startswith("{") or s.startswith("["):
        try:
            from_json(json.loads(text))
        except ValueError as e:
            print(SEP.join(["E", "%s: invalid JSON (%s)" % (path, e)])); continue
    else:
        from_text(text)
if group_flag is not None:
    out.append(SEP.join(["G", "1" if group_flag else "0"]))
print("\n".join(out))
PY
)" || die "Could not read the links files."

add_link() {
  local label="$1" url="$2" nm="$3" u
  for u in "${URLS[@]}"; do [ "$u" = "$url" ] && return; done
  LABELS+=("$label"); URLS+=("$url"); NAMES+=("$nm")
}
while IFS=$'\x1f' read -r kind a b c; do
  case "$kind" in
    L) add_link "$a" "$b" "$c";;
    D) [ -z "$OUT_SET" ] && DOWNLOAD_DIR="${a/#\~/$HOME}";;
    G) GROUP="$a";;
    E) die "$a";;
  esac
done <<< "$parsed"
for l in ${ENV_LINKS//,/ }; do case "$l" in http://*|https://*) add_link "" "$l" "";; esac; done
for l in "${CLI_LINKS[@]}"; do
  case "$l" in http://*|https://*) add_link "" "$l" "";; *) warn "not a link, skipped: $l";; esac
done
[ "${#URLS[@]}" -gt 0 ] || die "No links found in the given input."
# Command-line flags win over the env file and the JSON file.
[ "$CLI_GROUP" = 1 ] && GROUP=1
[ "$CLI_FORCE" = 1 ] && FORCE=1

# ---- Helpers ----------------------------------------------------------------
filename_from_url() {
  local name="${1%%\?*}"; name="${name##*/}"
  printf '%b' "${name//%/\\x}"
}
safe_dir() { echo "$1" | sed -e 's#[/\\:*?"<>|]#_#g' -e 's/^[ .]*//' -e 's/[ .]*$//' -e 's/  */ /g'; }

prompt_credentials() {
  if ! { : < /dev/tty; } 2>/dev/null; then
    die "Server asked for authentication but there is no terminal to prompt on. Put DEV04_USER and DEV04_PASS in an env file (-e)."
  fi
  echo "" >&2
  echo "The server is asking for authentication." >&2
  read -r -p "  Username: " AUTH_USER < /dev/tty
  read -r -s -p "  Password: " AUTH_PASS < /dev/tty; echo "" >&2
  [ -n "${AUTH_USER}" ] || die "No username given."
}
curl_quote() { local v="${1//\\/\\\\}"; v="${v//\"/\\\"}"; printf '"%s"' "$v"; }
fetch() {
  local url="$1" out="$2" cfg=""
  [ -n "${AUTH_USER}" ] && cfg="user = $(curl_quote "${AUTH_USER}:${AUTH_PASS}")"
  printf '%s\n' "$cfg" | curl --config - \
    --globoff --location --anyauth \
    --connect-timeout "${CONNECT_TIMEOUT}" --retry 2 --retry-delay 3 \
    --silent --show-error \
    --output "$out" --write-out '%{http_code}' \
    "$url" 2>"${out}.err"
}
is_zip() { [ -s "$1" ] && [ "$(head -c 2 "$1" | od -An -c | tr -d ' ')" = "PK" ]; }

dest_for() {
  local i="$1" nm dir="$DOWNLOAD_DIR"
  nm="${NAMES[$i]:-$(filename_from_url "${URLS[$i]}")}"
  if [ "$GROUP" = 1 ] && [ -n "${LABELS[$i]}" ]; then dir="$DOWNLOAD_DIR/$(safe_dir "${LABELS[$i]}")"; fi
  echo "$dir/$nm"
}

# ---- Plan -------------------------------------------------------------------
grp_note=""; [ "$GROUP" = 1 ] && grp_note=" (one sub-folder per label)"
echo "Found ${#URLS[@]} link(s). Download folder: ${DOWNLOAD_DIR}${grp_note}"
last_label="__none__"
for i in "${!URLS[@]}"; do
  if [ "${LABELS[$i]}" != "$last_label" ]; then echo "  ${LABELS[$i]:-(no label)}:"; last_label="${LABELS[$i]}"; fi
  d="$(dest_for "$i")"; st=""; [ -f "$d" ] && st="  (already downloaded)"
  echo "    ${d#$DOWNLOAD_DIR/}$st"
done

if [ "$DRY" = 1 ]; then
  echo ""
  log "DRY RUN: nothing was downloaded."
  exit 0
fi

# ---- Reachability check (one per host) --------------------------------------
if [ "$CHECK" = 1 ]; then
  declare -A HOSTS_OK=()
  for u in "${URLS[@]}"; do
    hp="${u#*://}"; hp="${hp%%/*}"; hp="${hp##*@}"
    [ -n "${HOSTS_OK[$hp]:-}" ] && continue
    host="${hp%%:*}"; port="${hp##*:}"
    if [ "$port" = "$hp" ]; then case "$u" in https://*) port=443;; *) port=80;; esac; fi
    if timeout "${CONNECT_TIMEOUT}" bash -c "</dev/tcp/${host}/${port}" 2>/dev/null; then
      HOSTS_OK[$hp]=1
    else
      die "Cannot reach ${host}:${port} (timed out or refused). Connect to the VPN / office network first, or use --no-check to try anyway."
    fi
  done
fi

# ---- Download loop ------------------------------------------------------------
echo ""
ok=0; skipped=0; failed=0; RESULTS=()
for i in "${!URLS[@]}"; do
  url="${URLS[$i]}"; dest="$(dest_for "$i")"; name="$(basename "$dest")"; tmp="${dest}.part"
  label="${LABELS[$i]:--}"
  if ! mkdir -p "$(dirname "$dest")"; then
    warn "cannot create $(dirname "$dest")"; failed=$((failed+1)); RESULTS+=("FAILED|$label|$name"); continue
  fi

  if [ -f "$dest" ] && [ "${FORCE}" != "1" ]; then
    log "skip (already downloaded): ${name}"
    skipped=$((skipped+1)); RESULTS+=("SKIPPED|$label|$name"); continue
  fi

  log "download ${name}${LABELS[$i]:+  [${LABELS[$i]}]}"
  code="$(fetch "$url" "$tmp")"
  if [ "$code" = "401" ]; then
    [ -n "${AUTH_USER}" ] && warn "${name}: credentials were rejected (HTTP 401). Enter them again."
    prompt_credentials
    code="$(fetch "$url" "$tmp")"
  fi

  res="FAILED"
  case "$code" in
    200)
      if [[ "$name" == *.zip ]] && ! is_zip "$tmp"; then
        if grep -qiE '<html|<form|login|password' "$tmp" 2>/dev/null; then
          warn "${name}: got an HTML page instead of a zip - looks like a LOGIN FORM (cookie/SSO), not a password popup. Saved as ${tmp}.html"
          mv "$tmp" "${tmp}.html"
        else
          warn "${name}: downloaded, but it is not a valid zip. Kept as ${tmp}."
        fi
      else
        mv "$tmp" "$dest"; res="OK"
        log "  saved ${dest} ($(du -h "$dest" | cut -f1))"
      fi;;
    401) warn "${name}: still HTTP 401 - wrong username/password."; rm -f "$tmp";;
    403) warn "${name}: HTTP 403 Forbidden - your IP/VPN may not be allowed."; rm -f "$tmp";;
    404) warn "${name}: HTTP 404 - not on the server (check the exact name/timestamp)."; rm -f "$tmp";;
    000) warn "${name}: could not reach the server: $(tail -n 1 "${tmp}.err" 2>/dev/null)"; rm -f "$tmp";;
    *)   warn "${name}: unexpected HTTP ${code}: $(tail -n 1 "${tmp}.err" 2>/dev/null)"; rm -f "$tmp";;
  esac
  rm -f "${tmp}.err"
  if [ "$res" = OK ]; then ok=$((ok+1)); else failed=$((failed+1)); fi
  RESULTS+=("$res|$label|$name")
done

echo ""
echo "Summary:"
printf '  %-8s %-20s %s\n' "RESULT" "LABEL" "FILE"
for r in "${RESULTS[@]}"; do
  IFS='|' read -r a b c <<< "$r"; printf '  %-8s %-20s %s\n' "$a" "$b" "$c"
done
echo ""
log "DONE. Downloaded: ${ok}, Skipped: ${skipped}, Failed: ${failed}. Folder: ${DOWNLOAD_DIR}"
[ "$failed" -eq 0 ]
