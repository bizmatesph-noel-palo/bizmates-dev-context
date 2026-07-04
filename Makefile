TOOLKIT_PATH := ../agentic-toolkit

.PHONY: help new-project link-project ingest list-projects

help: ## Show available commands
	@echo ""
	@echo "Workspace — Project Management"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""

new-project: ## Scaffold a new project (name= required)
ifndef name
	$(error Usage: make new-project name=project-code)
endif
	@./scripts/bootstrap-project.sh $(name)

link-project: ## Scan a repo and pre-fill project context (name= repo= required)
ifndef name
	$(error Usage: make link-project name=project-code repo=/path/to/repo)
endif
ifndef repo
	$(error Usage: make link-project name=project-code repo=/path/to/repo)
endif
	@./scripts/link-project.sh $(name) $(repo)

ingest: ## Ingest a project — tell this to Kiro (name= required)
ifndef name
	$(error Usage: make ingest name=project-code)
endif
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Project Ingestion: $(name)"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "  In your Kiro session, say:"
	@echo ""
	@echo "    Ingest $(name)"
	@echo ""
	@echo "  This will:"
	@echo "    1. Read the detected stack from .detected-stack.md"
	@echo "    2. Fill project-context.md with real project data"
	@echo "    3. Customize .kiro-draft/ steering files"
	@echo "    4. Validate the three-layer workspace is understood"
	@echo ""
	@echo "  After ingestion completes, you're ready for spec-driven development."
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""

list-projects: ## List all project directories
	@echo "Projects:"
	@find ./projects -maxdepth 1 -type d ! -name 'projects' 2>/dev/null | sed 's|./projects/||' | sort | while read dir; do \
		if [ -f "./projects/$$dir/project-context.md" ]; then \
			echo "  projects/$$dir/ (has project-context.md)"; \
		fi; \
	done
