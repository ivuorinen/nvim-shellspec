-- Main ShellSpec module for Neovim
local M = {}

local config = require("shellspec.config")
local format = require("shellspec.format")
local autocmds = require("shellspec.autocmds")

-- Version info
M._VERSION = "2.0.2"

--- Apply `opts` and register commands and autocommands.
---
--- Safe to call after plugin/shellspec.vim has already run: autocmds.setup()
--- recreates its augroup with clear = true, so a second call replaces the first
--- set rather than adding to it.
function M.setup(opts)
  config.setup(opts or {})

  -- Registers both user commands and reads auto_format itself; nothing else
  -- here needs to repeat either.
  autocmds.setup()
end

-- Format functions (for external use)
M.format_buffer = format.format_buffer
M.format_selection = format.format_selection
M.format_lines = format.format_lines

-- Configuration access
M.config = config

--- Deprecated aliases, kept for backward compatibility.
---
--- These are exported from a tagged release (v2.0.2), so they may be called
--- from a user's config even though nothing in this repository calls them.
--- Removing them would be a breaking change to the public Lua surface and needs
--- a major version bump, not a cleanup commit.
---
--- `M.health` previously duplicated `shellspec.health.check` and called the
--- removed `vim.health.report_*` API; it now delegates to the working
--- implementation that `:checkhealth shellspec` uses.

function M.health()
  require("shellspec.health").check()
end

function M.format_buffer_compat()
  format.format_buffer()
end

function M.format_selection_compat(start_line, end_line)
  format.format_selection(0, start_line, end_line)
end

return M
