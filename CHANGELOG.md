# Changelog

## Unreleased

Release this as a **major** version: the Breaking entries below change documented behaviour
(`make release-major`).

### Breaking

- Filetype detection no longer claims every `test/*.sh` script. Specs under `test/` named `*_spec.sh`
  or `*.spec.sh` are still detected; restore the old rule with
  `autocmd BufRead,BufNewFile test/*.sh set filetype=shellspec`.
- The Lua implementation now requires Neovim 0.10. Neovim 0.7–0.9 use the VimScript fallback (the
  Lua path errored there on every shellspec buffer and in `:checkhealth`).
- `'formatexpr'` formats only the range `gq` is given, not the whole buffer.
- `'foldmethod'` is no longer set on shellspec buffers.

### Fixed

- `bin/shellspec-format` no longer drops a final line without a trailing newline, no longer replaces
  a file with truncated output when a write fails, keeps symlinks, stops on Ctrl-C, and reads
  `--indent-size` as decimal.
- `<< EOF`, lowercase and backslash-quoted HEREDOC delimiters are detected.
- `Mock`, `Data:raw`/`Data:expand` and `Parameters:*` blocks are indented.
- Range formatting and `gq` starting on an `End` line no longer shift the following lines.
- Vim: spec files are detected as `shellspec` (was `sh`), and `:{range}ShellSpecFormatRange` honours
  its range.
- `:ShellSpecFormatAsync` formats the buffer it was invoked from.
