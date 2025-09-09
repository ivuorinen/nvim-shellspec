-- Main ShellSpec module for Neovim
local M = {}

-- Lazy-load submodules
local config = require("shellspec.config")
local format = require("shellspec.format")
local autocmds = require("shellspec.autocmds")

-- Version info
M._VERSION = "2.0.1"

-- Setup function for Lua configuration
function M.setup(opts)
  opts = opts or {}

  -- Setup configuration
  config.setup(opts)

  -- Setup autocommands
  autocmds.setup()

  -- Create global commands for compatibility
  vim.api.nvim_create_user_command("ShellSpecFormat", function()
    format.format_buffer()
  end, { desc = "Format current ShellSpec buffer" })

  vim.api.nvim_create_user_command("ShellSpecFormatRange", function(cmd_opts)
    format.format_selection(0, cmd_opts.line1, cmd_opts.line2)
  end, {
    range = true,
    desc = "Format ShellSpec selection",
  })

  -- Optional: Enable auto-format if configured
  if config.get("auto_format") then
    autocmds.refresh() -- Refresh to pick up auto-format settings
  end
end

-- Format functions (for external use)
M.format_buffer = format.format_buffer
M.format_selection = format.format_selection
M.format_lines = format.format_lines

-- Configuration access
M.config = config

-- Health check function for :checkhealth
function M.health()
  local health = vim.health or require("health")

  health.report_start("ShellSpec.nvim")

  -- Check Neovim version
  if vim.fn.has("nvim-0.7") == 1 then
    health.report_ok("Neovim version >= 0.7.0")
  else
    health.report_warn("Neovim version < 0.7.0, some features may not work")
  end

  -- Check configuration
  local current_config = config.config
  if current_config then
    health.report_ok("Configuration loaded successfully")
    health.report_info("Auto-format: " .. tostring(current_config.auto_format))
    health.report_info("Indent size: " .. tostring(current_config.indent_size))
    health.report_info("Use spaces: " .. tostring(current_config.use_spaces))
  else
    health.report_error("Configuration not loaded")
  end

  -- Check if in ShellSpec buffer
  local filetype = vim.bo.filetype
  if filetype == "shellspec" then
    health.report_ok("Current buffer is ShellSpec filetype")
  else
    health.report_info("Current buffer filetype: " .. (filetype or "none"))
  end
end

-- Backward compatibility function for VimScript
function M.format_buffer_compat()
  format.format_buffer()
end

function M.format_selection_compat(start_line, end_line)
  format.format_selection(0, start_line, end_line)
end

return M
