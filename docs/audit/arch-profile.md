# Architecture Profile

Generated: 2026-09-24

## Detected Patterns

### Plugin / Extension — Medium confidence

Evidence:

- The repository is itself an extension of a host (Vim/Neovim) and is laid out on the host's
  runtimepath extension points: `plugin/`, `ftdetect/`, `syntax/`, `indent/`, `autoload/`,
  `lua/shellspec/`, `doc/`.
- `plugin/shellspec.vim` is the single load-time entry; it selects the Lua implementation
  (`has('nvim-0.10')`) or registers the VimScript fallback.
- `lua/shellspec/init.lua` is the public Lua facade (`setup`, `format_*`, `config`), delegating to
  `config`, `format`, `autocmds`, `health` modules; no module imports `init`.

### Pipe and Filter — Low confidence

Evidence:

- `format.format_lines(lines, start_indent)` is a line-stream transform with a two-state machine;
  every editor entry point (`format_buffer`, `format_selection`, `formatexpr`) reads lines, calls
  it, and writes the result back.
- Its only dependency is `shellspec.config` (read-only `get`), so it is not strictly a pure filter.

## Detected Combination

Custom hybrid: host Plugin/Extension with a replicated formatting core — one algorithm implemented
three times (`lua/shellspec/format.lua`, `autoload/shellspec.vim`, `bin/shellspec-format`), plus a
fourth, partial copy of the block grammar in `autoload/shellspec/indent.vim`.

## Inferred Structural Rules

- The formatting core (`format_lines` and its fallback/CLI twins) must not touch buffers, windows
  or options; editor entry points own all buffer I/O.
- The three formatter implementations must produce byte-identical output
  (`tests/parity_test.sh` enforces this); any grammar change lands in all three and in
  `indent.vim`'s block pattern.
- Host extension points stay single-sourced: one filetype-detection definition, one indent
  definition, one syntax definition.
- The public Lua surface is `require("shellspec")` plus modules shipped in tagged releases;
  removing anything exported at v2.0.2 is a breaking change.

## Ambiguities & Contradictions

- At profiling time filetype detection was defined twice — `ftdetect/shellspec.vim`
  (`setfiletype`) and `lua/shellspec/autocmds.lua` (forced `filetype=`) — contradicting
  single-sourcing (audit-28dc4f07). Resolved in the same run: ftdetect is now the only source.
- The grammar is replicated four ways by design; parity is enforced only for the three
  formatters, not for `indent.vim` (covered instead by an integration `gg=G` check).
