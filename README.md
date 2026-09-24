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
- **📄 Filetype detection** for `*_spec.sh`, `*.spec.sh` (any directory), and `.sh` files under `spec/`
- **✨ Advanced formatting** with HEREDOC and comment support
- **⚡ Deferred formatting** via `:ShellSpecFormatAsync` (Neovim 0.10+)
- **🔄 Backward compatibility** with Vim and older Neovim versions

### Advanced Formatting Features

- **HEREDOC Preservation**: Maintains original formatting within `<<EOF`, `<< EOF`, `<<eof`, `<<\EOF`,
  `<<'EOF'`, `<<"EOF"`, and `<<-EOF` blocks. The terminator line stays at its original column — the shell
  requires a non-`<<-` delimiter at column 0, so indenting it would leave the HEREDOC unterminated. Lines
  containing `((` (arithmetic such as `$(( a << b ))`) never open a HEREDOC.
- **Block awareness**: `Describe`/`Context`/`It` and friends, hooks, `Mock`, `Data`, `Data:raw`/`Data:expand`,
  `Parameters` and `Parameters:block|value|matrix|dynamic` all open an indent level closed by `End`.
- **Smart Comment Indentation**: Comments are indented to match surrounding code level
- **Context-Aware Formatting**: State machine tracks formatting context for accurate indentation.
  Here-strings (`<<<`) and comments that merely mention a delimiter do not start a HEREDOC.

## Usage

### Commands

- `:ShellSpecFormat` - Format entire buffer
- `:ShellSpecFormatRange` - Format selected lines. The indent level is taken from the first line of the
  range, so a selection nested inside a `Describe`/`Context` keeps its place in the block structure.
- `:ShellSpecFormatAsync` - Format the buffer on the next event-loop tick (Neovim only)

`gq` also works: `formatexpr` is set for shellspec buffers and formats the motion's range.

Full reference: `:help shellspec`

### File Types

Plugin activates for files matching:

- `*_spec.sh` (any directory, any depth)
- `*.spec.sh` (any directory, any depth)
- `spec/*.sh`, at any depth below a `spec/` directory

The first two are matched against the file's basename, so a spec named `*_spec.sh` or `*.spec.sh`
is detected wherever it lives — including under `test/`.

The `spec/` rule is registered twice, as `spec/*.sh` and `*/spec/*.sh`. Vim matches a pattern
containing a slash against both the name as typed and the full path, so the bare form catches
`nvim spec/foo.sh` while the `*/` form catches `nvim /abs/path/spec/foo.sh`.

> **Changed since 2.0.2:** a `test/*.sh` rule used to claim *every* shell script under a `test/`
> directory, including ordinary scripts that are not specs. It has been removed. Spec files under
> `test/` are still detected by the basename rules above; if you keep specs there under other names,
> add the rule back yourself:
>
> ```vim
> autocmd BufRead,BufNewFile test/*.sh set filetype=shellspec
> ```
>
> Use `set filetype=`, not `setfiletype`: the runtime's own `*.sh` rule has already set `sh`, and
> `setfiletype` never overrides an existing filetype.

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

  -- HEREDOC openers. Lua patterns, each with exactly one capture group
  -- holding the delimiter; a pattern without one is skipped. The list is
  -- replaced wholesale, not merged, so a shorter list drops the defaults.
  heredoc_patterns = {
    "<<%-?%s*\\?([%a_][%w_]*)", -- <<EOF, << EOF, <<eof, <<\EOF, <<-EOF
    "<<%-?%s*'([^']+)'",        -- <<'EOF'
    '<<%-?%s*"([^"]+)"',        -- <<"EOF"
  },
})

-- Unknown keys are reported via vim.notify rather than silently ignored.

-- Custom keybindings. The visual mapping uses `:`, not `<cmd>`: a <cmd>
-- mapping passes no '<,'> range, so it would format only the cursor line.
vim.keymap.set('n', '<leader>sf', '<cmd>ShellSpecFormat<cr>', { desc = 'Format ShellSpec buffer' })
vim.keymap.set('x', '<leader>sf', ':ShellSpecFormatRange<cr>', { desc = 'Format ShellSpec selection' })
```

The plugin does not change `'foldmethod'`; set your own folding in an `ftplugin/shellspec.lua` if you
want it.

### Vim/Legacy Configuration

The VimScript fallback (Vim, and Neovim before 0.10) reads two globals. Indent width comes from
`'shiftwidth'` and `'expandtab'` rather than a plugin variable, so it follows the buffer's own
settings; `indent_size`, `use_spaces` and `heredoc_patterns` are Neovim-only.

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
make test

# Run individual test suites
make test-unit           # Lua unit tests (requires Neovim)
make test-integration    # Plugin loading, commands, filetype, health, Vim fallback
make test-golden         # Golden master formatting comparisons
make test-bin            # Standalone bin/shellspec-format
make test-parity         # All three implementations must agree
```

The unit tests require Neovim — they call `vim.api` directly and are run through
`nvim --headless`, not `lua`.

### Test Suites

- **Unit Tests** (`tests/format_spec.lua`): Core formatting functions, every HEREDOC pattern branch, each
  configuration option, and the `format_buffer` / `format_selection` buffer entry points
- **Integration Tests** (`tests/integration_test.sh`): Plugin loading, command registration, filetype detection,
  `:checkhealth`, and the VimScript fallback formatting a real file
- **Golden Master Tests** (`tests/golden_master_test.sh`): Compare actual formatting output against expected results using dynamic test generation
- **Standalone Formatter Tests** (`tests/bin_format_spec.sh`): `bin/shellspec-format` via stdin and in-place,
  including CLI options and file-mode preservation
- **Parity Tests** (`tests/parity_test.sh`): Run one fixture through the Lua, VimScript and bash implementations
  and require byte-identical output, so the three cannot drift apart again

### Test Architecture

The test suite uses **dynamic test generation** to avoid pre-commit hook interference:

- **No external fixture files**: Test data is defined programmatically within the test scripts. There are no
  committed `.spec.sh` files anywhere in the repository — one used to sit at the root, contradicting this rule.
- **Pre-commit safe**: No `.spec.sh` fixture files that can be modified by formatters
- **Maintainable**: Test cases are co-located with test logic for easy updates
- **Comprehensive coverage**: Tests basic indentation, comment handling, HEREDOC preservation, and nested contexts

### Test Development

When adding features or fixing bugs:

1. Add unit tests for new formatting logic in `tests/format_spec.lua`
2. Add integration tests for new commands/features in `tests/integration_test.sh`
3. Add golden master test cases with `add_case` in `tests/golden_master_test.sh`
4. If the change touches formatting behaviour, apply it to **all three** implementations
   (`lua/shellspec/format.lua`, `autoload/shellspec.vim`, `bin/shellspec-format`) — `make test-parity`
   fails if they disagree. Block-keyword changes also belong in `autoload/shellspec/indent.vim`.
5. Run `make test` to verify all tests pass

Example of adding a golden master test case (name, input, expected — three separate arguments, so
content may freely contain `|` and ShellSpec's `#|` data lines):

```bash
add_case my_case "Describe \"x\"
It \"y\"
End
End" "Describe \"x\"
  It \"y\"
  End
End"
```

## Development

Tool versions are pinned in [`mise.toml`](mise.toml):

```bash
mise install            # fetch luacheck and prek at the pinned versions
make check              # verify tooling and version consistency
make lint               # run every hook in .pre-commit-config.yaml
make lint-lua           # StyLua + Luacheck only
```

The `make lint*` targets and `make install` run [prek](https://github.com/j178/prek), a drop-in
replacement for the `pre-commit` runner that reads the same `.pre-commit-config.yaml` and
substitutes Rust implementations for the `pre-commit/pre-commit-hooks` entries automatically.

Nothing in the config is prek-specific — prek-only syntax (`repo: builtin`) is deliberately not
used — so `pre-commit run --all-files` still checks exactly the same things if you prefer it:

```bash
mise exec -- prek run --all-files   # what `make lint` does
pre-commit run --all-files          # identical result, upstream runner
```

Lua linting uses [Luacheck](https://github.com/lunarmodules/luacheck), configured in
[`.luacheckrc`](.luacheckrc). It runs as a `language: system` pre-commit hook backed by the
mise-pinned binary rather than via luacheck's official hook, which declares `language: lua` and
requires luarocks on every machine.

## Contributing

Contributions welcome! Please open issues and pull requests at:
<https://github.com/ivuorinen/nvim-shellspec>

## License

MIT License - see [LICENSE](LICENSE).

## Related

- [ShellSpec](https://github.com/shellspec/shellspec) - BDD testing framework for shell scripts
