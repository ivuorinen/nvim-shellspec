# Development Commands

## Key Make Targets

- `make help` - Show all available targets with descriptions
- `make check` - Quick health check (tools and version consistency)
- `make test` - Run complete test suite
- `make lint` - Run all linters
- `make format` - Format all code (auto-fix where possible)
- `make ci` - Full CI pipeline (check, test, lint)
- `make clean` - Remove temporary files
- `make dev-setup` - Set up development environment

## Testing

- `make test-unit` - Lua unit tests only
- `make test-integration` - Integration tests
- `make test-golden` - Golden master tests
- `make test-bin` - Standalone formatter tests
- Test runner: `./tests/run_tests.sh`

## Linting

- Uses pre-commit hooks
- ShellCheck for shell scripts
- StyLua for Lua formatting
- markdownlint for Markdown
- yamllint for YAML files
- shfmt for shell script formatting

## Version Management

- Three files must stay in sync:
  - `lua/shellspec/init.lua` (M._VERSION)
  - `plugin/shellspec.vim` (g:shellspec_version)
  - `bin/shellspec-format` (version string)
- `make version-check` verifies consistency
