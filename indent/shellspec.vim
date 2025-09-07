" Indentation for ShellSpec DSL
if exists("b:did_indent")
  finish
endif
let b:did_indent = 1

setlocal indentexpr=GetShellSpecIndent()
setlocal indentkeys=!^F,o,O,e,=End

function! GetShellSpecIndent()
  let line = getline(v:lnum)
  let prevline = getline(v:lnum - 1)

  " Don't change indentation for comments
  if line =~ '^\s*#'
    return -1
  endif

  " End decreases indent
  if line =~ '^\s*End\s*$'
    return indent(v:lnum - 1) - &shiftwidth
  endif

  " After block start keywords, increase indent
  if prevline =~ '^\s*\(Describe\|Context\|ExampleGroup\|It\|Specify\|Example\)'
    return indent(v:lnum - 1) + &shiftwidth
  endif

  " After prefixed block keywords
  if prevline =~ '^\s*\([xf]\)\(Describe\|Context\|ExampleGroup\|It\|Specify\|Example\)'
    return indent(v:lnum - 1) + &shiftwidth
  endif

  " After Data blocks
  if prevline =~ '^\s*Data\s*$'
    return indent(v:lnum - 1) + &shiftwidth
  endif

  " After Parameters blocks
  if prevline =~ '^\s*Parameters'
    return indent(v:lnum - 1) + &shiftwidth
  endif

  " Keep same indent for most lines
  return indent(v:lnum - 1)
endfunction
