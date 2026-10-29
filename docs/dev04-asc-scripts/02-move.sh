#!/usr/bin/env bash
#
# ASC Project — DEV04 run automation — SCRIPT 2 of 2 (the MOVE + REPORT)
# Run AFTER SCRIPT 1 (01-run.sh).
#
# This script does two things:
#   1. Copy each month's generated zips to bizmates.jp/public.
#   2. Write the timestamped "Good day" report, with the ACTUAL filenames copied
#      (links only make sense once the files are on the download surface).
#
# WHY GLOB-BASED (the workaround for the naming inconsistency):
#   SCRIPT 1 names each zip with a time token parsed from laravel.log
#   (e.g. ..._143757.zip), which is NOT known ahead of time. Rather than
#   hard-code P02/S02-style tokens that would drift, this script DISCOVERS each
#   month's file by its FIXED, unique prefix:
#       YYYYMM01_PRE_(*).zip   and   YYYYMM01_SEND_(*).zip
#   and copies whatever it finds. So the two scripts never need to agree on the
#   token inside the parentheses.
#
# Safety: for each (month, phase) it requires EXACTLY ONE matching zip.
#   - 0 matches  -> warn + skip (SCRIPT 1 did not produce it for that month)
#   - >1 matches -> warn + skip (ambiguous: stale/leftover files — do not guess)
#
# Paths default to the /home/bizmates layout (correct for the DEV04 container).
# Override only if your layout differs:
#   SRC_PUBLIC=/path/storage/app/public DST_PUBLIC=/path/public bash 02-move.sh
#   MONTHS="02" bash 02-move.sh     # move February only

set -uo pipefail   # NOTE: no -e; a per-month skip must not abort the whole move.

# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------
MONTHS="${MONTHS:-02 03 04 05 06 07 08 09 10 11 12}"
YEAR="2026"

# Source = where SCRIPT 1 wrote the renamed zips (accounting app storage).
# Destination = bizmates.jp public download dir. Both correct for DEV04.
SRC_PUBLIC="${SRC_PUBLIC:-/home/bizmates/accounting_related_system_for_freee/storage/app/public}"
DST_PUBLIC="${DST_PUBLIC:-/home/bizmates/bizmates.jp/public}"

# Public base URL for the report links.
URL_BASE="${URL_BASE:-https://dev04.dev.bizmates.jp}"

# Report file (timestamped). Written to REPORT_DIR, which defaults to a writable
# location (storage/app/public) because the app root is often not writable by the
# running user. Override with REPORT_DIR=/some/path if you want it elsewhere.
NOW_STAMP="$(date '+%Y%m%d_%H%M%S')"
REPORT_DIR="${REPORT_DIR:-${SRC_PUBLIC}}"
REPORT_FILE="${REPORT_DIR}/dev04-asc-report-${NOW_STAMP}.txt"

log()  { echo "[$(date '+%H:%M:%S')] $*"; }
warn() { echo "[WARN] $*" >&2; }

# Use sudo only if it exists AND we are not already root. In the DEV04 container
# the shell is root and sudo is not installed, so SUDO resolves to empty and the
# commands run directly.
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
else
  SUDO=""
fi

copied=0
skipped=0

# Collects the actual basename copied, keyed per month: "MM|<basename>".
COPIED_PRE=()
COPIED_SEND=()

# ----------------------------------------------------------------------------
# Preflight
# ----------------------------------------------------------------------------
[ -d "${SRC_PUBLIC}" ] || { echo "[ERROR] Source dir not found: ${SRC_PUBLIC}" >&2; exit 1; }
${SUDO} mkdir -p "${DST_PUBLIC}"

# ----------------------------------------------------------------------------
# Resolve + copy exactly one match for a (month, phase) prefix, or warn+skip.
# Sets COPIED_BASENAME to the copied basename on success (empty on skip).
#   $1 = YM prefix (e.g. 20260201)
#   $2 = phase label PRE|SEND
# ----------------------------------------------------------------------------
copy_one() {
  local ym="$1" phase="$2"
  local pattern="${SRC_PUBLIC}/${ym}_${phase}_("*").zip"

  shopt -s nullglob
  local matches=( ${pattern} )
  shopt -u nullglob

  if [ "${#matches[@]}" -eq 0 ]; then
    warn "${ym} ${phase}: no file matched '${ym}_${phase}_(*).zip' in ${SRC_PUBLIC} — skipping (did SCRIPT 1 run this month?)."
    skipped=$((skipped+1))
    return
  fi

  if [ "${#matches[@]}" -gt 1 ]; then
    warn "${ym} ${phase}: ${#matches[@]} files matched '${ym}_${phase}_(*).zip' (ambiguous — likely leftover from a prior run). Skipping rather than guessing:"
    printf '         %s\n' "${matches[@]}" >&2
    skipped=$((skipped+1))
    return
  fi

  local src="${matches[0]}"
  local base
  base="$(basename "${src}")"
  log "copy ${base}"
  ${SUDO} cp "${src}" "${DST_PUBLIC}/${base}"
  copied=$((copied+1))
  COPIED_BASENAME="${base}"   # hand back to caller
}

# ----------------------------------------------------------------------------
# Move loop
# ----------------------------------------------------------------------------
log "Copying generated zips: ${SRC_PUBLIC}  ->  ${DST_PUBLIC}"
for MM in ${MONTHS}; do
  YM="${YEAR}${MM}01"
  echo "###=== ${MM}01 ===###"

  COPIED_BASENAME=""
  copy_one "${YM}" "PRE"
  [ -n "${COPIED_BASENAME}" ] && COPIED_PRE+=("${MM}|${COPIED_BASENAME}")

  COPIED_BASENAME=""
  copy_one "${YM}" "SEND"
  [ -n "${COPIED_BASENAME}" ] && COPIED_SEND+=("${MM}|${COPIED_BASENAME}")
done

# ----------------------------------------------------------------------------
# Month-number -> captured-month label (exeDate captures the PREVIOUS month)
# ----------------------------------------------------------------------------
captured_label() {
  case "$1" in
    02) echo "January data (2026/01/01 to 2026/01/31)";;
    03) echo "February data (2026/02/01 to 2026/02/28)";;
    04) echo "March data (2026/03/01 to 2026/03/31)";;
    05) echo "April data (2026/04/01 to 2026/04/30)";;
    06) echo "May data (2026/05/01 to 2026/05/31)";;
    07) echo "June data (2026/06/01 to 2026/06/30)";;
    08) echo "July data (2026/07/01 to 2026/07/31)";;
    09) echo "August data (2026/08/01 to 2026/08/31)";;
    10) echo "September data (2026/09/01 to 2026/09/30)";;
    11) echo "October data (2026/10/01 to 2026/10/31)";;
    12) echo "November data (2026/11/01 to 2026/11/30)";;
    *)  echo "unknown month ${1}";;
  esac
}

# ----------------------------------------------------------------------------
# Write the "Good day" report with the ACTUAL copied filenames
# ----------------------------------------------------------------------------
log "Writing report: ${REPORT_FILE}"
{
  echo "Good day, Team!"
  echo ""
  echo "cc: @Hayato Kuroda-san, @Roi Patrick Florentino-san, @Kenta Miyachi-san"
  echo ""
  echo "ASC Project Update:"
  echo ""
  echo "We have successfully rerun the commands on DEV04 for the following execution dates"
  echo ""
  for MM in ${MONTHS}; do
    echo "${YEAR}/${MM}/01 captures the $(captured_label "${MM}")."
  done
  echo ""
  echo "Below are the links to the files generated during the 2026-06-11 execution:"
  echo ""
  for MM in ${MONTHS}; do
    pre_zip=""
    send_zip=""
    for e in "${COPIED_PRE[@]:-}";  do [ "${e%%|*}" = "${MM}" ] && pre_zip="${e#*|}"; done
    for e in "${COPIED_SEND[@]:-}"; do [ "${e%%|*}" = "${MM}" ] && send_zip="${e#*|}"; done
    echo "$(captured_label "${MM}"):"
    [ -n "${pre_zip}" ]  && echo "${URL_BASE}/${pre_zip}"
    [ -n "${send_zip}" ] && echo "${URL_BASE}/${send_zip}"
    echo ""
  done
  echo "Thank you!"
} > "${REPORT_FILE}"

echo ""
log "DONE (SCRIPT 2 — move + report). Copied: ${copied}, Skipped: ${skipped}."
log "Report written to: $(pwd)/${REPORT_FILE}"
[ "${skipped}" -eq 0 ] || warn "Some month/phase files were skipped — review the warnings above."
