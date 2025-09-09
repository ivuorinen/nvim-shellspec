-- Health check for shellspec.nvim
local M = {}

function M.check()
  local health = vim.health or require("health")

  health.report_start("ShellSpec.nvim")

  -- Check Neovim version
  local nvim_version = vim.version()
  if nvim_version.major > 0 or nvim_version.minor >= 7 then
    health.report_ok(string.format("Neovim version %d.%d.%d >= 0.7.0", nvim_version.major, nvim_version.minor, nvim_version.patch))
  else
    health.report_warn(string.format("Neovim version %d.%d.%d < 0.7.0, some features may not work", nvim_version.major, nvim_version.minor, nvim_version.patch))
  end

  -- Check if module can be loaded
  local ok, config = pcall(require, "shellspec.config")
  if ok then
    health.report_ok("ShellSpec configuration module loaded successfully")

    -- Report current configuration
    local current_config = config.config
    if current_config then
      health.report_info("Configuration:")
      health.report_info("  Auto-format: " .. tostring(current_config.auto_format))
      health.report_info("  Indent size: " .. tostring(current_config.indent_size))
      health.report_info("  Use spaces: " .. tostring(current_config.use_spaces))
      health.report_info("  Indent comments: " .. tostring(current_config.indent_comments))
    end
  else
    health.report_error("Failed to load ShellSpec configuration: " .. config)
    return
  end

  -- Check formatting module
  local ok_format, format = pcall(require, "shellspec.format")
  if ok_format then
    health.report_ok("ShellSpec formatting module loaded successfully")
  else
    health.report_error("Failed to load ShellSpec formatting module: " .. format)
  end

  -- Check autocommands module
  local ok_autocmds, autocmds = pcall(require, "shellspec.autocmds")
  if ok_autocmds then
    health.report_ok("ShellSpec autocommands module loaded successfully")
  else
    health.report_error("Failed to load ShellSpec autocommands module: " .. autocmds)
  end

  -- Check if we're in a ShellSpec buffer
  local filetype = vim.bo.filetype
  if filetype == "shellspec" then
    health.report_ok("Current buffer is ShellSpec filetype")

    -- Check buffer-local settings
    local shiftwidth = vim.bo.shiftwidth
    local expandtab = vim.bo.expandtab
    local commentstring = vim.bo.commentstring

    health.report_info("Buffer settings:")
    health.report_info("  shiftwidth: " .. tostring(shiftwidth))
    health.report_info("  expandtab: " .. tostring(expandtab))
    health.report_info("  commentstring: " .. tostring(commentstring))
  else
    health.report_info("Current buffer filetype: " .. (filetype or "none"))
    health.report_info("Open a ShellSpec file (*.spec.sh) to test buffer-specific features")
  end

  -- Check for common ShellSpec files in project
  local cwd = vim.fn.getcwd()
  local spec_dirs = { "spec", "test" }
  local found_specs = false

  for _, dir in ipairs(spec_dirs) do
    local spec_dir = cwd .. "/" .. dir
    if vim.fn.isdirectory(spec_dir) == 1 then
      local files = vim.fn.glob(spec_dir .. "/*.sh", false, true)
      if #files > 0 then
        found_specs = true
        health.report_ok("Found " .. #files .. " ShellSpec files in " .. dir .. "/")
        break
      end
    end
  end

  if not found_specs then
    local spec_files = vim.fn.glob("**/*_spec.sh", false, true)
    local spec_files2 = vim.fn.glob("**/*.spec.sh", false, true)
    local total_specs = #spec_files + #spec_files2

    if total_specs > 0 then
      health.report_ok("Found " .. total_specs .. " ShellSpec files in project")
    else
      health.report_info("No ShellSpec files found in current directory")
      health.report_info("ShellSpec files typically match: *_spec.sh, *.spec.sh, spec/*.sh")
    end
  end

  -- Check commands availability
  local commands = { "ShellSpecFormat", "ShellSpecFormatRange" }
  for _, cmd in ipairs(commands) do
    if vim.fn.exists(":" .. cmd) == 2 then
      health.report_ok("Command :" .. cmd .. " is available")
    else
      health.report_error("Command :" .. cmd .. " is not available")
    end
  end
end

return M
