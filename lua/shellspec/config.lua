-- ShellSpec configuration management
local M = {}

-- Default configuration
M.defaults = {
  -- Auto-format on save
  auto_format = false,

  -- Indentation settings
  indent_size = 2,
  use_spaces = true,

  -- HEREDOC handling
  heredoc_patterns = {
    "<<[A-Z_][A-Z0-9_]*", -- <<EOF, <<DATA, etc.
    "<<'[^']*'", -- <<'EOF'
    '<<"[^"]*"', -- <<"EOF"
    "<<-[A-Z_][A-Z0-9_]*", -- <<-EOF (with leading tab removal)
  },

  -- Comment indentation
  indent_comments = true,

  -- Formatting options
  preserve_empty_lines = true,
  max_line_length = 160,
}

-- Current configuration
M.config = {}

-- Setup function
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})

  -- Validate configuration
  if type(M.config.indent_size) ~= "number" or M.config.indent_size < 1 then
    vim.notify("shellspec: indent_size must be a positive number", vim.log.levels.WARN)
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
