# Code Style and Conventions

## EditorConfig Settings

All files follow these rules from `.editorconfig`:

- **Charset**: UTF-8
- **Line endings**: LF (Unix-style)
- **Indentation**: 2 spaces (no tabs)
- **Max line length**: 160 characters
- **Final newline**: Required
- **Trim trailing whitespace**: Yes

### Special Cases

- **Markdown files**: Don't trim trailing whitespace (for hard line breaks)
- **Makefiles**: Use tabs with width 4

## Lua Code Conventions (New)

### Module Structure

```lua
-- Module header with description
local M = {}

-- Import dependencies at top
local config = require('shellspec.config')

-- Private functions (local)
local function private_helper() end

-- Public functions (M.function_name)
function M.public_function() end

return M
```

### Function Names

- Use `snake_case` for all functions
- Private functions: `local function name()`
- Public functions: `function M.name()` or `M.name = function()`
- Descriptive names, avoid abbreviations

### Variable Names

- Local variables: `local variable_name`
- Constants: `local CONSTANT_NAME` (uppercase)
- Table keys: `snake_case`

### Documentation

- Use LuaDoc style comments for public functions
- Include parameter and return type information

```lua
--- Format lines with ShellSpec DSL rules
-- @param lines table: Array of strings to format
-- @return table: Array of formatted strings
function M.format_lines(lines) end
```

### Error Handling

- Use `pcall()` for operations that might fail
- Provide meaningful error messages
- Use `vim.notify()` for user-facing messages

## Vim Script Conventions (Enhanced)

### Function Names

- Use `snake_case#function_name()` format
- Functions in autoload use namespace prefix: `shellspec#function_name()`
- Guard clauses with `abort` keyword: `function! shellspec#format_buffer() abort`
- Private functions: `s:function_name()`

### Variable Names

- Local variables: `l:variable_name`
- Global variables: `g:variable_name`
- Buffer-local: `b:variable_name`
- Script-local: `s:variable_name`

### State Management

- Use descriptive state names: `'normal'`, `'heredoc'`
- Document state transitions in comments
- Initialize state variables clearly

### Code Structure

```vim
" File header with description and author
if exists('g:loaded_plugin')
  finish
endif
let g:loaded_plugin = 1

" Helper functions (private)
function! s:private_function() abort
endfunction

" Public functions
function! public#function() abort
endfunction

" Commands, autocommands at end
```

### Comments

- Use `"` for comments
- Include descriptive headers for functions
- Comment complex logic blocks and state changes
- Document HEREDOC patterns and detection logic

## Shell Script Style (bin/shellspec-format)

- Use `#!/bin/bash` shebang
- Double quote variables: `"$variable"`
- Use `[[ ]]` for conditionals instead of `[ ]`
- Proper error handling with exit codes
- Function names in `snake_case`

## Configuration Files

- **YAML**: 2-space indentation, 200 character line limit
- **JSON**: Pretty formatted, no trailing commas
- **Markdown**: 200 character line limit (relaxed from default 80)
- **Lua**: Follow Neovim Lua style guide

## Naming Conventions

- **Files**: lowercase with hyphens (`shellspec-format`)
- **Directories**: lowercase (`autoload`, `syntax`, `ftdetect`)
- **Lua modules**: lowercase with dots (`shellspec.format`)
- **Functions**: namespace#function_name format (VimScript), snake_case (Lua)
- **Variables**: descriptive names, avoid abbreviations

## Architecture Patterns

### Dual Implementation Pattern

```vim
" Detect environment and choose implementation
if has('nvim-0.7')
  " Use Lua implementation
  lua require('module').function()
else
  " Fall back to VimScript
  call legacy#function()
endif
```

### State Machine Pattern (Both Lua and VimScript)

```lua
-- Lua version
local state = State.NORMAL
if state == State.NORMAL then
  -- handle normal formatting
elseif state == State.IN_HEREDOC then
  -- preserve heredoc content
end
```

```vim
" VimScript version
let l:state = 'normal'
if l:state ==# 'normal'
  " handle normal formatting
elseif l:state ==# 'heredoc'
  " preserve heredoc content
endif
```

### Configuration Pattern

```lua
-- Lua: Use vim.tbl_deep_extend for merging
local config = vim.tbl_deep_extend("force", defaults, user_opts)
```

```vim
" VimScript: Use get() with defaults
let l:option = get(g:, 'plugin_option', default_value)
```

## Testing Conventions

- Create test files with `.spec.sh` extension
- Test both Lua and VimScript implementations
- Include HEREDOC and comment test cases
- Use descriptive test names matching actual ShellSpec patterns

## Documentation Standards

- Update README.md with new features
- Include both Lua and VimScript configuration examples
- Provide clear examples of HEREDOC and comment behavior
- Document breaking changes and migration paths
