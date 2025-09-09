# Release Process

## Command
Always use `make release` for releases, not manual version bumping.

## Available Release Commands
- `make release` - Interactive release with menu (patch/minor/major)
- `make release-patch` - Bump patch version (X.Y.Z → X.Y.Z+1)
- `make release-minor` - Bump minor version (X.Y.Z → X.Y+1.0)
- `make release-major` - Bump major version (X.Y.Z → X+1.0.0)

## What make release does:
1. Checks git status is clean
2. Verifies version consistency across files
3. Runs complete test suite
4. Runs all linters
5. Calculates and prompts for new version
6. Updates versions in all files:
   - `lua/shellspec/init.lua` - M._VERSION
   - `plugin/shellspec.vim` - g:shellspec_version
   - `bin/shellspec-format` - version string
7. Creates git commit with version bump
8. Creates git tag (with v prefix, e.g., v2.0.3)
9. Provides next steps for pushing

## Manual Process (DO NOT USE)
The old manual process was error-prone and didn't update all version files consistently.