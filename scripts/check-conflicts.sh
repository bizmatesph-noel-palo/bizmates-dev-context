#!/usr/bin/env bash
#
# check-conflicts.sh ? check whether merging one branch into another would
# conflict, across several git repositories. READ-ONLY for your checkouts:
# it never touches the branch you have checked out, your working tree, or
# your index. It fetches from origin and merges in a throwaway location.
#
# Usage:
#   bash check-conflicts.sh SOURCE TARGET [options]
#     SOURCE  branch to merge FROM (e.g. deployment/dev04)
#     TARGET  branch to merge INTO (e.g. main, or @default)
#
#   Branch names are looked up as origin/<name> first, then as given (so a
#   local branch, tag or commit also works).
#   "@default" means the repo's own default branch (origin/HEAD): main for
#   most repos, master for bizmates.jp. Use it when repos differ.
#   If "main" or "master" does not exist in a repo, the other is tried
#   automatically and a note is printed.
#
# Which repos to check (first match wins):
#   -c, --config FILE      JSON config (see check-conflicts.repos.json)
#   -f, --repos-file FILE  text file, one repo per line: "name [path]"
#   REPOS="a b c"          env var, repo names (space or comma separated)
#   default                ./check-conflicts.repos.json next to this script
#
# Options:
#   -r, --root DIR   folder containing the repos (default ~/bizmates,
#                    or "root" in the JSON, or REPOS_ROOT env)
#   --no-fetch       don't fetch from origin first (use what you have)
#   -q, --quiet      only print the summary table
#
# JSON config shape:
#   {
#     "root": "~/bizmates",
#     "repos": [
#       "MBTI_backend",
#       { "name": "bizmates.jp", "branch_map": { "main": "master" } },
#       { "name": "other", "path": "/abs/path/to/repo" }
#     ]
#   }
#   branch_map renames a branch for that repo only (e.g. main -> master).
#
# Exit code: 0 = no conflicts anywhere, 1 = at least one conflict,
#            2 = a repo or branch could not be checked.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG=""; REPOS_FILE=""; ROOT="${REPOS_ROOT:-}"; FETCH=1; QUIET=0
POS=()

usage() { sed -n '2,/^set -uo/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d'; exit 2; }
die()   { echo "[ERROR] $*" >&2; exit 2; }
say()   { [ "$QUIET" = 1 ] || echo "$*"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -c|--config)     CONFIG="${2:-}"; shift 2;;
    -f|--repos-file) REPOS_FILE="${2:-}"; shift 2;;
    -r|--root)       ROOT="${2:-}"; shift 2;;
    --no-fetch)      FETCH=0; shift;;
    -q|--quiet)      QUIET=1; shift;;
    -h|--help)       usage;;
    -*)              die "Unknown option: $1";;
    *)               POS+=("$1"); shift;;
  esac
done
[ "${#POS[@]}" -eq 2 ] || usage
SOURCE="${POS[0]}"; TARGET="${POS[1]}"

command -v git >/dev/null || die "git is not installed."

# ----------------------------------------------------------------------------
# Load the repo list -> arrays NAMES[], PATHS[], MAPS[] (MAPS = "from=to,...")
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
    # \x1f (unit separator) is used because bash `read` collapses empty tab fields
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

ROOT="${ROOT:-$HOME/bizmates}"
ROOT="${ROOT/#\~/$HOME}"

# ----------------------------------------------------------------------------
# Merge engine: git >= 2.38 can merge without a worktree; older git uses a
# throwaway worktree. Both use git's real merge (handles criss-cross history).
# ----------------------------------------------------------------------------
gv="$(git --version | grep -oE '[0-9]+\.[0-9]+' | head -n 1)"
if [ "$(printf '%s\n2.38\n' "$gv" | sort -V | head -n 1)" = "2.38" ]; then
  ENGINE="merge-tree"
else
  ENGINE="worktree"
fi

TMPROOT="$(mktemp -d)"
CURRENT_WT=""; CURRENT_REPO=""
cleanup() {
  if [ -n "$CURRENT_WT" ] && [ -n "$CURRENT_REPO" ]; then
    git -C "$CURRENT_REPO" worktree remove --force "$CURRENT_WT" >/dev/null 2>&1
    git -C "$CURRENT_REPO" worktree prune >/dev/null 2>&1
  fi
  rm -rf "$TMPROOT"
}
trap cleanup EXIT INT TERM

# Resolve a branch name to a ref in repo $1, honouring the repo's map ($3).
# Prints "<ref>|<note>" or nothing if not found.
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
    [ -n "$d" ] && { echo "$d|default branch is ${d#origin/}"; return; }
    return
  fi
  if git -C "$repo" rev-parse --verify -q "origin/$b^{commit}" >/dev/null; then echo "origin/$b|$note"; return; fi
  if git -C "$repo" rev-parse --verify -q "$b^{commit}" >/dev/null; then echo "$b|$note"; return; fi
  local alt=""
  [ "$b" = "main" ] && alt="master"; [ "$b" = "master" ] && alt="main"
  if [ -n "$alt" ] && git -C "$repo" rev-parse --verify -q "origin/$alt^{commit}" >/dev/null; then
    echo "origin/$alt|no $b here, used $alt"; return
  fi
}

# ----------------------------------------------------------------------------
# Check each repo
# ----------------------------------------------------------------------------
SUMMARY=(); any_conflict=0; any_error=0

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  repo="${PATHS[$i]:-$ROOT/$name}"; repo="${repo/#\~/$HOME}"
  say ""
  say "=== ${name} (${repo}) ==="

  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    say "  not a git repository"; SUMMARY+=("$name|ERROR|not a git repo|"); any_error=1; continue
  fi

  if [ "$FETCH" = 1 ]; then
    git -C "$repo" fetch -q origin 2>&1 | sed 's/^/  fetch: /' || true
  fi

  src_r="$(resolve "$repo" "$SOURCE" "${MAPS[$i]}")"
  tgt_r="$(resolve "$repo" "$TARGET" "${MAPS[$i]}")"
  if [ -z "$src_r" ] || [ -z "$tgt_r" ]; then
    missing=""; [ -z "$src_r" ] && missing="$SOURCE"; [ -z "$tgt_r" ] && missing="${missing:+$missing, }$TARGET"
    say "  branch not found: ${missing}"; SUMMARY+=("$name|ERROR|branch not found: $missing|"); any_error=1; continue
  fi
  SRC="${src_r%%|*}"; TGT="${tgt_r%%|*}"
  for n in "${src_r#*|}" "${tgt_r#*|}"; do [ -n "$n" ] && say "  note: $n"; done
  say "  merging ${SRC}  ->  ${TGT}"

  if ! base="$(git -C "$repo" merge-base "$SRC" "$TGT" 2>/dev/null)"; then
    say "  no common ancestor"; SUMMARY+=("$name|ERROR|no common ancestor|$SRC -> $TGT"); any_error=1; continue
  fi
  ahead="$(git -C "$repo" rev-list --count "$TGT..$SRC")"
  behind="$(git -C "$repo" rev-list --count "$SRC..$TGT")"
  say "  ${SRC#origin/} is ${ahead} ahead / ${behind} behind ${TGT#origin/}"

  files=()
  if [ "$ENGINE" = "merge-tree" ]; then
    out="$(git -C "$repo" merge-tree --write-tree --name-only --no-messages "$TGT" "$SRC" 2>&1)"; rc=$?
    if [ $rc -eq 1 ]; then
      while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done < <(echo "$out" | tail -n +2 | sort -u)
    elif [ $rc -ne 0 ]; then
      say "  merge check failed: $out"; SUMMARY+=("$name|ERROR|merge check failed|$SRC -> $TGT"); any_error=1; continue
    fi
  else
    CURRENT_REPO="$repo"; CURRENT_WT="$TMPROOT/wt-$i"
    if ! git -C "$repo" worktree add -q --detach "$CURRENT_WT" "$TGT" >"$TMPROOT/wt.log" 2>&1; then
      say "  could not create temp worktree: $(tail -n 1 "$TMPROOT/wt.log")"
      SUMMARY+=("$name|ERROR|temp worktree failed|$SRC -> $TGT"); any_error=1; CURRENT_WT=""; continue
    fi
    if ! git -C "$CURRENT_WT" -c user.name=conflict-check -c user.email=conflict-check@local \
           merge -q --no-commit --no-ff "$SRC" >"$TMPROOT/merge.log" 2>&1; then
      while IFS= read -r f; do [ -n "$f" ] && files+=("$f"); done \
        < <(git -C "$CURRENT_WT" diff --name-only --diff-filter=U)
      if [ "${#files[@]}" -eq 0 ]; then
        say "  merge failed: $(tail -n 1 "$TMPROOT/merge.log")"
        git -C "$CURRENT_WT" merge --abort >/dev/null 2>&1
        git -C "$repo" worktree remove --force "$CURRENT_WT" >/dev/null 2>&1; CURRENT_WT=""
        SUMMARY+=("$name|ERROR|merge failed|$SRC -> $TGT"); any_error=1; continue
      fi
    fi
    git -C "$CURRENT_WT" merge --abort >/dev/null 2>&1
    git -C "$repo" worktree remove --force "$CURRENT_WT" >/dev/null 2>&1
    git -C "$repo" worktree prune >/dev/null 2>&1
    CURRENT_WT=""
  fi

  if [ "${#files[@]}" -eq 0 ]; then
    say "  OK: no conflicts"
    SUMMARY+=("$name|CLEAN||$SRC -> $TGT")
  else
    say "  CONFLICTS in ${#files[@]} file(s):"
    for f in "${files[@]}"; do say "    - $f"; done
    SUMMARY+=("$name|CONFLICT|${#files[@]} file(s): $(IFS=,; echo "${files[*]}")|$SRC -> $TGT")
    any_conflict=1
  fi
done

# ----------------------------------------------------------------------------
# Summary
# ----------------------------------------------------------------------------
echo ""
echo "Summary: merge ${SOURCE} -> ${TARGET}   (engine: ${ENGINE}, git ${gv})"
printf '  %-38s %-9s %s\n' "REPO" "RESULT" "DETAIL"
for row in "${SUMMARY[@]}"; do
  IFS='|' read -r n res det refs <<< "$row"
  printf '  %-38s %-9s %s\n' "$n" "$res" "${det:-$refs}"
done

[ "$any_error" = 1 ] && exit 2
[ "$any_conflict" = 1 ] && exit 1
exit 0
