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
  for _, pattern in ipairs(get_heredoc_patterns()) do
    local match = string.match(trimmed, pattern)
    if match then
      -- Extract the delimiter
      local delimiter = string.match(match, "<<-?['\"]?([A-Z_][A-Z0-9_]*)['\"]?")
      return delimiter
    end
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

  -- Standard block keywords
  if string.match(trimmed, "^(Describe|Context|ExampleGroup|It|Specify|Example)") then
    return true
  end

  -- Prefixed block keywords (x for skip, f for focus)
  if string.match(trimmed, "^[xf](Describe|Context|ExampleGroup|It|Specify|Example)") then
    return true
  end

  -- Data and Parameters blocks
  if string.match(trimmed, "^(Data|Parameters)%s*$") then
    return true
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

      -- Handle comments with proper indentation
      if is_comment(line) and indent_comments then
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

      -- Apply normal indentation for other lines
      if not is_comment(line) or not indent_comments then
        local formatted_line = make_indent(indent_level) .. trimmed
        table.insert(result, formatted_line)

        -- Increase indent after block keywords
        if is_block_keyword(line) then
          indent_level = indent_level + 1
        end
      else
        -- Preserve original comment formatting if indent_comments is false
        table.insert(result, line)
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
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local formatted = M.format_lines(lines)

  -- Store cursor position
  local cursor_pos = vim.api.nvim_win_get_cursor(0)

  -- Replace buffer content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, formatted)

  -- Restore cursor position
  pcall(vim.api.nvim_win_set_cursor, 0, cursor_pos)
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
