# Neovim ShellSpec DSL Support

Advanced language support and formatter for ShellSpec DSL testing framework with first-class Neovim support.

## Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "ivuorinen/nvim-shellspec",
  ft = "shellspec",
  config = function()
    require("shellspec").setup({
      auto_format = true,
      indent_size = 2,
      indent_comments = true,
    })
  end,
}
```

### With [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'ivuorinen/nvim-shellspec'
```

### Manual Installation

```bash
git clone https://github.com/ivuorinen/nvim-shellspec.git ~/.config/nvim/pack/plugins/start/nvim-shellspec
```

## Features

- **🚀 First-class Neovim support** with modern Lua implementation
- **🎨 Syntax highlighting** for all ShellSpec DSL keywords
- **📐 Smart indentation** for block structures
- **📄 Enhanced filetype detection** for `*_spec.sh`, `*.spec.sh`, `spec/*.sh`, and `test/*.sh`
- **✨ Advanced formatting** with HEREDOC and comment support
- **⚡ Async formatting** to prevent blocking (Neovim 0.7+)
- **🔄 Backward compatibility** with Vim and older Neovim versions

### Advanced Formatting Features

- **HEREDOC Preservation**: Maintains original formatting within `<<EOF`, `<<'EOF'`, `<<"EOF"`, and `<<-EOF` blocks
- **Smart Comment Indentation**: Comments are indented to match surrounding code level
- **Context-Aware Formatting**: State machine tracks formatting context for accurate indentation

## Usage

### Commands

- `:ShellSpecFormat` - Format entire buffer
- `:ShellSpecFormatRange` - Format selected lines

### File Types

Plugin activates for files matching:

- `*_spec.sh`
- `*.spec.sh`
- `spec/*.sh`
- `test/*.sh`
- Files in nested `spec/` directories

## Configuration

### Neovim (Lua Configuration) - Recommended

```lua
require("shellspec").setup({
  -- Auto-format on save
  auto_format = true,

  -- Indentation settings
  indent_size = 2,
  use_spaces = true,

  -- Comment indentation (align with code level)
  indent_comments = true,

  -- HEREDOC patterns (customizable)
  heredoc_patterns = {
    "<<[A-Z_][A-Z0-9_]*",  -- <<EOF, <<DATA, etc.
    "<<'[^']*'",           -- <<'EOF'
    '<<"[^"]*"',           -- <<"EOF"  
    "<<-[A-Z_][A-Z0-9_]*", -- <<-EOF
  },

  -- Other options
  preserve_empty_lines = true,
  max_line_length = 160,
})

-- Custom keybindings
vim.keymap.set('n', '<leader>sf', '<cmd>ShellSpecFormat<cr>', { desc = 'Format ShellSpec buffer' })
vim.keymap.set('v', '<leader>sf', '<cmd>ShellSpecFormatRange<cr>', { desc = 'Format ShellSpec selection' })
```

### Vim/Legacy Configuration

```vim
" Enable auto-formatting on save
let g:shellspec_auto_format = 1

" Enable comment indentation (default: 1)
let g:shellspec_indent_comments = 1

" Custom keybindings
autocmd FileType shellspec nnoremap <buffer> <leader>f :ShellSpecFormat<CR>
autocmd FileType shellspec vnoremap <buffer> <leader>f :ShellSpecFormatRange<CR>
```

## Examples

### HEREDOC Formatting

The formatter intelligently handles HEREDOC blocks:

```shellspec
Describe "HEREDOC handling"
  It "preserves original formatting within HEREDOC"
    When call cat <<EOF
      This indentation is preserved
        Even nested indentation
    And this too
EOF
    The output should equal expected
  End
End
```

### Comment Indentation

Comments are properly aligned with surrounding code:

```shellspec
Describe "Comment handling"
  # This comment is indented to match the block level
  It "should handle comments correctly"
    # This comment matches the It block indentation
    When call echo "test"
    The output should equal "test"
  End
  # Back to Describe level indentation
End
```

## Testing

This plugin includes comprehensive tests to ensure formatting quality and reliability.

### Running Tests

```bash
# Run all test suites
./tests/run_tests.sh

# Run individual test suites
lua tests/format_spec.lua          # Unit tests
./tests/integration_test.sh        # Integration tests  
./tests/golden_master_test.sh      # Golden master tests
```

### Test Suites

- **Unit Tests** (`tests/format_spec.lua`): Test core formatting functions with Lua - includes vim API mocking for standalone execution
- **Integration Tests** (`tests/integration_test.sh`): Test plugin loading, command registration, and end-to-end functionality in Neovim
- **Golden Master Tests** (`tests/golden_master_test.sh`): Compare actual formatting output against expected results using dynamic test generation

### Test Architecture

The test suite uses **dynamic test generation** to avoid pre-commit hook interference:

- **No external fixture files**: Test data is defined programmatically within the test scripts
- **Pre-commit safe**: No `.spec.sh` fixture files that can be modified by formatters
- **Maintainable**: Test cases are co-located with test logic for easy updates
- **Comprehensive coverage**: Tests basic indentation, comment handling, HEREDOC preservation, and nested contexts

### Test Development

When adding features or fixing bugs:

1. Add unit tests for new formatting logic in `tests/format_spec.lua`
2. Add integration tests for new commands/features in `tests/integration_test.sh`
3. Add golden master test cases in the `TEST_CASES` array in `tests/golden_master_test.sh`
4. Run `./tests/run_tests.sh` to verify all tests pass

Example of adding a golden master test case:

```bash
"test_name|input_content|expected_content"
```

## Contributing

Contributions welcome! Please open issues and pull requests at:
<https://github.com/ivuorinen/nvim-shellspec>

## License

MIT License - see repository for details.

## Related

- [ShellSpec](https://github.com/shellspec/shellspec) - BDD testing framework for shell scripts
