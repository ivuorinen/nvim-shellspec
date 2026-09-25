-- Neovim-native autocommands for ShellSpec
local config = require("shellspec.config")
local format = require("shellspec.format")
local M = {}

--- Autocommand group, recreated by each M.setup() call.
---
--- Created inside setup() rather than at module load so a second setup() clears
--- the first's registrations. With the group created once at load, plugin/
--- calling setup() and the user's own setup() each appended a full set, leaving
--- every detection autocmd registered twice and setup_buffer running twice per
--- FileType event.
local augroup = nil

-- Setup buffer-local settings
local function setup_buffer(bufnr)
  vim.api.nvim_set_option_value("commentstring", "# %s", { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", config.get("indent_size"), { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", config.get("indent_size"), { buf = bufnr })
  vim.api.nvim_set_option_value("expandtab", config.get("use_spaces"), { buf = bufnr })

  -- 'foldmethod' is deliberately left alone. Forcing indent folds overrode the
  -- user's own folding and, with the default 'foldlevel' 0, opened every spec
  -- fully folded -- and closed folds widen any :{range} to whole folds.

  -- bar = true on every command so `:ShellSpecFormat | w` chains instead of
  -- failing with E488.
  vim.api.nvim_buf_create_user_command(bufnr, "ShellSpecFormat", function()
    format.format_buffer(bufnr)
  end, { bar = true, desc = "Format ShellSpec buffer" })

  vim.api.nvim_buf_create_user_command(bufnr, "ShellSpecFormatRange", function(opts)
    format.format_selection(bufnr, opts.line1, opts.line2)
  end, {
    bar = true,
    range = true,
    desc = "Format ShellSpec selection",
  })

  -- Range-aware: 'formatexpr' is called for the range gq was given, so it must
  -- not reformat the whole buffer.
  vim.api.nvim_set_option_value("formatexpr", "v:lua.require'shellspec.format'.formatexpr()", { buf = bufnr })
end

-- Create all autocommands and commands
function M.setup()
  augroup = vim.api.nvim_create_augroup("ShellSpec", { clear = true })

  vim.api.nvim_create_user_command("ShellSpecFormat", function()
    format.format_buffer()
  end, { bar = true, desc = "Format current ShellSpec buffer" })

  vim.api.nvim_create_user_command("ShellSpecFormatRange", function(cmd_opts)
    format.format_selection(0, cmd_opts.line1, cmd_opts.line2)
  end, {
    bar = true,
    range = true,
    desc = "Format ShellSpec selection",
  })

  vim.api.nvim_create_user_command("ShellSpecFormatAsync", function()
    format.format_buffer_async()
  end, { bar = true, desc = "Format current ShellSpec buffer on the next event-loop tick" })

  vim.api.nvim_create_autocmd("FileType", {
    group = augroup,
    pattern = "shellspec",
    callback = function(args)
      setup_buffer(args.buf)
    end,
    desc = "Setup ShellSpec buffer",
  })

  -- Auto-format on save (if enabled)
  if config.get("auto_format") then
    vim.api.nvim_create_autocmd("BufWritePre", {
      group = augroup,
      pattern = { "*.spec.sh", "*_spec.sh" },
      callback = function(args)
        local filetype = vim.api.nvim_get_option_value("filetype", { buf = args.buf })
        if filetype == "shellspec" then
          format.format_buffer(args.buf)
        end
      end,
      desc = "Auto-format ShellSpec files on save",
    })
  end

  -- Filetype detection lives only in ftdetect/shellspec.vim, which Neovim and
  -- Vim both source. A second copy here drifted from it in semantics (forced
  -- `filetype=` vs `setfiletype`) and had to be edited in lockstep.
end

-- Cleanup function
function M.cleanup()
  if augroup then
    vim.api.nvim_clear_autocmds({ group = augroup })
  end
end

--- Re-register everything against the current configuration.
--- setup() recreates the group with clear = true, so this needs no cleanup pass.
function M.refresh()
  M.setup()
end

return M
