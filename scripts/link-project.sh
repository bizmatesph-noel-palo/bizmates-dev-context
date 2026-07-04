#!/bin/bash
set -e

PROJECT_NAME="$1"
REPO_PATH="$2"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_DIR="${ROOT_DIR}/projects/${PROJECT_NAME}"
CONTEXT_FILE="${PROJECT_DIR}/project-context.md"

if [ -z "$PROJECT_NAME" ] || [ -z "$REPO_PATH" ]; then
    echo "Usage: $0 <project-name> <path-to-repo>"
    echo "Example: $0 my-project /home/user/projects/my-project"
    exit 1
fi

if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Project '$PROJECT_NAME' not found at $PROJECT_DIR"
    echo "Run 'make new-project name=$PROJECT_NAME' first."
    exit 1
fi

if [ ! -d "$REPO_PATH" ]; then
    echo "Error: Repo not found at $REPO_PATH"
    exit 1
fi

echo "Scanning project repo: $REPO_PATH"
echo "Updating context for: $PROJECT_NAME"
echo ""

# Detect tech stack
TECH_INFO=""
FRAMEWORK=""
LANGUAGE=""
DATABASE=""
BUILD_TOOL=""
TEST_TOOL=""
PACKAGE_MANAGER=""

# Determine if project uses a src/ subdirectory layout
APP_ROOT="$REPO_PATH"
if [ -f "$REPO_PATH/src/composer.json" ] || [ -f "$REPO_PATH/src/package.json" ]; then
    APP_ROOT="$REPO_PATH/src"
    TECH_INFO="${TECH_INFO}Layout: src/ subdirectory (app code under src/)\n"
fi

# PHP/Laravel detection
if [ -f "$APP_ROOT/composer.json" ]; then
    LANGUAGE="PHP"
    PACKAGE_MANAGER="Composer"
    if grep -q "laravel/framework" "$APP_ROOT/composer.json" 2>/dev/null; then
        FRAMEWORK="Laravel"
        LARAVEL_VER=$(grep -o '"laravel/framework": "[^"]*"' "$APP_ROOT/composer.json" | grep -o '[0-9]*\.' | head -1)
        FRAMEWORK="Laravel ${LARAVEL_VER}x"
    fi
    if grep -q "phpunit" "$APP_ROOT/composer.json" 2>/dev/null; then
        TEST_TOOL="PHPUnit"
    fi
    if grep -q "nuwave/lighthouse" "$APP_ROOT/composer.json" 2>/dev/null; then
        TECH_INFO="${TECH_INFO}API: GraphQL (Lighthouse)\n"
    fi
    # PHP version detection
    PHP_VER=$(grep -o '"php": "[^"]*"' "$APP_ROOT/composer.json" | grep -o '[0-9]\.[0-9]*' | head -1)
    if [ -n "$PHP_VER" ]; then
        TECH_INFO="${TECH_INFO}PHP Version: ${PHP_VER}+\n"
    fi
fi

# Node/JS detection
if [ -f "$APP_ROOT/package.json" ]; then
    if [ -z "$LANGUAGE" ]; then
        LANGUAGE="JavaScript/TypeScript"
    else
        TECH_INFO="${TECH_INFO}Frontend: JavaScript/TypeScript (package.json found)\n"
    fi
    if grep -q "\"vue\"" "$APP_ROOT/package.json" 2>/dev/null; then
        TECH_INFO="${TECH_INFO}Frontend Framework: Vue.js\n"
    fi
    if grep -q "\"react\"" "$APP_ROOT/package.json" 2>/dev/null; then
        TECH_INFO="${TECH_INFO}Frontend Framework: React\n"
    fi
    if grep -q "\"vite\"" "$APP_ROOT/package.json" 2>/dev/null; then
        BUILD_TOOL="Vite"
    elif grep -q "laravel-mix" "$APP_ROOT/package.json" 2>/dev/null; then
        BUILD_TOOL="Laravel Mix (Webpack)"
    elif grep -q "\"webpack\"" "$APP_ROOT/package.json" 2>/dev/null; then
        BUILD_TOOL="Webpack"
    fi
    if grep -q "\"vitest\"" "$APP_ROOT/package.json" 2>/dev/null; then
        TEST_TOOL="${TEST_TOOL:+$TEST_TOOL + }Vitest"
    elif grep -q "\"jest\"" "$APP_ROOT/package.json" 2>/dev/null; then
        TEST_TOOL="${TEST_TOOL:+$TEST_TOOL + }Jest"
    fi
    if grep -q "\"typescript\"" "$APP_ROOT/package.json" 2>/dev/null; then
        TECH_INFO="${TECH_INFO}TypeScript: Yes\n"
    fi
fi

# Docker detection
if [ -f "$REPO_PATH/docker-compose.yml" ] || [ -f "$REPO_PATH/docker/docker-compose.yml" ]; then
    TECH_INFO="${TECH_INFO}Infrastructure: Docker Compose\n"
fi

# Database detection (check both root and src/)
for ENV_FILE in "$REPO_PATH/.env.example" "$APP_ROOT/.env.example"; do
    if [ -f "$ENV_FILE" ] && [ -z "$DATABASE" ]; then
        if grep -q "DB_CONNECTION=mysql" "$ENV_FILE" 2>/dev/null; then
            DATABASE="MySQL"
        elif grep -q "DB_CONNECTION=pgsql" "$ENV_FILE" 2>/dev/null; then
            DATABASE="PostgreSQL"
        elif grep -q "DB_CONNECTION=sqlite" "$ENV_FILE" 2>/dev/null; then
            DATABASE="SQLite"
        fi
    fi
done

# Makefile detection
MAKEFILE_TARGETS=""
if [ -f "$REPO_PATH/Makefile" ]; then
    MAKEFILE_TARGETS=$(grep -E "^[a-zA-Z_-]+:.*##" "$REPO_PATH/Makefile" | head -10 | awk -F':.*##' '{printf "| `make %s` | %s |\n", $1, $2}')
fi

# Existing .kiro detection
HAS_KIRO="No"
if [ -d "$REPO_PATH/.kiro/steering" ]; then
    HAS_KIRO="Yes ($(ls "$REPO_PATH/.kiro/steering/"*.md 2>/dev/null | wc -l) steering files)"
fi

# Generate summary
echo "=== Detected ==="
echo "Language: ${LANGUAGE:-Unknown}"
echo "Framework: ${FRAMEWORK:-Unknown}"
echo "Database: ${DATABASE:-Unknown}"
echo "Build: ${BUILD_TOOL:-Unknown}"
echo "Testing: ${TEST_TOOL:-Unknown}"
echo "Existing .kiro/: $HAS_KIRO"
echo -e "$TECH_INFO"
echo ""

# Build key files list (avoid empty lines from failed conditionals)
KEY_FILES=""
if [ "$APP_ROOT" != "$REPO_PATH" ]; then
    APP_LABEL=" (in ${APP_ROOT#$REPO_PATH/}/)"
else
    APP_LABEL=""
fi
[ -f "$APP_ROOT/composer.json" ] && KEY_FILES="${KEY_FILES}- composer.json ✅${APP_LABEL}\n"
[ -f "$APP_ROOT/package.json" ] && KEY_FILES="${KEY_FILES}- package.json ✅${APP_LABEL}\n"
[ -f "$REPO_PATH/Makefile" ] && KEY_FILES="${KEY_FILES}- Makefile ✅\n"
[ -f "$REPO_PATH/docker-compose.yml" ] && KEY_FILES="${KEY_FILES}- docker-compose.yml ✅\n"
[ -d "$REPO_PATH/docker" ] && KEY_FILES="${KEY_FILES}- docker/ ✅\n"
[ -f "$REPO_PATH/.env.example" ] && KEY_FILES="${KEY_FILES}- .env.example ✅\n"
[ -f "$APP_ROOT/.env.example" ] && [ "$APP_ROOT" != "$REPO_PATH" ] && KEY_FILES="${KEY_FILES}- src/.env.example ✅\n"
[ -d "$REPO_PATH/.kiro" ] && KEY_FILES="${KEY_FILES}- .kiro/ ✅\n"
[ -f "$REPO_PATH/README.md" ] && KEY_FILES="${KEY_FILES}- README.md ✅\n"

# Build Makefile commands table for context
MAKEFILE_TABLE=""
if [ -n "$MAKEFILE_TARGETS" ]; then
    MAKEFILE_TABLE="$MAKEFILE_TARGETS"
fi

# Determine app description from README (first non-empty, non-heading line)
APP_DESCRIPTION=""
if [ -f "$REPO_PATH/README.md" ]; then
    APP_DESCRIPTION=$(grep -v '^#' "$REPO_PATH/README.md" | grep -v '^$' | head -1 | cut -c1-100)
fi

# ─── FILL project-context.md DIRECTLY ───────────────────────────────────────

# Determine relative app path label
if [ "$APP_ROOT" != "$REPO_PATH" ]; then
    MODELS_HINT="src/app/Models/"
    LAYOUT_ROW="| Layout | App code under \`src/\` subdirectory |"
else
    MODELS_HINT="app/Models/"
    LAYOUT_ROW=""
fi

# Get infrastructure info
INFRA_VALUE=$(echo -e "$TECH_INFO" | grep -i "docker\|infra" | sed 's/.*: //' | head -1)
INFRA_VALUE="${INFRA_VALUE:-Unknown}"

# Set defaults for empty values
LANG_VAL="${LANGUAGE:-Unknown}"
FW_VAL="${FRAMEWORK:-Unknown}"
DB_VAL="${DATABASE:-Unknown}"
BUILD_VAL="${BUILD_TOOL:-Unknown}"
TEST_VAL="${TEST_TOOL:-Unknown}"
PKG_VAL="${PACKAGE_MANAGER:-Unknown}"
DESC_VAL="${APP_DESCRIPTION:-Main project code}"
MAKE_TABLE="${MAKEFILE_TABLE:-| TBA | No Makefile targets detected |}"

cat > "$CONTEXT_FILE" << CTXEOF
# $PROJECT_NAME - Project Context

> Load this at the start of each session for project-specific context.
> Auto-generated by make link-project. Refine as you learn more about the project.

---

## Workspace Overview

| Directory | What it is |
|-----------|-----------|
| \`$REPO_PATH\` | **Code repo.** $DESC_VAL |
| \`projects/$PROJECT_NAME/\` | **Dev context.** Artifacts, knowledge, steering drafts. |

---

## Tech Stack

| Component | Value |
|---|---|
| Language | $LANG_VAL |
| Framework | $FW_VAL |
| Database | $DB_VAL |
| Build Tool | $BUILD_VAL |
| Testing | $TEST_VAL |
| Package Manager | $PKG_VAL |
| Infrastructure | $INFRA_VALUE |
$LAYOUT_ROW

---

## System Overview

### What It Does

$DESC_VAL

### Key Commands

| Command | Purpose |
|---------|---------|
$MAKE_TABLE

### Key Tables / Models

| Table/Model | Purpose |
|-------|---------|
| TBA | Scan \`$MODELS_HINT\` or migrations to fill this |

---

## Testing & Verification

### Verification Method

$TEST_VAL - run via \`make test\` or equivalent.

---

## Naming & File Conventions

### Naming

- Branches: \`{type}/$PROJECT_NAME-XXX-description\`
- Commits: \`type($PROJECT_NAME-XXX): description\`

### File Placement

| Content type | Path |
|---|---|
| JIRA ticket docs | \`$PROJECT_NAME/technical-notes/jira/tickets/\` |
| Epic docs | \`$PROJECT_NAME/technical-notes/jira/epics/\` |
| Design proposals | \`$PROJECT_NAME/technical-notes/jira/proposals/\` |
| Investigation reports | \`$PROJECT_NAME/technical-notes/investigation/\` |
| Test cases | \`$PROJECT_NAME/testcases/\` |
| Knowledge base | \`$PROJECT_NAME/knowledge-base/\` |
| Generated output | \`$PROJECT_NAME/generated-files/\` (gitignored) |

---

## Cross-References

| Shorthand | Repository |
|---|---|
| \`[$PROJECT_NAME]\` | \`$REPO_PATH\` |

---

## Recent Work

| ID | What | Status |
|----|------|--------|
| - | Project just linked | Setup |
CTXEOF

echo ""
echo "✅ project-context.md filled with detected data."
echo ""

# ─── Final output ────────────────────────────────────────────────────────────

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ Setup complete — ${PROJECT_NAME}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  project-context.md: filled with detected stack info"
echo ""
echo "  You're ready to work. In a Kiro session, load context:"
echo "    Read projects/${PROJECT_NAME}/project-context.md"
echo ""
echo "  Then use any toolkit workflow:"
echo "    - Investigate a bug"
echo "    - Fix a bug"
echo "    - Start a new feature (spec-driven)"
echo "    - Create a PR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
