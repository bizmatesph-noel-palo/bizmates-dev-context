#!/bin/bash
set -e

PROJECT_NAME="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
TOOLKIT_PATH="${ROOT_DIR}/../agentic-toolkit"
PROJECT_DIR="${ROOT_DIR}/projects/${PROJECT_NAME}"

if [ -z "$PROJECT_NAME" ]; then
    echo "Usage: $0 <project-name>"
    echo "Example: $0 my-project"
    exit 1
fi

if [ -d "$PROJECT_DIR" ]; then
    echo "Error: Project '$PROJECT_NAME' already exists at $PROJECT_DIR"
    exit 1
fi

if [ ! -d "$TOOLKIT_PATH/templates/bootstrap/project" ]; then
    echo "Error: Toolkit not found at $TOOLKIT_PATH"
    echo "Expected: $TOOLKIT_PATH/templates/bootstrap/project/"
    echo "Make sure agentic-toolkit is cloned alongside this workspace."
    exit 1
fi

echo "Scaffolding project: $PROJECT_NAME"
echo "  From toolkit: $TOOLKIT_PATH"
echo "  Target: $PROJECT_DIR"
echo ""

# Create directory structure
mkdir -p "$PROJECT_DIR"/{knowledge-base,testcases,technical-notes/jira/{tickets,epics,proposals},technical-notes/investigation,documentation/diagrams,generated-files,.kiro-draft/{steering,hooks,skills}}

# Copy base templates from toolkit (always included)
cp "$TOOLKIT_PATH/templates/bootstrap/project/project-context.md" "$PROJECT_DIR/project-context.md"
cp "$TOOLKIT_PATH/templates/bootstrap/project/README.md" "$PROJECT_DIR/README.md"
cp "$TOOLKIT_PATH/templates/bootstrap/project/conventions.md" "$PROJECT_DIR/.kiro-draft/steering/conventions.md"
cp "$TOOLKIT_PATH/templates/bootstrap/project/repository-map.md" "$PROJECT_DIR/.kiro-draft/steering/repository-map.md"
cp "$TOOLKIT_PATH/hooks/git-commit-guard.json" "$PROJECT_DIR/.kiro-draft/hooks/git-commit-guard.json"

# Copy steering templates (to be customized based on project type)
cp "$TOOLKIT_PATH/templates/steering/system-overview.md" "$PROJECT_DIR/.kiro-draft/steering/system-overview.md"
cp "$TOOLKIT_PATH/templates/steering/tech-stack.md" "$PROJECT_DIR/.kiro-draft/steering/tech-stack.md"
cp "$TOOLKIT_PATH/templates/steering/coding-standards.md" "$PROJECT_DIR/.kiro-draft/steering/coding-standards.md"

# Copy skill template
cp "$TOOLKIT_PATH/templates/skills/developer-role.md" "$PROJECT_DIR/.kiro-draft/skills/developer-role.md"

# Add .gitkeep to empty directories
for dir in knowledge-base testcases technical-notes/jira/tickets technical-notes/jira/epics technical-notes/jira/proposals technical-notes/investigation documentation documentation/diagrams; do
    touch "$PROJECT_DIR/$dir/.gitkeep"
done

# Gitignore generated files
cat > "$PROJECT_DIR/generated-files/.gitignore" << 'EOF'
*
!.gitignore
EOF

# Replace placeholder in templates
sed -i "s/{{PROJECT_NAME}}/${PROJECT_NAME}/g" "$PROJECT_DIR/project-context.md"
sed -i "s/{{PROJECT_NAME}}/${PROJECT_NAME}/g" "$PROJECT_DIR/README.md"
sed -i "s/{{PROJECT_NAME}}/${PROJECT_NAME}/g" "$PROJECT_DIR/.kiro-draft/steering/conventions.md"
sed -i "s/{{PROJECT_NAME}}/${PROJECT_NAME}/g" "$PROJECT_DIR/.kiro-draft/steering/repository-map.md"

# Update routing table in workspace steering (avoid duplicates)
ROUTING_FILE="${ROOT_DIR}/.kiro/steering/workspace-identity.md"
if [ -f "$ROUTING_FILE" ]; then
    if ! grep -q "| \`${PROJECT_NAME}\`" "$ROUTING_FILE"; then
        echo "| \`${PROJECT_NAME}\` | TBA | \`projects/${PROJECT_NAME}/\` | Active |" >> "$ROUTING_FILE"
    fi
fi

echo "✅ Project '$PROJECT_NAME' scaffolded successfully"
echo ""
echo "Next step:"
echo "  Link to your code repo (this fills project-context.md automatically):"
echo "    make link-project name=$PROJECT_NAME repo=/path/to/your/$PROJECT_NAME"
