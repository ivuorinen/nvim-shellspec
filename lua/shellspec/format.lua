-- Enhanced ShellSpec DSL formatter with HEREDOC support
local config = require("shellspec.config")
local M = {}

-- Formatting state
local State = {
  NORMAL = 1,
  IN_HEREDOC = 2,
}

--- Lines that open a block, and so increase the indent of everything after them.
---
--- Block keywords require a following space and standalone hooks require end of
--- line. Without those anchors an ordinary assignment such as `Items=3` matches
--- `It` and opens a block that is never closed, cascading misindentation through
--- the rest of the file.
---
--- `Mock`, `Data:raw`/`Data:expand` and the `Parameters:` variants open blocks
--- too; without them their `End` closed the enclosing block instead.
local BLOCK_PATTERNS = {
  "^[xf]?Describe%s",
  "^[xf]?Context%s",
  "^[xf]?ExampleGroup%s",
  "^[xf]?It%s",
  "^[xf]?Specify%s",
  "^[xf]?Example%s",
  "^Mock%s",
  "^Data%s*$",
  "^Data:%l+%s*$",
  "^Parameters%s*$",
  "^Parameters:%l+%s*$",
  "^BeforeEach%s*$",
  "^AfterEach%s*$",
  "^BeforeAll%s*$",
  "^AfterAll%s*$",
  "^Before%s*$",
  "^After%s*$",
  "^BeforeCall%s*$",
  "^AfterCall%s*$",
  "^BeforeRun%s*$",
  "^AfterRun%s*$",
}

local function debug(msg)
  if vim.g.shellspec_debug then
    vim.notify("ShellSpec: " .. msg, vim.log.levels.DEBUG)
  end
end

--- Return the HEREDOC delimiter a line opens, or nil.
---
--- Here-strings are rejected before any pattern runs: `<<<"word"` contains `<<"`
--- at offset 1 and would otherwise match the double-quoted pattern, leaving the
--- formatter in a HEREDOC state that no later line can end. An empty delimiter is
--- rejected for the same reason -- `is_heredoc_end` can never match one, so the
--- rest of the file would be swallowed.
---
--- Lines containing `((` are rejected as well: the default patterns accept a
--- blank after `<<`, so the arithmetic shift in `$(( a << b ))` would otherwise
--- open a HEREDOC that swallows the rest of the file.
---
--- Patterns come from config so a project can add its own; each must carry
--- exactly one capture group holding the delimiter.
local function detect_heredoc_start(trimmed)
  if trimmed:find("<<<", 1, true) or trimmed:find("((", 1, true) then
    return nil
  end

  for _, pattern in ipairs(config.get("heredoc_patterns")) do
    local delimiter = string.match(trimmed, pattern)
    if delimiter and delimiter ~= "" then
      return delimiter
    end
  end

  return nil
end

-- Check if line ends a HEREDOC
local function is_heredoc_end(trimmed, delimiter)
  return delimiter ~= nil and trimmed == delimiter
end

-- Check if line is a ShellSpec block keyword
local function is_block_keyword(trimmed)
  for _, pattern in ipairs(BLOCK_PATTERNS) do
    if string.match(trimmed, pattern) then
      debug('Matched block keyword: "' .. trimmed .. '"')
      return true
    end
  end
  return false
end

-- Check if line is an End keyword
local function is_end_keyword(trimmed)
  return string.match(trimmed, "^End%s*$") ~= nil
end

-- Check if line is a comment
local function is_comment(trimmed)
  return string.match(trimmed, "^#") ~= nil
end

-- Generate indentation string
local function make_indent(level)
  if config.get("use_spaces") then
    return string.rep(" ", level * config.get("indent_size"))
  end
  return string.rep("\t", level)
end

--- Reformat `lines`, returning a new list.
---
--- `start_indent` seeds the indent level, defaulting to 0. Callers formatting a
--- sub-range must pass the level the range sits at; without it a nested
--- selection is re-indented as though it were a whole file and flattened to
--- column 0 while the lines around it keep their original indent.
function M.format_lines(lines, start_indent)
  local result = {}
  local indent_level = start_indent or 0
  local state = State.NORMAL
  local heredoc_delimiter = nil
  local indent_comments = config.get("indent_comments")

  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)

    if trimmed == "" then
      table.insert(result, line)
    elseif state == State.IN_HEREDOC then
      -- The terminator is emitted verbatim, like the body: a non-`<<-` HEREDOC
      -- requires its delimiter at column 0, so indenting it leaves the shell
      -- unable to close the HEREDOC and the rest of the file becomes body.
      if is_heredoc_end(trimmed, heredoc_delimiter) then
        state = State.NORMAL
        heredoc_delimiter = nil
        debug("HEREDOC end detected")
      end
      table.insert(result, line)
    elseif is_comment(trimmed) then
      -- Checked before HEREDOCs so a comment that merely mentions `<<EOF`
      -- does not put the formatter into a HEREDOC state.
      if indent_comments then
        table.insert(result, make_indent(indent_level) .. trimmed)
      else
        table.insert(result, line)
      end
    elseif is_end_keyword(trimmed) then
      indent_level = math.max(0, indent_level - 1)
      table.insert(result, make_indent(indent_level) .. trimmed)
    else
      table.insert(result, make_indent(indent_level) .. trimmed)

      -- Checked before the HEREDOC start so a line that is both -- `It "x" <<EOF`
      -- -- still opens its block.
      if is_block_keyword(trimmed) then
        indent_level = indent_level + 1
        debug('Block keyword: "' .. trimmed .. '", new indent: ' .. indent_level)
      end

      local delimiter = detect_heredoc_start(trimmed)
      if delimiter then
        state = State.IN_HEREDOC
        heredoc_delimiter = delimiter
        debug("HEREDOC start detected: '" .. delimiter .. "'")
      end
    end
  end

  return result
end

--- Indent level a line sits at, derived from its existing leading whitespace.
local function indent_level_of(line)
  local leading = line:match("^%s*") or ""
  if config.get("use_spaces") then
    return math.floor(#leading / config.get("indent_size"))
  end
  return #(leading:gsub("[^\t]", ""))
end

--- Window currently displaying `bufnr`, or nil.
---
--- Cursor save/restore must target the window showing the buffer being
--- formatted, not window 0: `format_buffer` is reachable from a `BufWritePre`
--- autocmd and from `:bufdo`, where the current window shows something else.
local function window_for(bufnr)
  if bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end
  local win = vim.fn.bufwinid(bufnr)
  return win ~= -1 and win or nil
end

-- Format entire buffer
function M.format_buffer(bufnr)
  bufnr = bufnr or 0

  local ok, err = pcall(function()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local formatted = M.format_lines(lines)

    local win = window_for(bufnr)
    local cursor_pos = win and vim.api.nvim_win_get_cursor(win) or nil

    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)

    -- Clamped rather than pcall'd: formatting can shorten the buffer past the
    -- saved row, which is a foreseeable outcome, not an error to swallow.
    if win and cursor_pos then
      cursor_pos[1] = math.min(cursor_pos[1], vim.api.nvim_buf_line_count(bufnr))
      vim.api.nvim_win_set_cursor(win, cursor_pos)
    end

    debug("Formatted " .. #lines .. " lines")
  end)

  if not ok then
    vim.notify("ShellSpec: Format buffer failed - " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- Format buffer lines [start_line, end_line], 1-indexed against `bufnr`.
---
--- The indent level is taken from the first line's existing indentation, so a
--- selection whose opening keyword lies outside the range keeps its place in the
--- block structure instead of being flattened to column 0.
---
--- An `End` first line sits at its opener's level, but format_lines decrements
--- before emitting `End`, so the seed is one deeper for it. Seeding with the
--- line's own level shifted every following line one level left, which made
--- `gq` or a range starting at an `End` corrupt already-formatted code.
function M.format_selection(bufnr, start_line, end_line)
  bufnr = bufnr or 0

  local ok, err = pcall(function()
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
    if #lines == 0 then
      return
    end
    local seed = indent_level_of(lines[1])
    if is_end_keyword(vim.trim(lines[1])) then
      seed = seed + 1
    end
    local formatted = M.format_lines(lines, seed)
    vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, formatted)
  end)

  if not ok then
    vim.notify("ShellSpec: Format selection failed - " .. tostring(err), vim.log.levels.ERROR)
  end
end

--- 'formatexpr' entry point, for `gq`.
---
--- Formats the range Vim asks about (`v:lnum` for `v:count` lines) rather than
--- the whole buffer, and returns 0 to report the range as handled. Pointing
--- 'formatexpr' straight at `format_buffer` made every `gq` motion rewrite the
--- entire file.
function M.formatexpr()
  M.format_selection(0, vim.v.lnum, vim.v.lnum + vim.v.count - 1)
  return 0
end

--- Format the buffer on the next event-loop tick.
---
--- Defers the work so a large buffer does not block the keystroke that started
--- it; the formatting itself is still synchronous once it runs.
---
--- Buffer 0 is resolved to a real handle now, not inside the callback: 0 means
--- "current buffer" at the moment it is read, so a buffer switch before the
--- next tick used to reformat whatever buffer had become current instead.
function M.format_buffer_async(bufnr, callback)
  if bufnr == nil or bufnr == 0 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  vim.schedule(function()
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    M.format_buffer(bufnr)
    if callback then
      callback()
    end
  end)
end

return M
