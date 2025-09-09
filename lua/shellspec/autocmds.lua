-- Neovim-native autocommands for ShellSpec
local config = require("shellspec.config")
local format = require("shellspec.format")
local M = {}

-- Autocommand group
local augroup = vim.api.nvim_create_augroup("ShellSpec", { clear = true })

-- Setup buffer-local settings
local function setup_buffer(bufnr)
  -- Set buffer options
  vim.api.nvim_set_option_value("commentstring", "# %s", { buf = bufnr })
  vim.api.nvim_set_option_value("shiftwidth", config.get("indent_size"), { buf = bufnr })
  vim.api.nvim_set_option_value("tabstop", config.get("indent_size"), { buf = bufnr })
  vim.api.nvim_set_option_value("expandtab", config.get("use_spaces"), { buf = bufnr })

  -- Set window-local options (foldmethod is window-local)
  vim.api.nvim_set_option_value("foldmethod", "indent", { win = 0 })

  -- Buffer-local commands
  vim.api.nvim_buf_create_user_command(bufnr, "ShellSpecFormat", function()
    format.format_buffer(bufnr)
  end, { desc = "Format ShellSpec buffer" })

  vim.api.nvim_buf_create_user_command(bufnr, "ShellSpecFormatRange", function(opts)
    format.format_selection(bufnr, opts.line1, opts.line2)
  end, {
    range = true,
    desc = "Format ShellSpec selection",
  })

  -- Optional: Set up LSP-style formatting
  if vim.fn.has("nvim-0.8") == 1 then
    vim.api.nvim_buf_set_option(bufnr, "formatexpr", 'v:lua.require("shellspec.format").format_buffer()')
  end
end

-- Create all autocommands
function M.setup()
  -- Create global commands first
  vim.api.nvim_create_user_command("ShellSpecFormat", function()
    format.format_buffer()
  end, { desc = "Format current ShellSpec buffer" })

  vim.api.nvim_create_user_command("ShellSpecFormatRange", function(cmd_opts)
    format.format_selection(0, cmd_opts.line1, cmd_opts.line2)
  end, {
    range = true,
    desc = "Format ShellSpec selection",
  })

  -- FileType detection and setup
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
        -- Only format if it's a shellspec buffer
        local filetype = vim.api.nvim_get_option_value("filetype", { buf = args.buf })
        if filetype == "shellspec" then
          format.format_buffer(args.buf)
        end
      end,
      desc = "Auto-format ShellSpec files on save",
    })
  end

  -- Enhanced filetype detection with better patterns
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = augroup,
    pattern = {
      "*_spec.sh",
      "*.spec.sh",
      "spec/*.sh",
      "test/*.sh",
    },
    callback = function(args)
      -- Set filetype to shellspec
      vim.api.nvim_set_option_value("filetype", "shellspec", { buf = args.buf })
    end,
    desc = "Detect ShellSpec files",
  })

  -- Additional pattern for nested spec directories
  vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
    group = augroup,
    pattern = "**/spec/**/*.sh",
    callback = function(args)
      vim.api.nvim_set_option_value("filetype", "shellspec", { buf = args.buf })
    end,
    desc = "Detect ShellSpec files in nested spec directories",
  })
end

-- Cleanup function
function M.cleanup()
  vim.api.nvim_clear_autocmds({ group = augroup })
end

-- Update configuration and refresh autocommands
function M.refresh()
  M.cleanup()
  M.setup()
end

return M
