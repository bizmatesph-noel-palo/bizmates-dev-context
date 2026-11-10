#!/usr/bin/env bash
#
# merge-to-new-branch-v2.sh — multi-repo branch tool with 4 options.
#
#   Option 1  CHECK     Is there a conflict between the 2 branches?   (read-only)
#   Option 2  MERGE     If there is no conflict: ask for a new branch name,
#                       create it from TARGET and merge SOURCE into it.
#                       Conflict -> nothing is done for that repo. Never pushes.
#   Option 3  CHANGES   Show the commits and changed files between the 2
#                       branches. Merges nothing.                     (read-only)
#   Option 4  CHECKOUT  Switch every repo's checkout to one branch.
#                       Repos with uncommitted changes are skipped (nothing lost).
#
# Usage:
#   bash merge-to-new-branch-v2.sh                       # interactive menu
#   bash merge-to-new-branch-v2.sh -o 1 SOURCE TARGET    # check
#   bash merge-to-new-branch-v2.sh -o 2 SOURCE TARGET    # merge into a new branch
#   bash merge-to-new-branch-v2.sh -o 3 SOURCE TARGET    # show changes
#   bash merge-to-new-branch-v2.sh -o 4 BRANCH           # checkout
#
#   SOURCE = branch merged IN (e.g. main), TARGET = branch merged INTO / the new
#   branch starts from (e.g. deployment/dev04).
#   Branches resolve as origin/<name> first, then as given. "@default" = the
#   repo's default branch (main, or master for bizmates.jp). If "main"/"master"
#   doesn't exist in a repo, the other is tried. JSON "branch_map" also applies.
#
# Repos (first match wins): -c FILE (JSON), -f FILE (text "name [path]"),
#   REPOS="a b" env, or check-conflicts.repos.json next to this script.
#
# Options:
#   -o, --option N    1-4 (no option = interactive menu)
#   -r, --root DIR    folder containing the repos (default ~/bizmates)
#   --no-fetch        don't fetch from origin first
#   Option 2:  -n NAME  same new-branch name for every repo (no prompt)
#              -y       accept the suggested name for every repo (no prompt)
#   Option 3:  --diff   also print the full diff of SOURCE's changes
#              --limit N  max commits listed per side (default 20)
#   Option 4:  --pull   after checkout, fast-forward to origin if behind
#                       (only fast-forward; never creates a merge commit)
#
# Exit code: 0 = all good, 1 = conflict/skip somewhere, 2 = error somewhere.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG=""; REPOS_FILE=""; ROOT="${REPOS_ROOT:-}"; FETCH=1
OPTION=""; FIXED_NAME=""; AUTO_YES=0; SHOW_DIFF=0; LIMIT=20; DO_PULL=0
POS=()

usage() { sed -n '2,/^set -uo/p' "$0" | sed 's/^# \{0,1\}//' | sed '$d'; exit 2; }
die()   { echo "[ERROR] $*" >&2; exit 2; }

while [ $# -gt 0 ]; do
  case "$1" in
    -o|--option)     OPTION="${2:-}"; shift 2;;
    -c|--config)     CONFIG="${2:-}"; shift 2;;
    -f|--repos-file) REPOS_FILE="${2:-}"; shift 2;;
    -r|--root)       ROOT="${2:-}"; shift 2;;
    -n|--name)       FIXED_NAME="${2:-}"; shift 2;;
    -y|--yes)        AUTO_YES=1; shift;;
    --diff)          SHOW_DIFF=1; shift;;
    --limit)         LIMIT="${2:-20}"; shift 2;;
    --pull)          DO_PULL=1; shift;;
    --no-fetch)      FETCH=0; shift;;
    -h|--help)       usage;;
    -*)              die "Unknown option: $1";;
    *)               POS+=("$1"); shift;;
  esac
done
command -v git >/dev/null || die "git is not installed."

# All prompts read from the original stdin (fd 3), so git can't eat the answers.
exec 3<&0
ask() { # ask "question" "default" -> prints answer (default on empty)
  local q="$1" def="${2:-}" ans
  if [ -n "$def" ]; then printf '%s [%s]: ' "$q" "$def" >&2; else printf '%s: ' "$q" >&2; fi
  IFS= read -r ans <&3 || { echo "" >&2; die "no input available for: $q"; }
  ans="$(echo "$ans" | tr -d '\r' | xargs)"
  echo "${ans:-$def}"
}

# ----------------------------------------------------------------------------
# Choose the option and branches (menu when not given)
# ----------------------------------------------------------------------------
if [ -z "$OPTION" ]; then
  {
    echo ""
    echo "What do you want to do?"
    echo "  1) Check for conflicts between 2 branches          (read-only)"
    echo "  2) Merge into a NEW branch, only where no conflict (never pushes)"
    echo "  3) Show the changes/files between 2 branches       (read-only)"
    echo "  4) Checkout every repo to one branch"
  } >&2
  OPTION="$(ask "Option (1-4)" "")"
fi
case "$OPTION" in 1|2|3|4) ;; *) die "Option must be 1, 2, 3 or 4 (got '$OPTION').";; esac

if [ "$OPTION" = 4 ]; then
  BRANCH="${POS[0]:-}"
  [ -n "$BRANCH" ] || BRANCH="$(ask "Branch to checkout in every repo (e.g. deployment/dev04, @default)" "")"
  [ -n "$BRANCH" ] || die "No branch given."
else
  SOURCE="${POS[0]:-}"; TARGET="${POS[1]:-}"
  [ -n "$SOURCE" ] || SOURCE="$(ask "SOURCE branch (merged in, e.g. main)" "main")"
  [ -n "$TARGET" ] || TARGET="$(ask "TARGET branch (merged into, e.g. deployment/dev04)" "deployment/dev04")"
fi

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
  die "No repos given. Use -c, -f, or REPOS=\"...\"."
fi
[ "${#NAMES[@]}" -gt 0 ] || die "The repo list is empty."
ROOT="${ROOT:-$HOME/bizmates}"; ROOT="${ROOT/#\~/$HOME}"

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
TMPROOT="$(mktemp -d)"
CURRENT_WT=""; CURRENT_REPO=""
drop_worktree() {
  [ -n "$CURRENT_WT" ] || return 0
  git -C "$CURRENT_WT" merge --abort >/dev/null 2>&1
  git -C "$CURRENT_REPO" worktree remove --force "$CURRENT_WT" >/dev/null 2>&1
  git -C "$CURRENT_REPO" worktree prune >/dev/null 2>&1
  CURRENT_WT=""
}
cleanup() { drop_worktree; rm -rf "$TMPROOT"; }
trap cleanup EXIT INT TERM

# Map + @default + main/master fallback. Prints "<name>|<note>" (bare branch
# name, no origin/) or nothing. $4=1 also accepts any other ref (tag/commit).
resolve_name() {
  local repo="$1" want="$2" map="$3" b note="" pair alt=""
  b="$want"
  for pair in ${map//,/ }; do
    [ "${pair%%=*}" = "$want" ] && { b="${pair#*=}"; note="mapped $want -> $b"; }
  done
  if [ "$b" = "@default" ]; then
    local d; d="$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD)" \
      || { git -C "$repo" remote set-head origin --auto >/dev/null 2>&1; \
           d="$(git -C "$repo" symbolic-ref -q --short refs/remotes/origin/HEAD)"; }
    [ -n "$d" ] && echo "${d#origin/}|default branch is ${d#origin/}"
    return
  fi
  if git -C "$repo" rev-parse --verify -q "origin/$b^{commit}" >/dev/null \
     || git -C "$repo" show-ref --verify -q "refs/heads/$b"; then echo "$b|$note"; return; fi
  [ "$b" = "main" ] && alt="master"; [ "$b" = "master" ] && alt="main"
  if [ -n "$alt" ] && { git -C "$repo" rev-parse --verify -q "origin/$alt^{commit}" >/dev/null \
       || git -C "$repo" show-ref --verify -q "refs/heads/$alt"; }; then
    echo "$alt|no $b here, used $alt"; return
  fi
  if [ "${4:-0}" = 1 ] && git -C "$repo" rev-parse --verify -q "$b^{commit}" >/dev/null; then echo "$b|$note"; fi
}
# A ref to compare/merge with: origin/<name> when it exists, else the name.
as_ref() { if git -C "$1" rev-parse --verify -q "origin/$2^{commit}" >/dev/null; then echo "origin/$2"; else echo "$2"; fi; }
short() { local s="${1#origin/}"; echo "${s##*/}"; }

branch_exists() {
  local repo="$1" name="$2"
  git -C "$repo" show-ref --verify -q "refs/heads/$name" && { echo "local"; return 0; }
  git -C "$repo" show-ref --verify -q "refs/remotes/origin/$name" && { echo "origin"; return 0; }
  if [ "$FETCH" = 1 ] && [ -n "$(git -C "$repo" ls-remote --heads origin "$name" 2>/dev/null)" ]; then
    echo "origin"; return 0
  fi
  return 1
}

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

# Dry-run merge of $3 into $2 in a temp worktree (detached at $2).
# Returns 0 clean (worktree KEPT, merge aborted), 1 conflict, 2 error.
CONFLICT_FILES=""
dry_merge() {
  local repo="$1" tgt="$2" src="$3" idx="$4"
  CONFLICT_FILES=""
  CURRENT_REPO="$repo"; CURRENT_WT="$TMPROOT/wt-$idx"
  if ! git -C "$repo" worktree add -q --detach "$CURRENT_WT" "$tgt" >"$TMPROOT/wt.log" 2>&1; then
    echo "  could not create temp worktree: $(tail -n 1 "$TMPROOT/wt.log")"; CURRENT_WT=""; return 2
  fi
  if git -C "$CURRENT_WT" -c user.name=conflict-check -c user.email=conflict-check@local \
       merge -q --no-commit --no-ff "$src" >"$TMPROOT/merge.log" 2>&1; then
    git -C "$CURRENT_WT" merge --abort >/dev/null 2>&1
    return 0
  fi
  CONFLICT_FILES="$(git -C "$CURRENT_WT" diff --name-only --diff-filter=U)"
  drop_worktree
  if [ -n "$CONFLICT_FILES" ]; then return 1; fi
  echo "  merge check failed: $(tail -n 1 "$TMPROOT/merge.log")"; return 2
}

SUMMARY=(); rc_any=0
note_rc() { [ "$1" -gt "$rc_any" ] && rc_any="$1"; return 0; }
add() { SUMMARY+=("$1|$2|$3"); }
count_lines() { sed '/^$/d' | wc -l | tr -d ' '; }

# ----------------------------------------------------------------------------
# Option 4: checkout
# ----------------------------------------------------------------------------
do_checkout() {
  local name="$1" repo="$2" map="$3" r b note cur up counts behind ahead gd
  r="$(resolve_name "$repo" "$BRANCH" "$map")"
  [ -n "$r" ] || { echo "  branch not found: $BRANCH"; add "$name" ERROR "branch not found: $BRANCH"; note_rc 2; return; }
  b="${r%%|*}"; note="${r#*|}"; [ -n "$note" ] && echo "  note: $note"
  cur="$(git -C "$repo" branch --show-current)"

  if [ "$cur" != "$b" ]; then
    gd="$(git -C "$repo" rev-parse --git-dir)"; case "$gd" in /*) ;; *) gd="$repo/$gd";; esac
    if [ -e "$gd/MERGE_HEAD" ] || [ -d "$gd/rebase-merge" ] || [ -d "$gd/rebase-apply" ]; then
      echo "  a merge/rebase is in progress - skipped (finish or abort it first)."
      add "$name" SKIPPED "merge/rebase in progress (on ${cur:-detached})"; note_rc 1; return
    fi
    if [ -n "$(git -C "$repo" status --porcelain --untracked-files=no)" ]; then
      echo "  has uncommitted changes on '${cur:-detached}' - skipped so nothing is lost:"
      git -C "$repo" status --short --untracked-files=no | head -n 10 | sed 's/^/    /'
      add "$name" SKIPPED "uncommitted changes on ${cur:-detached}"; note_rc 1; return
    fi
    local co_rc
    if git -C "$repo" show-ref --verify -q "refs/heads/$b"; then
      git -C "$repo" checkout -q "$b" >"$TMPROOT/co.log" 2>&1; co_rc=$?
    else
      git -C "$repo" checkout -q -b "$b" --track "origin/$b" >"$TMPROOT/co.log" 2>&1; co_rc=$?
    fi
    if [ $co_rc -ne 0 ]; then
      echo "  checkout failed: $(tail -n 2 "$TMPROOT/co.log" | tr '\n' ' ')"
      add "$name" ERROR "checkout failed (still on ${cur:-detached})"; note_rc 2; return
    fi
    echo "  switched: ${cur:-detached} -> $b"
  else
    echo "  already on $b"
  fi

  up="$(git -C "$repo" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null)"
  if [ -z "$up" ]; then add "$name" OK "on $b (no upstream)"; return; fi
  counts="$(git -C "$repo" rev-list --left-right --count "$up...HEAD")"
  behind="${counts%%[[:space:]]*}"; ahead="${counts##*[[:space:]]}"
  if [ "$behind" -gt 0 ] && [ "$DO_PULL" = 1 ] && [ "$ahead" -eq 0 ]; then
    if git -C "$repo" merge -q --ff-only "$up" >/dev/null 2>&1; then
      echo "  fast-forwarded $behind commit(s) from $up"
      add "$name" OK "on $b (fast-forwarded $behind)"; return
    fi
    echo "  fast-forward failed (local files in the way?) - left as is."
  fi
  if [ "$behind" -gt 0 ] || [ "$ahead" -gt 0 ]; then
    local hint=""; [ "$behind" -gt 0 ] && [ "$DO_PULL" = 0 ] && hint=" (use --pull to fast-forward)"
    echo "  vs $up: behind $behind, ahead $ahead$hint"
    add "$name" OK "on $b (behind $behind, ahead $ahead)"
  else
    add "$name" OK "on $b (up to date)"
  fi
}

# ----------------------------------------------------------------------------
# Options 1-3
# ----------------------------------------------------------------------------
do_pair() {
  local name="$1" repo="$2" map="$3" idx="$4" sr tr SRC TGT n base ahead behind rc
  sr="$(resolve_name "$repo" "$SOURCE" "$map" 1)"; tr="$(resolve_name "$repo" "$TARGET" "$map" 1)"
  if [ -z "$sr" ] || [ -z "$tr" ]; then
    local missing=""; [ -z "$sr" ] && missing="$SOURCE"; [ -z "$tr" ] && missing="${missing:+$missing, }$TARGET"
    echo "  branch not found: $missing"; add "$name" ERROR "branch not found: $missing"; note_rc 2; return
  fi
  for n in "${sr#*|}" "${tr#*|}"; do [ -n "$n" ] && echo "  note: $n"; done
  SRC="$(as_ref "$repo" "${sr%%|*}")"; TGT="$(as_ref "$repo" "${tr%%|*}")"
  if ! base="$(git -C "$repo" merge-base "$SRC" "$TGT" 2>/dev/null)"; then
    echo "  no common ancestor"; add "$name" ERROR "no common ancestor"; note_rc 2; return
  fi
  ahead="$(git -C "$repo" rev-list --count "$TGT..$SRC")"; behind="$(git -C "$repo" rev-list --count "$SRC..$TGT")"
  echo "  ${SRC#origin/} -> ${TGT#origin/}: ${SRC#origin/} has $ahead commit(s) not in ${TGT#origin/}; ${TGT#origin/} has $behind not in ${SRC#origin/}"

  case "$OPTION" in
  1)
    dry_merge "$repo" "$TGT" "$SRC" "$idx"; rc=$?; drop_worktree
    case $rc in
      0) echo "  OK: no conflicts"; add "$name" CLEAN "${SRC#origin/} -> ${TGT#origin/}";;
      1) echo "  CONFLICTS:"; echo "$CONFLICT_FILES" | sed 's/^/    - /'
         add "$name" CONFLICT "$(echo "$CONFLICT_FILES" | count_lines) file(s): $(echo "$CONFLICT_FILES" | paste -sd, -)"; note_rc 1;;
      *) add "$name" ERROR "merge check failed"; note_rc 2;;
    esac;;
  2)
    if [ "$ahead" -eq 0 ]; then
      echo "  nothing to merge (${TGT#origin/} already contains ${SRC#origin/})"
      add "$name" SKIPPED "nothing to merge"; return
    fi
    dry_merge "$repo" "$TGT" "$SRC" "$idx"; rc=$?
    if [ $rc -eq 1 ]; then
      echo "  CONFLICT - nothing done for this repo:"; echo "$CONFLICT_FILES" | sed 's/^/    - /'
      add "$name" CONFLICT "nothing done ($(echo "$CONFLICT_FILES" | count_lines) file(s))"; note_rc 1; return
    elif [ $rc -ne 0 ]; then
      add "$name" ERROR "merge check failed"; note_rc 2; return
    fi
    echo "  OK: no conflicts."
    if [ -z "$(git -C "$repo" config user.name)" ] || [ -z "$(git -C "$repo" config user.email)" ]; then
      drop_worktree; echo "  git user.name/user.email not set - can't create the merge commit."
      add "$name" ERROR "git identity not set"; note_rc 2; return
    fi
    local suggested new msg head
    suggested="sync/$(short "$TGT")/$(short "$SRC")-to-$(short "$TGT")-$(date '+%Y%m%d')"
    new="$(pick_name "$repo" "$suggested")"
    [ -n "$new" ] || { drop_worktree; add "$name" SKIPPED "no branch created"; note_rc 1; return; }
    if ! git -C "$CURRENT_WT" checkout -q -b "$new" >"$TMPROOT/co.log" 2>&1; then
      echo "  could not create '$new': $(tail -n 1 "$TMPROOT/co.log")"
      drop_worktree; add "$name" ERROR "could not create $new"; note_rc 2; return
    fi
    msg="Merge ${SRC#origin/} into ${new} (from ${TGT#origin/})"
    if git -C "$CURRENT_WT" merge -q --no-ff -m "$msg" "$SRC" >"$TMPROOT/merge2.log" 2>&1; then
      head="$(git -C "$CURRENT_WT" rev-parse --short HEAD)"; drop_worktree
      echo "  created branch '$new' at $head (local only, not pushed)"
      add "$name" CREATED "$new @ $head"
    else
      echo "  merge failed unexpectedly: $(tail -n 1 "$TMPROOT/merge2.log")"
      git -C "$CURRENT_WT" merge --abort >/dev/null 2>&1; git -C "$CURRENT_WT" checkout -q --detach >/dev/null 2>&1
      drop_worktree
      if [ "$(git -C "$repo" rev-parse "refs/heads/$new" 2>/dev/null)" = "$(git -C "$repo" rev-parse "$TGT^{commit}")" ]; then
        git -C "$repo" branch -q -D "$new" >/dev/null 2>&1 && echo "  removed the empty branch '$new' created by this run."
      fi
      add "$name" ERROR "merge failed"; note_rc 2
    fi;;
  3)
    local s="${SRC#origin/}" t="${TGT#origin/}" fs ft both nfs nft nboth
    echo "  merge-base: $(git -C "$repo" --no-pager log -1 --format='%h %ad %s' --date=short "$base")"
    echo ""
    echo "  Commits only on $s ($ahead):"
    git -C "$repo" --no-pager log --format='    %h %ad %an  %s' --date=short -n "$LIMIT" "$TGT..$SRC"
    [ "$ahead" -gt "$LIMIT" ] && echo "    ... and $((ahead - LIMIT)) more (use --limit N)"
    echo ""
    echo "  Commits only on $t ($behind):"
    git -C "$repo" --no-pager log --format='    %h %ad %an  %s' --date=short -n "$LIMIT" "$SRC..$TGT"
    [ "$behind" -gt "$LIMIT" ] && echo "    ... and $((behind - LIMIT)) more (use --limit N)"
    fs="$(git -C "$repo" diff --name-only "$base" "$SRC" | sort)"; ft="$(git -C "$repo" diff --name-only "$base" "$TGT" | sort)"
    both="$(comm -12 <(echo "$fs") <(echo "$ft") | sed '/^$/d')"
    nfs="$(echo "$fs" | count_lines)"; nft="$(echo "$ft" | count_lines)"; nboth="$(echo "$both" | count_lines)"
    echo ""
    echo "  Files changed on $s since the merge-base ($nfs):"
    git -C "$repo" --no-pager diff --name-status "$base" "$SRC" | sed 's/^/    /'
    echo ""
    echo "  Files changed on $t since the merge-base ($nft):"
    git -C "$repo" --no-pager diff --name-status "$base" "$TGT" | sed 's/^/    /'
    echo ""
    echo "  Files changed on BOTH sides - review these ($nboth):"
    if [ -n "$both" ]; then echo "$both" | sed 's/^/    /'; else echo "    (none)"; fi
    if [ "$SHOW_DIFF" = 1 ]; then
      echo ""
      echo "  ---- full diff: what $s changes (merge-base -> $s) ----"
      git -C "$repo" --no-pager diff "$base" "$SRC" | sed 's/^/  /'
    fi
    add "$name" CHANGES "$s: $ahead commits/$nfs files | $t: $behind commits/$nft files | both: $nboth files";;
  esac
}

# ----------------------------------------------------------------------------
# Main loop
# ----------------------------------------------------------------------------
case "$OPTION" in
  1) TITLE="Option 1 - conflict check: ${SOURCE} -> ${TARGET}";;
  2) TITLE="Option 2 - merge ${SOURCE} into a NEW branch from ${TARGET} (nothing pushed)";;
  3) TITLE="Option 3 - changes between ${SOURCE} and ${TARGET} (nothing merged)";;
  4) TITLE="Option 4 - checkout ${BRANCH}";;
esac
echo "$TITLE"

for i in "${!NAMES[@]}"; do
  name="${NAMES[$i]}"
  repo="${PATHS[$i]:-$ROOT/$name}"; repo="${repo/#\~/$HOME}"
  echo ""
  echo "=== ${name} (${repo}) ==="
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    echo "  not a git repository"; add "$name" ERROR "not a git repo"; note_rc 2; continue
  fi
  [ "$FETCH" = 1 ] && git -C "$repo" fetch -q origin 2>&1 | sed 's/^/  fetch: /'
  if [ "$OPTION" = 4 ]; then do_checkout "$name" "$repo" "${MAPS[$i]}"
  else do_pair "$name" "$repo" "${MAPS[$i]}" "$i"; fi
done

echo ""
echo "Summary: $TITLE"
printf '  %-38s %-9s %s\n' "REPO" "RESULT" "DETAIL"
for row in "${SUMMARY[@]}"; do
  IFS='|' read -r n res det <<< "$row"
  printf '  %-38s %-9s %s\n' "$n" "$res" "$det"
done
if [ "$OPTION" = 2 ] && printf '%s\n' "${SUMMARY[@]}" | grep -q '|CREATED|'; then
  echo ""
  echo "Nothing was pushed. Review, then push a branch yourself when ready:"
  echo "  git -C <repo> log --oneline -3 <branch>"
  echo "  git -C <repo> push -u origin <branch>"
fi
exit "$rc_any"
