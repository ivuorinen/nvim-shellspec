" Indentation for ShellSpec DSL
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

" Autoload rather than a global GetShellSpecIndent(): a script-local `s:` name
" does not resolve when 'indentexpr' is evaluated, and a global one would occupy
" that name for the whole Vim session.
setlocal indentexpr=shellspec#indent#Get()
setlocal indentkeys=!^F,o,O,e,=End

" Restores both options when 'filetype' changes away from shellspec.
let b:undo_indent = 'setlocal indentexpr< indentkeys<'
