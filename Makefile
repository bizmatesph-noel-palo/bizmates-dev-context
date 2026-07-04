TOOLKIT_PATH := ../agentic-toolkit

.PHONY: help new-project link-project list-projects

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

list-projects: ## List all project directories
	@echo "Projects:"
	@find ./projects -maxdepth 1 -type d ! -name 'projects' 2>/dev/null | sed 's|./projects/||' | sort | while read dir; do \
		if [ -f "./projects/$$dir/project-context.md" ]; then \
			echo "  projects/$$dir/ (has project-context.md)"; \
		fi; \
	done
