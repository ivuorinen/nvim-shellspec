# Makefile for nvim-shellspec
# Provides help, linting, testing, and release functionality

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m # No Color

# Version files
VERSION_LUA := lua/shellspec/init.lua
VERSION_VIM := plugin/shellspec.vim
VERSION_BIN := bin/shellspec-format

# Commands
MAKE := make
PRE_COMMIT := pre-commit
TEST_RUNNER := ./tests/run_tests.sh

# Default target
.PHONY: help
help: ## Display this help message
	@echo "$(BLUE)nvim-shellspec Makefile$(NC)"
	@echo "$(BLUE)==========================================$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(GREEN)Current versions:$(NC)"
	@$(MAKE) --no-print-directory version-check
	@echo ""
	@echo "$(GREEN)Usage examples:$(NC)"
	@echo "  $(YELLOW)make test$(NC)          # Run all tests"
	@echo "  $(YELLOW)make lint$(NC)          # Run all linters"
	@echo "  $(YELLOW)make release-patch$(NC) # Bump patch version and create tag"
	@echo ""

.PHONY: check
check: ## Quick health check (verify tools and version consistency)
	@echo "$(BLUE)Running health check...$(NC)"
	@echo ""
	@echo "$(GREEN)Checking required tools:$(NC)"
	@which pre-commit >/dev/null 2>&1 && echo "  ✓ pre-commit found" || echo "  $(RED)✗ pre-commit not found$(NC)"
	@which git >/dev/null 2>&1 && echo "  ✓ git found" || echo "  $(RED)✗ git not found$(NC)"
	@which bash >/dev/null 2>&1 && echo "  ✓ bash found" || echo "  $(RED)✗ bash not found$(NC)"
	@test -f $(TEST_RUNNER) && echo "  ✓ test runner found" || echo "  $(RED)✗ test runner not found$(NC)"
	@echo ""
	@echo "$(GREEN)Version consistency:$(NC)"
	@$(MAKE) --no-print-directory version-check
	@echo ""

.PHONY: version
version: version-check ## Display current versions

.PHONY: version-check
version-check: ## Check version consistency across files
	@echo "$(GREEN)Version information:$(NC)"
	@lua_version=$$(grep '_VERSION = ' $(VERSION_LUA) | sed 's/.*"\(.*\)".*/\1/'); \
	vim_version=$$(grep "g:shellspec_version = " $(VERSION_VIM) | sed "s/.*'\(.*\)'.*/\1/"); \
	bin_version=$$(grep 'echo "shellspec-format ' $(VERSION_BIN) | sed 's/.*shellspec-format \([0-9.]*\).*/\1/'); \
	echo "  Lua module:      $$lua_version"; \
	echo "  VimScript:       $$vim_version"; \
	echo "  Binary script:   $$bin_version"; \
	if [ "$$lua_version" = "$$vim_version" ] && [ "$$vim_version" = "$$bin_version" ]; then \
		echo "  $(GREEN)✓ All versions match$(NC)"; \
	else \
		echo "  $(RED)✗ Version mismatch detected$(NC)"; \
		exit 1; \
	fi

# Linting targets
.PHONY: lint
lint: ## Run all linters
	@echo "$(BLUE)Running all linters...$(NC)"
	$(PRE_COMMIT) run --all-files

.PHONY: lint-fix
lint-fix: format ## Run linters with auto-fix (alias for format)

.PHONY: format
format: ## Format all code (auto-fix where possible)
	@echo "$(BLUE)Formatting all code...$(NC)"
	$(PRE_COMMIT) run --all-files

.PHONY: lint-lua
lint-lua: ## Format Lua code with StyLua
	@echo "$(BLUE)Formatting Lua code...$(NC)"
	$(PRE_COMMIT) run stylua-github --all-files

.PHONY: lint-shell
lint-shell: ## Lint shell scripts with ShellCheck and format with shfmt
	@echo "$(BLUE)Linting shell scripts...$(NC)"
	$(PRE_COMMIT) run shellcheck --all-files
	$(PRE_COMMIT) run shfmt --all-files

.PHONY: lint-markdown
lint-markdown: ## Lint and format Markdown files
	@echo "$(BLUE)Linting Markdown files...$(NC)"
	$(PRE_COMMIT) run markdownlint --all-files

.PHONY: lint-yaml
lint-yaml: ## Lint YAML files
	@echo "$(BLUE)Linting YAML files...$(NC)"
	$(PRE_COMMIT) run yamllint --all-files

# Testing targets
.PHONY: test
test: ## Run complete test suite
	@echo "$(BLUE)Running complete test suite...$(NC)"
	$(TEST_RUNNER)

.PHONY: test-unit
test-unit: ## Run only Lua unit tests
	@echo "$(BLUE)Running unit tests...$(NC)"
	cd tests && timeout 30 nvim --headless -u NONE -c "set rtp+=.." -c "luafile format_spec.lua" -c "quit"

.PHONY: test-integration
test-integration: ## Run integration tests
	@echo "$(BLUE)Running integration tests...$(NC)"
	cd tests && timeout 30 ./integration_test.sh

.PHONY: test-golden
test-golden: ## Run golden master tests
	@echo "$(BLUE)Running golden master tests...$(NC)"
	cd tests && timeout 30 ./golden_master_test.sh

.PHONY: test-bin
test-bin: ## Run standalone formatter tests
	@echo "$(BLUE)Running standalone formatter tests...$(NC)"
	cd tests && ./bin_format_spec.sh

# Release targets
.PHONY: release
release: ## Interactive release (prompts for version type)
	@echo "$(BLUE)Interactive Release$(NC)"
	@echo ""
	@echo "Select release type:"
	@echo "  1) $(GREEN)patch$(NC) (2.0.0 → 2.0.1) - Bug fixes"
	@echo "  2) $(YELLOW)minor$(NC) (2.0.0 → 2.1.0) - New features"
	@echo "  3) $(RED)major$(NC) (2.0.0 → 3.0.0) - Breaking changes"
	@echo ""
	@read -p "Enter choice (1-3): " choice; \
	case $$choice in \
		1) $(MAKE) release-patch ;; \
		2) $(MAKE) release-minor ;; \
		3) $(MAKE) release-major ;; \
		*) echo "$(RED)Invalid choice$(NC)"; exit 1 ;; \
	esac

.PHONY: release-patch
release-patch: ## Bump patch version (X.Y.Z → X.Y.Z+1)
	@$(MAKE) --no-print-directory _release TYPE=patch

.PHONY: release-minor
release-minor: ## Bump minor version (X.Y.Z → X.Y+1.0)
	@$(MAKE) --no-print-directory _release TYPE=minor

.PHONY: release-major
release-major: ## Bump major version (X.Y.Z → X+1.0.0)
	@$(MAKE) --no-print-directory _release TYPE=major

.PHONY: _release
_release: ## Internal release target (use release-* targets instead)
	@if [ "$(TYPE)" = "" ]; then echo "$(RED)Error: TYPE not specified$(NC)"; exit 1; fi
	@echo "$(BLUE)Starting $(TYPE) release...$(NC)"
	@echo ""

	# Check git status
	@echo "$(GREEN)Checking git status...$(NC)"
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "$(RED)Error: Working directory not clean$(NC)"; \
		git status --short; \
		exit 1; \
	fi
	@echo "  ✓ Working directory is clean"

	# Check version consistency
	@echo ""
	@echo "$(GREEN)Checking version consistency...$(NC)"
	@$(MAKE) --no-print-directory version-check

	# Run tests
	@echo ""
	@echo "$(GREEN)Running tests...$(NC)"
	@$(MAKE) --no-print-directory test

	# Run linters
	@echo ""
	@echo "$(GREEN)Running linters...$(NC)"
	@$(MAKE) --no-print-directory lint

	# Calculate new version
	@echo ""
	@echo "$(GREEN)Calculating new version...$(NC)"
	@current_version=$$(grep '_VERSION = ' $(VERSION_LUA) | sed 's/.*"\(.*\)".*/\1/'); \
	echo "  Current version: $$current_version"; \
	new_version=$$(echo "$$current_version" | awk -F. -v type=$(TYPE) '{ \
		if (type == "major") printf "%d.0.0", $$1+1; \
		else if (type == "minor") printf "%d.%d.0", $$1, $$2+1; \
		else if (type == "patch") printf "%d.%d.%d", $$1, $$2, $$3+1; \
	}'); \
	echo "  New version:     $$new_version"; \
	echo ""; \
	read -p "Continue with release? (y/N): " confirm; \
	if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
		echo "$(YELLOW)Release cancelled$(NC)"; \
		exit 1; \
	fi; \
	echo ""; \
	echo "$(GREEN)Updating version in files...$(NC)"; \
	sed -i.bak "s/M._VERSION = \".*\"/M._VERSION = \"$$new_version\"/" $(VERSION_LUA) && rm $(VERSION_LUA).bak; \
	sed -i.bak "s/let g:shellspec_version = '.*'/let g:shellspec_version = '$$new_version'/" $(VERSION_VIM) && rm $(VERSION_VIM).bak; \
	sed -i.bak "s/shellspec-format [0-9.]*/shellspec-format $$new_version/" $(VERSION_BIN) && rm $(VERSION_BIN).bak; \
	echo "  ✓ Updated $(VERSION_LUA)"; \
	echo "  ✓ Updated $(VERSION_VIM)"; \
	echo "  ✓ Updated $(VERSION_BIN)"; \
	echo ""; \
	echo "$(GREEN)Creating git commit...$(NC)"; \
	git add $(VERSION_LUA) $(VERSION_VIM) $(VERSION_BIN); \
	git commit -m "chore: bump version to $$new_version"; \
	echo "  ✓ Created commit"; \
	echo ""; \
	echo "$(GREEN)Creating git tag...$(NC)"; \
	git tag -a "v$$new_version" -m "Release version $$new_version"; \
	echo "  ✓ Created tag v$$new_version"; \
	echo ""; \
	echo "$(GREEN)$(TYPE) release completed successfully!$(NC)"; \
	echo ""; \
	echo "$(BLUE)Next steps:$(NC)"; \
	echo "  1. Review the changes: $(YELLOW)git show$(NC)"; \
	echo "  2. Push the release:   $(YELLOW)git push origin main --tags$(NC)"; \
	echo "  3. Create GitHub release from tag v$$new_version"; \
	echo ""

# Utility targets
.PHONY: clean
clean: ## Remove temporary files and test artifacts
	@echo "$(BLUE)Cleaning temporary files...$(NC)"
	find . -name "*.bak" -delete
	find . -name "*.tmp" -delete
	find /tmp -name "*shellspec*" -delete 2>/dev/null || true
	find /var/folders -name "*shellspec*" -delete 2>/dev/null || true
	@echo "  ✓ Cleaned temporary files"

.PHONY: install
install: ## Install pre-commit hooks
	@echo "$(BLUE)Installing pre-commit hooks...$(NC)"
	$(PRE_COMMIT) install
	@echo "  ✓ Pre-commit hooks installed"

# Development convenience targets
.PHONY: dev-setup
dev-setup: install ## Set up development environment
	@echo "$(BLUE)Setting up development environment...$(NC)"
	@$(MAKE) --no-print-directory check
	@echo ""
	@echo "$(GREEN)Development environment ready!$(NC)"

.PHONY: ci
ci: check test lint ## Run CI pipeline (check, test, lint)
	@echo ""
	@echo "$(GREEN)CI pipeline completed successfully!$(NC)"

# Debug targets
.PHONY: debug
debug: ## Show debug information
	@echo "$(BLUE)Debug Information$(NC)"
	@echo "$(BLUE)==================$(NC)"
	@echo ""
	@echo "$(GREEN)Environment:$(NC)"
	@echo "  PWD: $(PWD)"
	@echo "  SHELL: $(SHELL)"
	@echo "  MAKE: $(MAKE)"
	@echo ""
	@echo "$(GREEN)Git status:$(NC)"
	@git status --short || echo "  Not in git repository"
	@echo ""
	@echo "$(GREEN)Tools:$(NC)"
	@echo "  pre-commit: $$(which pre-commit || echo 'not found')"
	@echo "  git: $$(which git || echo 'not found')"
	@echo "  nvim: $$(which nvim || echo 'not found')"
	@echo ""
	@$(MAKE) --no-print-directory version-check

# Ensure all targets are PHONY (no file dependencies)
.PHONY: _release help check version version-check lint lint-fix format lint-lua lint-shell lint-markdown lint-yaml
.PHONY: test test-unit test-integration test-golden test-bin release release-patch release-minor release-major
.PHONY: clean install dev-setup ci debug
