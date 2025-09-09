-- Enhanced ShellSpec DSL formatter with HEREDOC support
local config = require("shellspec.config")
local M = {}

-- Formatting state
local State = {
  NORMAL = 1,
  IN_HEREDOC = 2,
  IN_DATA_BLOCK = 3,
}

-- HEREDOC detection patterns
local function get_heredoc_patterns()
  return config.get("heredoc_patterns")
end

-- Check if line starts a HEREDOC
local function detect_heredoc_start(line)
  local trimmed = vim.trim(line)

  -- Check each pattern and extract delimiter directly
  if string.match(trimmed, "<<[A-Z_][A-Z0-9_]*") then
    return string.match(trimmed, "<<([A-Z_][A-Z0-9_]*)")
  elseif string.match(trimmed, "<<'[^']*'") then
    return string.match(trimmed, "<<'([^']*)'")
  elseif string.match(trimmed, '<<"[^"]*"') then
    return string.match(trimmed, '<<"([^"]*)"')
  elseif string.match(trimmed, "<<-[A-Z_][A-Z0-9_]*") then
    return string.match(trimmed, "<<-([A-Z_][A-Z0-9_]*)")
  end

  return nil
end

-- Check if line ends a HEREDOC
local function is_heredoc_end(line, delimiter)
  if not delimiter then
    return false
  end
  local trimmed = vim.trim(line)
  return trimmed == delimiter
end

-- Check if line is a ShellSpec block keyword
local function is_block_keyword(line)
  local trimmed = vim.trim(line)

  -- Debug logging
  if vim.g.shellspec_debug then
    vim.notify('ShellSpec: Checking if block keyword: "' .. trimmed .. '"', vim.log.levels.DEBUG)
  end

  -- Standard block keywords - check each one individually
  if
    string.match(trimmed, "^Describe%s")
    or string.match(trimmed, "^Context%s")
    or string.match(trimmed, "^ExampleGroup%s")
    or string.match(trimmed, "^It%s")
    or string.match(trimmed, "^Specify%s")
    or string.match(trimmed, "^Example%s")
  then
    if vim.g.shellspec_debug then
      vim.notify('ShellSpec: Matched standard block keyword: "' .. trimmed .. '"', vim.log.levels.DEBUG)
    end
    return true
  end

  -- Prefixed block keywords (x for skip, f for focus)
  if
    string.match(trimmed, "^[xf]Describe%s")
    or string.match(trimmed, "^[xf]Context%s")
    or string.match(trimmed, "^[xf]ExampleGroup%s")
    or string.match(trimmed, "^[xf]It%s")
    or string.match(trimmed, "^[xf]Specify%s")
    or string.match(trimmed, "^[xf]Example%s")
  then
    if vim.g.shellspec_debug then
      vim.notify('ShellSpec: Matched prefixed block keyword: "' .. trimmed .. '"', vim.log.levels.DEBUG)
    end
    return true
  end

  -- Data and Parameters blocks
  if string.match(trimmed, "^Data%s*$") or string.match(trimmed, "^Parameters%s*$") then
    if vim.g.shellspec_debug then
      vim.notify('ShellSpec: Matched data/parameters block: "' .. trimmed .. '"', vim.log.levels.DEBUG)
    end
    return true
  end

  -- Hook keywords that create blocks (can be standalone)
  if
    string.match(trimmed, "^BeforeEach%s*$")
    or string.match(trimmed, "^AfterEach%s*$")
    or string.match(trimmed, "^BeforeAll%s*$")
    or string.match(trimmed, "^AfterAll%s*$")
    or string.match(trimmed, "^Before%s*$")
    or string.match(trimmed, "^After%s*$")
  then
    if vim.g.shellspec_debug then
      vim.notify('ShellSpec: Matched hook keyword: "' .. trimmed .. '"', vim.log.levels.DEBUG)
    end
    return true
  end

  -- Additional hook keywords (can be standalone)
  if
    string.match(trimmed, "^BeforeCall%s*$")
    or string.match(trimmed, "^AfterCall%s*$")
    or string.match(trimmed, "^BeforeRun%s*$")
    or string.match(trimmed, "^AfterRun%s*$")
  then
    if vim.g.shellspec_debug then
      vim.notify('ShellSpec: Matched additional hook keyword: "' .. trimmed .. '"', vim.log.levels.DEBUG)
    end
    return true
  end

  if vim.g.shellspec_debug then
    vim.notify('ShellSpec: Not a block keyword: "' .. trimmed .. '"', vim.log.levels.DEBUG)
  end

  return false
end

-- Check if line is an End keyword
local function is_end_keyword(line)
  local trimmed = vim.trim(line)
  return string.match(trimmed, "^End%s*$") ~= nil
end

-- Check if line is a comment
local function is_comment(line)
  local trimmed = vim.trim(line)
  return string.match(trimmed, "^#") ~= nil
end

-- Generate indentation string
local function make_indent(level)
  local indent_size = config.get("indent_size")
  local use_spaces = config.get("use_spaces")

  if use_spaces then
    return string.rep(" ", level * indent_size)
  else
    return string.rep("\t", level)
  end
end

-- Main formatting function
function M.format_lines(lines)
  local result = {}
  local indent_level = 0
  local state = State.NORMAL
  local heredoc_delimiter = nil
  local indent_comments = config.get("indent_comments")

  for _, line in ipairs(lines) do
    local trimmed = vim.trim(line)

    -- Handle empty lines
    if trimmed == "" then
      table.insert(result, line)
      goto continue
    end

    -- State machine for HEREDOC handling
    if state == State.NORMAL then
      -- Check for HEREDOC start
      local delimiter = detect_heredoc_start(line)
      if delimiter then
        state = State.IN_HEREDOC
        heredoc_delimiter = delimiter
        -- Apply current indentation to HEREDOC start line
        local formatted_line = make_indent(indent_level) .. trimmed
        table.insert(result, formatted_line)
        goto continue
      end

      -- Handle End keyword (decrease indent first)
      if is_end_keyword(line) then
        indent_level = math.max(0, indent_level - 1)
        local formatted_line = make_indent(indent_level) .. trimmed
        table.insert(result, formatted_line)
        goto continue
      end

      -- Handle comments
      if is_comment(line) then
        if indent_comments then
          local formatted_line = make_indent(indent_level) .. trimmed
          table.insert(result, formatted_line)
        else
          -- Preserve original comment formatting
          table.insert(result, line)
        end
        goto continue
      end

      -- Handle non-comment lines (ShellSpec commands, etc.)
      local formatted_line = make_indent(indent_level) .. trimmed
      table.insert(result, formatted_line)

      -- Increase indent after block keywords
      if is_block_keyword(line) then
        indent_level = indent_level + 1

        -- Debug logging
        if vim.g.shellspec_debug then
          vim.notify('ShellSpec: Block keyword detected: "' .. trimmed .. '", new indent: ' .. indent_level, vim.log.levels.DEBUG)
        end
      end
    elseif state == State.IN_HEREDOC then
      -- Check for HEREDOC end
      if is_heredoc_end(line, heredoc_delimiter) then
        state = State.NORMAL
        heredoc_delimiter = nil
        -- Apply current indentation to HEREDOC end line
        local formatted_line = make_indent(indent_level) .. trimmed
        table.insert(result, formatted_line)
      else
        -- Preserve original indentation within HEREDOC
        table.insert(result, line)
      end
    end

    ::continue::
  end

  return result
end

-- Format entire buffer
function M.format_buffer(bufnr)
  bufnr = bufnr or 0

  local ok, err = pcall(function()
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local formatted = M.format_lines(lines)

    -- Store cursor position
    local cursor_pos = vim.api.nvim_win_get_cursor(0)

    -- Replace buffer content
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)

    -- Restore cursor position
    pcall(vim.api.nvim_win_set_cursor, 0, cursor_pos)

    if vim.g.shellspec_debug then
      vim.notify("ShellSpec: Formatted " .. #lines .. " lines", vim.log.levels.INFO)
    end
  end)

  if not ok then
    vim.notify("ShellSpec: Format buffer failed - " .. tostring(err), vim.log.levels.ERROR)
  end
end

-- Format selection
function M.format_selection(bufnr, start_line, end_line)
  bufnr = bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)
  local formatted = M.format_lines(lines)

  -- Replace selection
  vim.api.nvim_buf_set_lines(bufnr, start_line - 1, end_line, false, formatted)
end

-- Async format function for performance
function M.format_buffer_async(bufnr, callback)
  bufnr = bufnr or 0

  -- Use vim.schedule to avoid blocking
  vim.schedule(function()
    M.format_buffer(bufnr)
    if callback then
      callback()
    end
  end)
end

return M
