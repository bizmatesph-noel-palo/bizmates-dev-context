#!/usr/bin/env bash
#
# ASC Project — DEV04 run automation
# Run tag: DEV04_ASC_20260611 (hard-coded, per runbook)
#
# What this does, per month (02 -> 12):
#   1. rm the stale laravel.log (artisan recreates it)
#   2. run the PRE pair (Monthly + Daily Pre)
#   3. verify laravel.log + the _pre zip exist
#   4. parse HHMMSS from the LAST line of laravel.log and rename log + zip
#   5. rm laravel.log again
#   6. run the SEND pair (Monthly + SendJournals)  <-- SENDS TO FREEE (no no-send flag)
#   7. verify laravel.log + the send zip exist
#   8. parse HHMMSS from the LAST line and rename log + zip
# Then copies every renamed zip to bizmates.jp/public and writes a timestamped report.
#
# WARNING: SendJournalsDataCommand is run WITHOUT the no-send flag, so it SENDS to Freee.
#          Only run this against DEV04 with the ASC Freee credentials configured.
#
# Run inside the accounting-system container (make php-root), from the Laravel app root.
#   bash dev04-asc-run.sh
# Or run only some months:
#   MONTHS="10 11 12" bash dev04-asc-run.sh

set -euo pipefail

# ----------------------------------------------------------------------------
# Config (hard-coded run tag per request)
# ----------------------------------------------------------------------------
RUN_TAG="DEV04_ASC_20260611"
MONTHS="${MONTHS:-02 03 04 05 06 07 08 09 10 11 12}"
YEAR="2026"

APP_ROOT="/home/bizmates/accounting_related_system_for_freee"
BIZMATES_PUBLIC="/home/bizmates/bizmates.jp/public"

LOG_DIR="storage/logs"
PUB_DIR="storage/app/public"
LOG_FILE="${LOG_DIR}/laravel.log"

# Report file (dev-context side). Written on the host-mounted path if present,
# otherwise next to the app. Timestamped so each run is distinct.
NOW_STAMP="$(date '+%Y%m%d_%H%M%S')"
REPORT_FILE="dev04-asc-report-${NOW_STAMP}.txt"

# Collects "MM|PRE|<zip>" and "MM|SEND|<zip>" lines for the report.
RENAMED_PRE=()
RENAMED_SEND=()

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

# Parse HHMMSS from the LAST line of laravel.log.
# Laravel line format: [2026-11-01 15:44:32] local.INFO: ...
# Extracts the HH:MM:SS of the last timestamped line and strips the colons -> 154432.
parse_last_time() {
  local file="$1"
  [ -f "$file" ] || die "Cannot parse time: ${file} does not exist."
  local t
  t="$(grep -oE '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' "$file" | tail -n 1)"
  [ -n "$t" ] || die "No timestamped line found in ${file}."
  # t looks like: [2026-11-01 15:44:32]  -> take HH:MM:SS -> strip ':'
  echo "$t" | sed -E 's/.* ([0-9]{2}):([0-9]{2}):([0-9]{2})\]/\1\2\3/'
}

require_file() {
  [ -f "$1" ] || die "Expected file not found: $1 (a command likely failed before rename)."
}

# ----------------------------------------------------------------------------
# One-time archive of any existing logs/zips (your starting lines)
# ----------------------------------------------------------------------------
log "Archiving existing logs and zips..."
mkdir -p "${LOG_DIR}/archives" "${PUB_DIR}/archives"
# '|| true' so an empty glob (nothing to archive) does not abort under set -e.
sudo mv ${LOG_DIR}/*.log "${LOG_DIR}/archives" 2>/dev/null || true
sudo mv ${PUB_DIR}/*.zip "${PUB_DIR}/archives" 2>/dev/null || true

# ----------------------------------------------------------------------------
# Per-month run
# ----------------------------------------------------------------------------
for MM in ${MONTHS}; do
  EXEC_DATE="${YEAR}-${MM}-01"      # artisan date form (YYYY-MM-DD)
  SEND_DATE="${YEAR}/${MM}/01"      # SendJournals date form (YYYY/MM/DD)
  YM="${YEAR}${MM}01"               # zip name prefix, e.g. 20260201

  echo ""
  echo "########################################################################"
  echo "##=== ${MM}/01  (exeDate ${EXEC_DATE}) ==="
  echo "########################################################################"

  # -------------------- PRE --------------------
  log "[${MM}] PRE: clearing stale laravel.log"
  sudo rm -f "${LOG_FILE}"

  log "[${MM}] PRE: MonthlyRateCalculationPreCommand ${EXEC_DATE}"
  php artisan command:MonthlyRateCalculationPreCommand "${EXEC_DATE}"
  log "[${MM}] PRE: DailyRateCalculationPreCommand ${EXEC_DATE}"
  php artisan command:DailyRateCalculationPreCommand "${EXEC_DATE}"

  # Both PRE commands finished -> verify outputs exist, then rename.
  require_file "${LOG_FILE}"
  require_file "${PUB_DIR}/${YM}_pre.zip"

  PRE_TIME="$(parse_last_time "${LOG_FILE}")"
  PRE_LOG_NAME="laravel_${RUN_TAG}_${PRE_TIME}_PRE.log"
  PRE_ZIP_NAME="${YM}_PRE_(${RUN_TAG}_${PRE_TIME}).zip"

  log "[${MM}] PRE: renaming -> ${PRE_LOG_NAME} / ${PRE_ZIP_NAME}"
  sudo mv "${LOG_FILE}" "${LOG_DIR}/${PRE_LOG_NAME}"
  sudo mv "${PUB_DIR}/${YM}_pre.zip" "${PUB_DIR}/${PRE_ZIP_NAME}"
  RENAMED_PRE+=("${MM}|${PRE_ZIP_NAME}")

  # -------------------- SEND --------------------
  log "[${MM}] SEND: clearing stale laravel.log"
  sudo rm -f "${LOG_FILE}"

  log "[${MM}] SEND: MonthlyRateCalculationCommand ${EXEC_DATE}"
  php artisan command:MonthlyRateCalculationCommand "${EXEC_DATE}"
  log "[${MM}] SEND: SendJournalsDataCommand ${SEND_DATE}  (SENDS TO FREEE)"
  php artisan command:SendJournalsDataCommand "${SEND_DATE}"

  # Both SEND commands finished -> verify outputs exist, then rename.
  require_file "${LOG_FILE}"
  require_file "${PUB_DIR}/${YM}.zip"

  SEND_TIME="$(parse_last_time "${LOG_FILE}")"
  SEND_LOG_NAME="laravel_${RUN_TAG}_${SEND_TIME}_SEND.log"
  SEND_ZIP_NAME="${YM}_SEND_(${RUN_TAG}_${SEND_TIME}).zip"

  log "[${MM}] SEND: renaming -> ${SEND_LOG_NAME} / ${SEND_ZIP_NAME}"
  sudo mv "${LOG_FILE}" "${LOG_DIR}/${SEND_LOG_NAME}"
  sudo mv "${PUB_DIR}/${YM}.zip" "${PUB_DIR}/${SEND_ZIP_NAME}"
  RENAMED_SEND+=("${MM}|${SEND_ZIP_NAME}")
done

# ----------------------------------------------------------------------------
# Move generated zips to bizmates.jp/public (download surface)
# ----------------------------------------------------------------------------
echo ""
log "Copying generated zips to ${BIZMATES_PUBLIC}"
for entry in "${RENAMED_PRE[@]}" "${RENAMED_SEND[@]}"; do
  zip="${entry#*|}"
  sudo cp "${APP_ROOT}/${PUB_DIR}/${zip}" "${BIZMATES_PUBLIC}/${zip}"
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
# Write the "Good day" report with the ACTUAL generated filenames
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
    for e in "${RENAMED_PRE[@]}";  do [ "${e%%|*}" = "${MM}" ] && pre_zip="${e#*|}"; done
    for e in "${RENAMED_SEND[@]}"; do [ "${e%%|*}" = "${MM}" ] && send_zip="${e#*|}"; done
    echo "$(captured_label "${MM}"):"
    [ -n "${pre_zip}" ]  && echo "https://dev04.dev.bizmates.jp/${pre_zip}"
    [ -n "${send_zip}" ] && echo "https://dev04.dev.bizmates.jp/${send_zip}"
    echo ""
  done
  echo "Thank you!"
} > "${REPORT_FILE}"

echo ""
log "DONE. Report written to: $(pwd)/${REPORT_FILE}"
log "Generated zips are in ${PUB_DIR} and copied to ${BIZMATES_PUBLIC}"
