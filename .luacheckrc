-- Luacheck configuration for nvim-shellspec
--
-- Run via `make lint-lua`, the pre-commit `luacheck` hook, or directly with
-- `mise exec -- luacheck lua/ tests/`.

-- Neovim embeds LuaJIT, so LuaJIT's standard library is what is actually
-- available at runtime -- not Lua 5.4's.
std = "luajit"

-- `vim` is injected by the host editor and never assigned by this plugin, so it
-- is read-only. Declaring it read_globals means an accidental `vim = ...` is
-- still reported rather than silently accepted.
read_globals = { "vim" }

-- Matches max_line_length in .editorconfig; luacheck's own default is 120,
-- which would flag lines the repo's other tooling accepts.
max_line_length = 160

exclude_files = {
  -- Vendored or generated trees, should any appear.
  ".git",
}
