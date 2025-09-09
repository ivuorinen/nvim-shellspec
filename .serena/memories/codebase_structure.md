# Codebase Structure

## Directory Layout

```text
nvim-shellspec/
├── lua/shellspec/          # Modern Neovim Lua implementation
│   ├── init.lua           # Main module entry point & setup
│   ├── config.lua         # Configuration management
│   ├── format.lua         # Enhanced formatting engine
│   ├── autocmds.lua       # Neovim-native autocommands
│   └── health.lua         # Health check support
├── autoload/              # Plugin functions (VimScript)
│   └── shellspec.vim      # Enhanced formatting with HEREDOC support
├── bin/                   # Standalone executables
│   └── shellspec-format   # Bash formatter script
├── ftdetect/              # Filetype detection
│   └── shellspec.vim      # Auto-detect ShellSpec files
├── indent/                # Indentation rules
│   └── shellspec.vim      # Smart indentation for ShellSpec DSL
├── plugin/                # Main plugin file (loaded at startup)
│   └── shellspec.vim      # Neovim detection & dual implementation
├── syntax/                # Syntax highlighting
│   └── shellspec.vim      # ShellSpec DSL syntax rules
└── .github/               # GitHub workflows and templates
```

## Core Files

### Lua Implementation (Neovim 0.7+)

#### lua/shellspec/init.lua

- Main module entry point with setup() function
- Lua configuration interface
- Health check integration (:checkhealth support)
- Backward compatibility functions for VimScript

#### lua/shellspec/config.lua

- Configuration management with defaults
- Validation and type checking
- Support for:
  - Auto-format settings
  - Indentation preferences
  - HEREDOC pattern customization
  - Comment indentation options

#### lua/shellspec/format.lua

- Advanced formatting engine with state machine
- HEREDOC detection and preservation
- Smart comment indentation
- Context-aware formatting (normal, in-heredoc states)
- Async formatting capabilities

#### lua/shellspec/autocmds.lua

- Neovim-native autocommands using vim.api
- Buffer-local settings and commands
- Enhanced filetype detection patterns
- Auto-format on save integration

#### lua/shellspec/health.lua

- Comprehensive health checks for :checkhealth
- Configuration validation
- Module loading verification
- Project ShellSpec file detection

### VimScript Implementation (Compatibility)

#### plugin/shellspec.vim

- **Dual Implementation Logic**: Detects Neovim 0.7+ and loads appropriate implementation
- **Neovim Path**: Loads Lua modules and creates command delegators
- **Vim Path**: Falls back to enhanced VimScript implementation
- Maintains all existing functionality

#### autoload/shellspec.vim

- **Enhanced VimScript formatter** with same features as Lua version
- HEREDOC detection patterns and state machine
- Smart comment indentation logic
- Backward compatibility with older Vim versions

### Traditional Vim Plugin Structure

#### ftdetect/shellspec.vim

- Automatic filetype detection for ShellSpec files
- Patterns: `*_spec.sh`, `*.spec.sh`, `spec/*.sh`, `test/*.sh`
- Enhanced with nested spec directory support

#### indent/shellspec.vim

- Smart indentation based on ShellSpec block structure
- Handles `Describe`, `Context`, `It` blocks and their variants
- Special handling for `End` keyword and `Data`/`Parameters` blocks

#### syntax/shellspec.vim

- Complete syntax highlighting for ShellSpec DSL
- Keywords: Block structures, control flow, evaluation, expectations, hooks
- Supports nested shell code regions
- Proper highlighting for strings, variables, comments

## Configuration Files

### Development & Quality

- `.pre-commit-config.yaml` - Pre-commit hooks configuration
- `.mega-linter.yml` - MegaLinter configuration
- `.yamllint.yml` - YAML linting rules
- `.markdownlint.json` - Markdown linting rules
- `.editorconfig` - Editor configuration

### Git & CI/CD

- `.github/workflows/` - GitHub Actions for CI
- `.gitignore` - Git ignore patterns

## ShellSpec DSL Keywords Supported

- **Blocks**: Describe, Context, ExampleGroup, It, Specify, Example
- **Prefixed blocks**: xDescribe, fDescribe (skip/focus variants)
- **Hooks**: BeforeEach, AfterEach, BeforeAll, AfterAll
- **Evaluation**: When, call, run, command, script, source
- **Expectations**: The, Assert, should, output, stdout, error, stderr
- **Helpers**: Dump, Include, Set, Path, File, Dir, Data, Parameters

## Architecture Benefits

- **Performance**: Lua implementation for better performance in Neovim
- **Modern APIs**: Uses Neovim's native autocmd and formatting APIs
- **Maintainability**: Modular structure with clear separation of concerns
- **Extensibility**: Easy to add new features through Lua configuration
- **Compatibility**: Seamless fallback ensures broad editor support
