-- Health check for shellspec.nvim
local M = {}

--- :checkhealth shellspec
---
--- Uses vim.health.start/ok/info/warn/error. The report_* spelling this once
--- used was deprecated in Neovim 0.10 and has since been removed, so calling it
--- replaced the health report with a "attempt to call a nil value" traceback.
--- The start/ok names only exist from 0.10, which is why plugin/shellspec.vim
--- gates the Lua path on it.
function M.check()
  local health = vim.health

  health.start("ShellSpec.nvim")

  local nvim_version = vim.version()
  local version_string = string.format("%d.%d.%d", nvim_version.major, nvim_version.minor, nvim_version.patch)
  if nvim_version.major > 0 or nvim_version.minor >= 10 then
    health.ok("Neovim version " .. version_string .. " >= 0.10.0")
  else
    health.warn("Neovim version " .. version_string .. " < 0.10.0, the VimScript fallback is in use")
  end

  -- tostring on every pcall error: a module may raise a table, and
  -- concatenating one would fail inside the check whose job is reporting that
  -- failure legibly.
  local ok, config = pcall(require, "shellspec.config")
  if ok then
    health.ok("ShellSpec configuration module loaded successfully")

    local current_config = config.config
    if current_config then
      health.info("Configuration:")
      health.info("  Auto-format: " .. tostring(current_config.auto_format))
      health.info("  Indent size: " .. tostring(current_config.indent_size))
      health.info("  Use spaces: " .. tostring(current_config.use_spaces))
      health.info("  Indent comments: " .. tostring(current_config.indent_comments))
    end
  else
    health.error("Failed to load ShellSpec configuration: " .. tostring(config))
    return
  end

  local ok_format, format = pcall(require, "shellspec.format")
  if ok_format then
    health.ok("ShellSpec formatting module loaded successfully")
  else
    health.error("Failed to load ShellSpec formatting module: " .. tostring(format))
  end

  local ok_autocmds, autocmds = pcall(require, "shellspec.autocmds")
  if ok_autocmds then
    health.ok("ShellSpec autocommands module loaded successfully")
  else
    health.error("Failed to load ShellSpec autocommands module: " .. tostring(autocmds))
  end

  -- The alternate buffer, not `vim.bo`: :checkhealth opens its report buffer
  -- before running checks, so the current buffer is the report itself and the
  -- user's spec is the one they came from.
  local buf = vim.fn.bufnr("#")
  local filetype = buf > 0 and vim.bo[buf].filetype or ""
  if filetype == "shellspec" then
    health.ok("Buffer " .. vim.fn.bufname(buf) .. " is ShellSpec filetype")
    health.info("Buffer settings:")
    health.info("  shiftwidth: " .. tostring(vim.bo[buf].shiftwidth))
    health.info("  expandtab: " .. tostring(vim.bo[buf].expandtab))
    health.info("  commentstring: " .. tostring(vim.bo[buf].commentstring))
  else
    health.info("Previous buffer filetype: " .. (filetype ~= "" and filetype or "none"))
    health.info("Run :checkhealth from a ShellSpec file (*_spec.sh, *.spec.sh, spec/*.sh) to see its settings")
  end

  -- No project-wide spec count: a recursive glob of the cwd walked the whole
  -- tree synchronously and froze :checkhealth for minutes when Neovim was
  -- started from $HOME, for a number that diagnosed nothing.

  for _, cmd in ipairs({ "ShellSpecFormat", "ShellSpecFormatRange" }) do
    if vim.fn.exists(":" .. cmd) == 2 then
      health.ok("Command :" .. cmd .. " is available")
    else
      health.error("Command :" .. cmd .. " is not available")
    end
  end
end

return M
