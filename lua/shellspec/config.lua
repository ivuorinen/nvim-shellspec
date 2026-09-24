-- ShellSpec configuration management
local M = {}

-- Default configuration
M.defaults = {
  -- Auto-format on save
  auto_format = false,

  -- Indentation settings
  indent_size = 2,
  use_spaces = true,

  -- HEREDOC detection. Lua patterns, each with exactly one capture group
  -- holding the delimiter -- `format.detect_heredoc_start` reads the capture,
  -- so a pattern without one matches but yields no delimiter and is skipped.
  --
  -- `%s*` and the optional backslash cover the POSIX spellings `<< EOF` and
  -- `<<\EOF`, and `%a` covers lowercase words; without them the terminator was
  -- indented and the shell never closed the HEREDOC.
  heredoc_patterns = {
    "<<%-?%s*\\?([%a_][%w_]*)", -- <<EOF, << EOF, <<eof, <<\EOF, <<-EOF
    "<<%-?%s*'([^']+)'", -- <<'EOF'
    '<<%-?%s*"([^"]+)"', -- <<"EOF"
  },

  -- Comment indentation
  indent_comments = true,
}

-- Current configuration
M.config = {}

--- True when `pattern` has exactly one Lua capture group, and it is not `()`.
---
--- Every `%x` escape is stripped before counting, so `%(` is not a capture while
--- the `(` in `%%(` still is (`%%` is a literal percent). Exactly one, because
--- string.match returns the first capture as the delimiter: `"<<(E)(OF)"`
--- yielded "E", which no terminator line equals. A position capture `()`
--- yields a number, which no terminator line equals either.
local function has_single_capture(pattern)
  local stripped = pattern:gsub("%%.", "")
  local _, count = stripped:gsub("%(", "")
  return count == 1 and not stripped:find("()", 1, true)
end

--- Drop HEREDOC patterns that do not carry exactly one capture group, warning
--- about each.
---
--- Before these patterns were wired up they were dead config, and the values
--- this project's own README published carried no capture group. Reading such a
--- pattern would return the whole match -- "<<EOF" rather than "EOF" -- as the
--- delimiter, which no terminator line can equal, so the formatter would stay
--- in its HEREDOC state and silently stop formatting the rest of the file. A
--- pattern with several captures fails the same way on its first capture.
--- Dropping them restores the old no-op behaviour and says why.
function M.validate_heredoc_patterns(patterns)
  local valid = {}
  for _, pattern in ipairs(patterns) do
    if has_single_capture(pattern) then
      table.insert(valid, pattern)
    else
      vim.notify(
        "shellspec: ignoring heredoc_pattern without exactly one capture group: "
          .. pattern
          .. '\n  the pattern must capture only the delimiter, e.g. "<<%-?%s*([%a_][%w_]*)"',
        vim.log.levels.WARN
      )
    end
  end

  if #valid == 0 then
    vim.notify("shellspec: no usable heredoc_patterns, falling back to defaults", vim.log.levels.WARN)
    return M.defaults.heredoc_patterns
  end

  return valid
end

--- Merge `opts` over the defaults and validate the result.
---
--- Unknown keys are reported rather than ignored: `vim.tbl_deep_extend` accepts
--- anything, so a typo or an option this plugin does not implement would
--- otherwise be silently accepted and have no effect.
function M.setup(opts)
  opts = opts or {}

  for key in pairs(opts) do
    if M.defaults[key] == nil then
      vim.notify("shellspec: unknown option '" .. key .. "'", vim.log.levels.WARN)
    end
  end

  M.config = vim.tbl_deep_extend("force", M.defaults, opts)

  -- Replaced, not merged: `tbl_deep_extend` merges list-like tables by index, so
  -- a user list shorter than the default would keep whichever defaults sit past
  -- its end -- a two-pattern override would silently retain the third default.
  if opts.heredoc_patterns then
    M.config.heredoc_patterns = M.validate_heredoc_patterns(opts.heredoc_patterns)
  end

  -- Integral as well as positive: a float such as 2.5 is rejected by
  -- 'shiftwidth', which made every shellspec FileType event raise, and
  -- string.rep truncated it differently at each indent level.
  local size = M.config.indent_size
  if type(size) ~= "number" or size < 1 or size % 1 ~= 0 then
    vim.notify("shellspec: indent_size must be a positive integer", vim.log.levels.WARN)
    M.config.indent_size = M.defaults.indent_size
  end
end

-- Get configuration value
function M.get(key)
  return M.config[key]
end

-- Initialize with defaults
M.setup()

return M
