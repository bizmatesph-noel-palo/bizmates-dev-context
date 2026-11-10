#!/usr/bin/env bash
#
# merge-to-new-branch.sh — for each repo, check whether SOURCE merges cleanly
# into TARGET; if it does, ask for a new branch name, create that branch from
# TARGET and merge SOURCE into it. Repos with a conflict are left untouched.
#
# Example (sync main into dev04, the sync/dev04/main-to-dev04-YYYYMMDD pattern):
#   bash merge-to-new-branch.sh main deployment/dev04
#
# Safety:
#   - Per repo: a repo with a conflict gets NOTHING (no branch, no commit).
#   - Never pushes. The new branch exists only locally; push it yourself after review.
#   - Never overwrites: if the name already exists locally or on origin, it asks
#     for another name (or skips the repo when it cannot ask).
#   - Never touches your current checkout, working tree or uncommitted files:
#     the merge runs in a temporary worktree that is removed afterwards.
#   - The new branch has no upstream, so a plain `git pull`/`git push` on it can't
#     accidentally hit main/master/deployment branches.
#   - The merge commit uses your normal git identity; hooks are not skipped.
#
# Usage:
#   bash merge-to-new-branch.sh SOURCE TARGET [options]
#     SOURCE  branch to merge IN (e.g. main, or @default)
#     TARGET  branch the new branch STARTS FROM (e.g. deployment/dev04)
#   Branches resolve as origin/<name> first, then as given. "@default" = the
#   repo's default branch (main, or master for bizmates.jp). If "main"/"master"
#   doesn't exist in a repo, the other is tried.
#
# Repos (first match wins): -c FILE (JSON), -f FILE (text "name [path]"),
#   REPOS="a b" env, or check-conflicts.repos.json next to this script.
#   JSON "branch_map" (e.g. {"main":"master"}) works as in check-conflicts.sh.
#
# Options:
#   -n, --name NAME   use NAME for every repo (no prompt). If it exists in a
#                     repo, that repo is skipped (never overwritten).
#   -y, --yes         accept the suggested name for every repo (no prompt)
#   -r, --root DIR    folder containing the repos (default ~/bizmates)
#   --no-fetch        don't fetch from origin first
#
# Exit code: 0 = every clean repo got its branch and none conflicted,
#            1 = at least one repo had a conflict or was skipped,
#            2 = a repo/branch could not be checked or a merge failed.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG=""; REPOS_FILE=""; ROOT="${REPOS_ROOT:-}"; FETCH=1
FIXED_NAME=""; AUTO_YES=0
POS=()

usage() { sed -n '2,/^set -uo/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d'; exit 2; }
die()   { echo "[ERROR] $*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    -c|--config)     CONFIG="${2:-}"; shift 2;;
    -f|--repos-file) REPOS_FILE="${2:-}"; shift 2;;
    -r|--root)       ROOT="${2:-}"; shift 2;;
    -n|--name)       FIXED_NAME="${2:-}"; shift 2;;
    -y|--yes)        AUTO_YES=1; shift;;
    --no-fetch)      FETCH=0; shift;;
    -h|--help)       usage;;
    -*)              die "Unknown option: $1";;
    *)               POS+=("$1"); shift;;
  esac
done
[ "${#POS[@]}" -eq 2 ] || usage
SOURCE="${POS[0]}"; TARGET="${POS[1]}"
command -v git >/dev/null || die "git is not installed."

# Prompts read from the original stdin (fd 3), so git commands can't eat answers.
exec 3<&0

# ----------------------------------------------------------------------------
# Repo list -> NAMES[], PATHS[], MAPS[]  (same formats as check-conflicts.sh)
# ----------------------------------------------------------------------------
NAMES=(); PATHS=(); MAPS=()
if [ -z "$CONFIG" ] && [ -z "$REPOS_FILE" ] && [ -z "${REPOS:-}" ] \
   && [ -f "${SCRIPT_DIR}/check-conflicts.repos.json" ]; then
  CONFIG="${SCRIPT_DIR}/check-conflicts.repos.json"
fi
if [ -n "$CONFIG" ]; then
  [ -f "$CONFIG" ] || die "Config not found: $CONFIG"
  command -v python3 >/dev/null || die "python3 is needed to read a JSON config."
  parsed="$(python3 - "$CONFIG" <<'PY'
import json, sys
cfg = json.load(open(sys.argv[1]))
repos = cfg if isinstance(cfg, list) else cfg.get("repos", [])
if isinstance(cfg, dict) and cfg.get("root"):
    print("ROOT\x1f" + cfg["root"])
for r in repos:
    if isinstance(r, str):
        r = {"name": r}
    m = ",".join(f"{k}={v}" for k, v in (r.get("branch_map") or {}).items())
    print("REPO\x1f" + r["name"] + "\x1f" + (r.get("path") or "") + "\x1f" + m)
PY
)" || die "Could not parse $CONFIG (is it valid JSON?)"
  while IFS=$'\x1f' read -r kind a b c; do
    case "$kind" in
      ROOT) [ -n "$ROOT" ] || ROOT="$a";;
      REPO) NAMES+=("$a"); PATHS+=("$b"); MAPS+=("$c");;
    esac
  done <<< "$parsed"
elif [ -n "$REPOS_FILE" ]; then
  [ -f "$REPOS_FILE" ] || die "Repos file not found: $REPOS_FILE"
  while read -r name path _; do
    name="${name%%#*}"; [ -n "$name" ] || continue
    NAMES+=("$name"); PATHS+=("${path:-}"); MAPS+=("")
  done < <(tr -d '\r' < "$REPOS_FILE")
elif [ -n "${REPOS:-}" ]; then
  for name in ${REPOS//,/ }; do NAMES+=("$name"); PATHS+=(""); MAPS+=(""); done
else
  die "No repos given. Use --config, --repos-file, or REPOS=\"...\"."
fi
[ "${#NAMES[@]}" -gt 0 ] || die "The repo list is empty."
ROOT="${ROOT:-$HOME/bizmates}"; ROOT="${ROOT/#\~/$HOME}"

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
TMPROOT="$(mktemp -d)"
CURRENT_WT=""; CURRENT_REPO=""
cleanup() {
  if [ -n "$CURRENT_WT" ] && [ -n "$CURRENT_REPO" ]; then
    git -C "$CURRENT_WT" merge --abort >/dev/null 2>&1
    git -C "$CURRENT_REPO" worktree remove --force "$CURRENT_WT" >/dev/null 2>&1
    git -C "$CURRENT_REPO" worktree prune >/dev/null 2>&1
  fi
  rm -rf "$TMPROOT"
}
trap cleanup EXIT INT TERM

drop_worktree() {
  [ -n "$CURRENT_WT" ] || return
  git -C "$CURRENT_WT" merge --abort >/dev/null 2>&1
  git -C "$CURRENT_REPO" worktree remove --force "$CURRENT_WT" >/dev/null 2>&1
  git -C "$CURRENT_REPO" worktree prune >/dev/null 2>&1
  CURRENT_WT=""
}

# Resolve a branch name in repo $1 (map in $3). Prints "<ref>|<note>" or nothing.
resolve() {
  local repo="$1" want="$2" map="$3" b note="" pair
  b="$want"
  for pair in ${map//,/ }; do
    [ "${pair%%=*}" = "$want" ] && { b="${pair#*=}"; note="mapped $want -> $b"; }
  done
  if [ "$b" = "@default" ]; then
    local d; d="$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD)" \
      || { git -C "$repo" remote set-head origin --auto >/dev/null 2>&1; \
           d="$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD)"; }
    [ -n "$d" ] && echo "$d|default branch is ${d#origin/}"
    return
  fi
  if git -C "$repo" rev-parse --verify -q "origin/$b^{commit}" >/dev/null; then echo "origin/$b|$note"; return; fi
  if git -C "$repo" rev-parse --verify -q "$b^{commit}" >/dev/null; then echo "$b|$note"; return; fi
  local alt=""
  [ "$b" = "main" ] && alt="master"; [ "$b" = "master" ] && alt="main"
  if [ -n "$alt" ] && git -C "$repo" rev-parse --verify -q "origin/$alt^{commit}" >/dev/null; then
    echo "origin/$alt|no $b here, used $alt"
  fi
}

# Last path segment of a branch: deployment/dev04 -> dev04, origin/main -> main.
short() { local s="${1#origin/}"; echo "${s##*/}"; }

# Does branch name $2 already exist in repo $1 (locally or on origin)?
branch_exists() {
  local repo="$1" name="$2"
  git -C "$repo" show-ref --verify -q "refs/heads/$name" && { echo "local"; return 0; }
  git -C "$repo" show-ref --verify -q "refs/remotes/origin/$name" && { echo "origin"; return 0; }
  if [ "$FETCH" = 1 ] && [ -n "$(git -C "$repo" ls-remote --heads origin "$name" 2>/dev/null)" ]; then
    echo "origin"; return 0
  fi
  return 1
}

# Ask for (or decide) the new branch name for repo $1. Prints the name, or
# nothing to skip. Re-asks on invalid or existing names; never overwrites.
pick_name() {
  local repo="$1" suggested="$2" name where ans
  if [ -n "$FIXED_NAME" ]; then
    name="$FIXED_NAME"
    git check-ref-format --branch "$name" >/dev/null 2>&1 || { echo "  invalid branch name: $name" >&2; return; }
    if where="$(branch_exists "$repo" "$name")"; then
      echo "  '$name' already exists ($where) - skipping this repo (never overwrite)." >&2; return
    fi
    echo "$name"; return
  fi
  if [ "$AUTO_YES" = 1 ]; then
    name="$suggested"
    if where="$(branch_exists "$repo" "$name")"; then
      echo "  suggested '$name' already exists ($where) - skipping (never overwrite). Run without -y to pick a name." >&2; return
    fi
    echo "$name"; return
  fi
  while true; do
    printf '  New branch name [%s] (Enter = accept, s = skip this repo): ' "$suggested" >&2
    if ! IFS= read -r ans <&3; then echo "" >&2; echo "  no input available - skipping this repo." >&2; return; fi
    ans="$(echo "$ans" | tr -d '\r' | xargs)"
    case "$ans" in
      s|S|skip) echo "  skipped by you." >&2; return;;
      "")       name="$suggested";;
      *)        name="$ans";;
    esac
    if ! git check-ref-format --branch "$name" >/dev/null 2>&1; then
      echo "  '$name' is not a valid branch name - try again." >&2; continue
    fi
    if where="$(branch_exists "$repo" "$name")"; then
      echo "  '$name' already exists ($where) - it will NOT be overwritten. Pick another name." >&2; continue
    fi
    echo "$name"; return
  done
}

# ----------------------------------------------------------------------------
# Per repo
# ----------------------------------------------------------------------------
SUMMARY=(); rc_any=0
note_rc() { [ "$1" -gt "$rc_any" ] && rc_any="$1"; }

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  repo="${PATHS[$i]:-$ROOT/$name}"; repo="${repo/#\~/$HOME}"
  echo ""
  echo "=== ${name} (${repo}) ==="

  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    echo "  not a git repository"; SUMMARY+=("$name|ERROR|not a git repo"); note_rc 2; continue
  fi
  if [ -z "$(git -C "$repo" config user.name)" ] || [ -z "$(git -C "$repo" config user.email)" ]; then
    echo "  git user.name/user.email not set for this repo - can't create the merge commit."
    SUMMARY+=("$name|ERROR|git identity not set"); note_rc 2; continue
  fi
  [ "$FETCH" = 1 ] && git -C "$repo" fetch -q origin 2>&1 | sed 's/^/  fetch: /'

  src_r="$(resolve "$repo" "$SOURCE" "${MAPS[$i]}")"
  tgt_r="$(resolve "$repo" "$TARGET" "${MAPS[$i]}")"
  if [ -z "$src_r" ] || [ -z "$tgt_r" ]; then
    missing=""; [ -z "$src_r" ] && missing="$SOURCE"; [ -z "$tgt_r" ] && missing="${missing:+$missing, }$TARGET"
    echo "  branch not found: ${missing}"; SUMMARY+=("$name|ERROR|branch not found: $missing"); note_rc 2; continue
  fi
  SRC="${src_r%%|*}"; TGT="${tgt_r%%|*}"
  for n in "${src_r#*|}" "${tgt_r#*|}"; do [ -n "$n" ] && echo "  note: $n"; done
  if ! git -C "$repo" merge-base "$SRC" "$TGT" >/dev/null 2>&1; then
    echo "  no common ancestor"; SUMMARY+=("$name|ERROR|no common ancestor"); note_rc 2; continue
  fi
  echo "  ${SRC#origin/} is $(git -C "$repo" rev-list --count "$TGT..$SRC") commits ahead of ${TGT#origin/}"
  echo "  checking: merge ${SRC} into ${TGT} ..."

  # 1) Dry-run merge on a detached copy of TARGET.
  CURRENT_REPO="$repo"; CURRENT_WT="$TMPROOT/wt-$i"
  if ! git -C "$repo" worktree add -q --detach "$CURRENT_WT" "$TGT" >"$TMPROOT/wt.log" 2>&1; then
    echo "  could not create temp worktree: $(tail -n 1 "$TMPROOT/wt.log")"
    CURRENT_WT=""; SUMMARY+=("$name|ERROR|temp worktree failed"); note_rc 2; continue
  fi
  if ! git -C "$CURRENT_WT" -c user.name=conflict-check -c user.email=conflict-check@local \
         merge -q --no-commit --no-ff "$SRC" >"$TMPROOT/merge.log" 2>&1; then
    files="$(git -C "$CURRENT_WT" diff --name-only --diff-filter=U)"
    drop_worktree
    if [ -n "$files" ]; then
      echo "  CONFLICT - nothing done for this repo. Conflicting files:"
      echo "$files" | sed 's/^/    - /'
      SUMMARY+=("$name|CONFLICT|nothing done ($(echo "$files" | wc -l) file(s))"); note_rc 1
    else
      echo "  merge check failed: $(tail -n 1 "$TMPROOT/merge.log")"
      SUMMARY+=("$name|ERROR|merge check failed"); note_rc 2
    fi
    continue
  fi
  git -C "$CURRENT_WT" merge --abort >/dev/null 2>&1
  echo "  OK: no conflicts."

  # 2) Pick the new branch name (never an existing one).
  suggested="sync/$(short "$TGT")/$(short "$SRC")-to-$(short "$TGT")-$(date '+%Y%m%d')"
  new="$(pick_name "$repo" "$suggested")"
  if [ -z "$new" ]; then
    drop_worktree; SUMMARY+=("$name|SKIPPED|no branch created"); note_rc 1; continue
  fi

  # 3) Create the branch at TARGET (in the temp worktree, no upstream) and merge.
  if ! git -C "$CURRENT_WT" checkout -q -b "$new" >"$TMPROOT/co.log" 2>&1; then
    echo "  could not create '$new': $(tail -n 1 "$TMPROOT/co.log")"
    drop_worktree; SUMMARY+=("$name|ERROR|could not create $new"); note_rc 2; continue
  fi
  msg="Merge ${SRC#origin/} into ${new} (from ${TGT#origin/})"
  if git -C "$CURRENT_WT" merge -q --no-ff -m "$msg" "$SRC" >"$TMPROOT/merge2.log" 2>&1; then
    head="$(git -C "$CURRENT_WT" rev-parse --short HEAD)"
    drop_worktree
    echo "  created branch '$new' at $head (local only, not pushed)"
    SUMMARY+=("$name|CREATED|$new @ $head")
  else
    echo "  merge failed unexpectedly: $(tail -n 1 "$TMPROOT/merge2.log")"
    git -C "$CURRENT_WT" merge --abort >/dev/null 2>&1
    git -C "$CURRENT_WT" checkout -q --detach >/dev/null 2>&1
    drop_worktree
    # Remove only the branch this run just created; it still points at TARGET.
    if [ "$(git -C "$repo" rev-parse "refs/heads/$new" 2>/dev/null)" = "$(git -C "$repo" rev-parse "$TGT^{commit}")" ]; then
      git -C "$repo" branch -q -D "$new" >/dev/null 2>&1 && echo "  removed the empty branch '$new' created by this run."
    fi
    SUMMARY+=("$name|ERROR|merge failed, see above"); note_rc 2
  fi
done

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
echo ""
echo "Summary: merge ${SOURCE} into a new branch from ${TARGET}   (nothing was pushed)"
printf '  %-38s %-9s %s\n' "REPO" "RESULT" "DETAIL"
for row in "${SUMMARY[@]}"; do
  IFS='|' read -r n res det <<< "$row"
  printf '  %-38s %-9s %s\n' "$n" "$res" "$det"
done
created=0; for row in "${SUMMARY[@]}"; do [[ "$row" == *"|CREATED|"* ]] && created=1; done
if [ "$created" = 1 ]; then
  echo ""
  echo "Review, then push a branch yourself when ready:"
  echo "  git -C <repo> log --oneline -3 <branch>"
  echo "  git -C <repo> push -u origin <branch>"
fi
exit "$rc_any"
