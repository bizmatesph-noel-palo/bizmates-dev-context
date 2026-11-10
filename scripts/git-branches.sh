#!/usr/bin/env bash
#
# gitbranch - show the current git branch of repositories.
#
# Usage:
#   gitbranch              # branch of the repo you are currently in
#   gitbranch --all        # branch of every repo under ~/bizmates
#   gitbranch --all DIR    # branch of every repo under DIR
#   gitbranch --help
#
# The BASE_DIR env var also sets the folder scanned by --all.
# Output columns: repo name, current branch, and "*" if the working tree has
# uncommitted changes. Read-only: it never changes anything in any repo.

BASE_DIR_DEFAULT="${BASE_DIR:-$HOME/bizmates}"

usage() {
  sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
}

# Print one row for the repo at the given directory.
print_repo() {
  local dir="$1" name branch dirty
  name=$(basename "$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir")")

  branch=$(git -C "$dir" symbolic-ref --short -q HEAD 2>/dev/null)
  if [ -z "$branch" ]; then
    # Detached HEAD: show the short commit instead.
    branch="(detached @ $(git -C "$dir" rev-parse --short HEAD 2>/dev/null))"
  fi

  if [ -n "$(git -C "$dir" status --porcelain 2>/dev/null | head -n 1)" ]; then
    dirty="*"
  else
    dirty=""
  fi

  printf '%-40s %-55s %s\n' "$name" "$branch" "$dirty"
}

print_header() {
  printf '%-40s %-55s %s\n' "REPOSITORY" "BRANCH" "DIRTY"
  printf '%-40s %-55s %s\n' "----------" "------" "-----"
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;

  -a|--all)
    base="${2:-$BASE_DIR_DEFAULT}"
    if [ ! -d "$base" ]; then
      echo "[ERROR] Base directory not found: $base" >&2
      exit 1
    fi

    print_header
    found=0
    for dir in "$base"/*/; do
      [ -d "${dir}.git" ] || continue
      found=$((found + 1))
      print_repo "$dir"
    done

    if [ "$found" -eq 0 ]; then
      echo "No git repositories found under $base"
    fi
    ;;

  "")
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      echo "Not inside a git repository. Use 'gitbranch --all' to list every repo." >&2
      exit 1
    fi

    print_header
    print_repo "."
    ;;

  *)
    echo "[ERROR] Unknown option: $1" >&2
    usage >&2
    exit 1
    ;;
esac
