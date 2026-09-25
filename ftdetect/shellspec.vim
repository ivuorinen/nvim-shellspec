" Filetype detection for ShellSpec DSL -- the single source for both Vim and
" Neovim.
"
" `set filetype=` rather than `setfiletype`: the runtime's own `*.sh` rule fires
" first and sets `sh`, and `setfiletype` is a no-op once a filetype is set, so
" spec files opened as plain `sh` and the plugin never activated in Vim.
"
" A pattern with no slash is matched against the basename, so `*_spec.sh` and
" `*.spec.sh` already catch spec files in any directory at any depth --
" including under test/. There is deliberately no `test/*.sh` rule: it claimed
" every shell script under a test/ directory, most of which are ordinary
" scripts rather than ShellSpec specs.
"
" The spec/ rules appear twice because a pattern containing a slash is matched
" against both the name as typed and the full path: the bare form catches
" `nvim spec/foo.sh`, the `*/` form catches `nvim /abs/path/spec/foo.sh`.
" `*` spans `/` in autocmd patterns, so both cover arbitrary nesting.
autocmd BufRead,BufNewFile *_spec.sh set filetype=shellspec
autocmd BufRead,BufNewFile *.spec.sh set filetype=shellspec
autocmd BufRead,BufNewFile spec/*.sh set filetype=shellspec
autocmd BufRead,BufNewFile */spec/*.sh set filetype=shellspec
