#!/usr/bin/env bash
#
# ASC Project — DEV04 run automation — SCRIPT 1 of 2 (the RUN)
# Run tag: DEV04_ASC_<YYYYMMDD> (defaults to TODAY; override with RUN_TAG=...)
# NO sudo (run as root inside the accounting-system container).
#
# This script ONLY runs the batch and names the files. The copy-to-bizmates.jp
# step is the separate SCRIPT 2 (02-move.sh), which discovers these files by
# their fixed per-month prefix, so the two scripts never need to agree on the
# time token inside the filename.
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
# The copy-to-bizmates.jp step AND the "Good day" report are SCRIPT 2 (02-move.sh).
#
# WARNING: SendJournalsDataCommand is run WITHOUT the no-send flag, so it SENDS to Freee.
#          Only run this against DEV04 with the ASC Freee credentials configured.
#
# Run from the Laravel app root (where artisan + storage/ live):
#   bash 01-run.sh                 # all months 02-12
#   MONTHS="02" bash 01-run.sh     # February only
#
# Produces files named: YYYYMM01_PRE_(DEV04_ASC_<YYYYMMDD>_<HHMMSS>).zip
#                       YYYYMM01_SEND_(DEV04_ASC_<YYYYMMDD>_<HHMMSS>).zip
# The fixed prefix (YYYYMM01_PRE_ / YYYYMM01_SEND_) is what SCRIPT 2 globs on.

set -euo pipefail

# ----------------------------------------------------------------------------
# Config
# ----------------------------------------------------------------------------
# Run tag defaults to today's date. Override for a re-run under an older tag:
#   RUN_TAG="DEV04_ASC_20261103" bash 01-run.sh
RUN_TAG="${RUN_TAG:-DEV04_ASC_$(date '+%Y%m%d')}"
MONTHS="${MONTHS:-02 03 04 05 06 07 08 09 10 11 12}"
YEAR="2026"

# ARCHIVE=1 (default): sweep existing *.log/*.zip into archives/ before running.
# ARCHIVE=0: skip the sweep so a second run ACCUMULATES with earlier months'
#            output (use this when running months in separate batches, e.g.
#            run 02 first, then  ARCHIVE=0 MONTHS="03 04 ... 12" bash 01-run.sh).
ARCHIVE="${ARCHIVE:-1}"

LOG_DIR="storage/logs"
PUB_DIR="storage/app/public"
LOG_FILE="${LOG_DIR}/laravel.log"

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
log() { echo "[$(date '+%H:%M:%S')] $*"; }
die() { echo "[ERROR] $*" >&2; exit 1; }

# Parse HHMMSS from the LAST timestamped line of laravel.log.
# Line format: [2026-11-01 15:44:32] local.INFO: ...  -> 154432
parse_last_time() {
  local file="$1"
  [ -f "$file" ] || die "Cannot parse time: ${file} does not exist."
  local t
  t="$(grep -oE '\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}\]' "$file" | tail -n 1)"
  [ -n "$t" ] || die "No timestamped line found in ${file}."
  echo "$t" | sed -E 's/.* ([0-9]{2}):([0-9]{2}):([0-9]{2})\]/\1\2\3/'
}

require_file() {
  [ -f "$1" ] || die "Expected file not found: $1 (a command likely failed before rename)."
}

# ----------------------------------------------------------------------------
# One-time archive of any existing logs/zips (your starting lines).
# Skipped when ARCHIVE=0 so separate-batch runs accumulate instead of sweeping
# away the earlier batch's zips.
# ----------------------------------------------------------------------------
mkdir -p "${LOG_DIR}/archives" "${PUB_DIR}/archives"
if [ "${ARCHIVE}" = "1" ]; then
  log "Archiving existing logs and zips..."
  mv ${LOG_DIR}/*.log "${LOG_DIR}/archives" 2>/dev/null || true
  mv ${PUB_DIR}/*.zip "${PUB_DIR}/archives" 2>/dev/null || true
else
  log "ARCHIVE=0 -> skipping archive sweep (accumulating with existing zips)."
fi

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
  rm -f "${LOG_FILE}"

  log "[${MM}] PRE: MonthlyRateCalculationPreCommand ${EXEC_DATE}"
  php artisan command:MonthlyRateCalculationPreCommand "${EXEC_DATE}"
  log "[${MM}] PRE: DailyRateCalculationPreCommand ${EXEC_DATE}"
  php artisan command:DailyRateCalculationPreCommand "${EXEC_DATE}"

  require_file "${LOG_FILE}"
  require_file "${PUB_DIR}/${YM}_pre.zip"

  PRE_TIME="$(parse_last_time "${LOG_FILE}")"
  PRE_LOG_NAME="laravel_${RUN_TAG}_${PRE_TIME}_PRE.log"
  PRE_ZIP_NAME="${YM}_PRE_(${RUN_TAG}_${PRE_TIME}).zip"

  log "[${MM}] PRE: renaming -> ${PRE_LOG_NAME} / ${PRE_ZIP_NAME}"
  mv "${LOG_FILE}" "${LOG_DIR}/${PRE_LOG_NAME}"
  mv "${PUB_DIR}/${YM}_pre.zip" "${PUB_DIR}/${PRE_ZIP_NAME}"

  # -------------------- SEND --------------------
  log "[${MM}] SEND: clearing stale laravel.log"
  rm -f "${LOG_FILE}"

  log "[${MM}] SEND: MonthlyRateCalculationCommand ${EXEC_DATE}"
  php artisan command:MonthlyRateCalculationCommand "${EXEC_DATE}"
  log "[${MM}] SEND: SendJournalsDataCommand ${SEND_DATE}  (SENDS TO FREEE)"
  php artisan command:SendJournalsDataCommand "${SEND_DATE}"

  require_file "${LOG_FILE}"
  require_file "${PUB_DIR}/${YM}.zip"

  SEND_TIME="$(parse_last_time "${LOG_FILE}")"
  SEND_LOG_NAME="laravel_${RUN_TAG}_${SEND_TIME}_SEND.log"
  SEND_ZIP_NAME="${YM}_SEND_(${RUN_TAG}_${SEND_TIME}).zip"

  log "[${MM}] SEND: renaming -> ${SEND_LOG_NAME} / ${SEND_ZIP_NAME}"
  mv "${LOG_FILE}" "${LOG_DIR}/${SEND_LOG_NAME}"
  mv "${PUB_DIR}/${YM}.zip" "${PUB_DIR}/${SEND_ZIP_NAME}"
done

echo ""
log "DONE (SCRIPT 1 — run). Generated zips are in ${PUB_DIR}."
log "Next: run SCRIPT 2 (02-move.sh) to copy them to bizmates.jp/public and write the report."
