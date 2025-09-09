# Development Commands for nvim-shellspec

## Quality Assurance & Linting Commands

### Primary Linting Command

```bash
pre-commit run --all-files
```

This runs all configured linters and formatters including:

- ShellCheck for shell scripts
- shfmt for shell script formatting
- yamllint for YAML files
- markdownlint for Markdown files
- Various pre-commit hooks

### Individual Linters

```bash
# YAML linting
yamllint .

# Markdown linting (via npx)
npx markdownlint-cli -c .markdownlint.json --fix README.md

# Shell script linting
shellcheck bin/shellspec-format

# Shell script formatting
shfmt -w bin/shellspec-format

# Lua linting (if available)
luacheck lua/shellspec/
```

## Code Formatting

### ShellSpec DSL Formatting

```bash
# Using standalone formatter
./bin/shellspec-format file.spec.sh

# Or in Neovim/Vim
:ShellSpecFormat
:ShellSpecFormatRange (for selected lines)
```

### Testing New Lua Implementation (Neovim)

```lua
-- Test in Neovim command line
:lua require('shellspec').setup({ auto_format = true })
:lua require('shellspec').format_buffer()

-- Health check
:checkhealth shellspec
```

## Development Testing

### Manual Plugin Testing

```bash
# Create test file
touch test_example.spec.sh

# Test in Neovim
nvim test_example.spec.sh
# Verify filetype: :set filetype?
# Test formatting: :ShellSpecFormat
# Test health check: :checkhealth shellspec
```

### HEREDOC and Comment Testing

Create test content with:

```shellspec
Describe "test"
  # Comment that should be indented
  It "should preserve HEREDOC"
    cat <<EOF
      This should not be reformatted
        Even with nested indentation
EOF
  End
End
```

## Git Integration

```bash
# Pre-commit hooks are automatically installed
pre-commit install

# Run pre-commit on all files
pre-commit run --all-files
```

## Neovim-Specific Development

### Lua Module Testing

```bash
# Test individual modules in Neovim
:lua print(vim.inspect(require('shellspec.config').defaults))
:lua require('shellspec.format').format_buffer()
:lua require('shellspec.autocmds').setup()
```

### Health Diagnostics

```bash
# Comprehensive health check
:checkhealth shellspec

# Check if modules load correctly
:lua require('shellspec.health').check()
```

## File System Utilities (macOS/Darwin)

```bash
# File operations
ls -la          # List files with details
find . -name    # Find files by pattern
grep -r         # Search in files (or use rg for ripgrep)

# Better alternatives available on system:
rg              # ripgrep for faster searching
fd              # faster find alternative

# Find all ShellSpec files in project
fd -e spec.sh
fd "_spec.sh$"
rg -t sh "Describe|Context|It" spec/
```

## Development Workflow

### Standard Development

1. Make changes to Vim script or Lua files
2. Test with sample ShellSpec files (`test_example.spec.sh`)
3. Run `pre-commit run --all-files` before committing
4. Fix any linting issues
5. Test in both Neovim (Lua path) and Vim (VimScript path)
6. Commit changes

### Feature Development

1. Update Lua implementation in `lua/shellspec/`
2. Update VimScript compatibility in `autoload/shellspec.vim`
3. Test dual implementation paths
4. Update health checks if needed
5. Update documentation

### Configuration Testing

```lua
-- Test different configurations
require('shellspec').setup({
  auto_format = true,
  indent_size = 4,
  indent_comments = false,
  heredoc_patterns = {"<<[A-Z_]+", "<<'[^']*'"}
})
```

## Performance Testing

```bash
# Test with large ShellSpec files
time nvim +':ShellSpecFormat' +':wq' large_spec_file.spec.sh

# Compare Lua vs VimScript performance
# (Use older Neovim version to force VimScript path)
```

## Plugin Integration Testing

```lua
-- Test with lazy.nvim
{
  dir = "/path/to/local/nvim-shellspec",
  config = function()
    require("shellspec").setup({ auto_format = true })
  end
}
```

## Memory and State Debugging

```lua
-- Debug configuration state
:lua print(vim.inspect(require('shellspec.config').config))

-- Debug formatting state
:lua require('shellspec.format').format_lines({"Describe 'test'", "  It 'works'", "  End", "End"})
```
