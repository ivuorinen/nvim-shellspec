" ShellSpec DSL formatter functions with HEREDOC and comment support
" Line continuations below need 'cpoptions' without the C flag. `vim -u NONE`
" implies 'compatible', which sets it -- and the script-local lists then never
" get defined, so every call fails with E121. This is the conventional guard for
" a distributed Vim plugin.
let s:cpo_save = &cpo
set cpo&vim
" Fallback implementation for Vim and Neovim < 0.7; the Lua modules under
" lua/shellspec/ are authoritative and this must match their behaviour.

" Lines that open a block. Block keywords require a following space and
" standalone hooks require end of line: without those anchors an ordinary
" assignment such as `Items=3` matches `It` and opens a block that is never
" closed, cascading misindentation through the rest of the file.
" `Mock`, `Data:raw`/`Data:expand` and the `Parameters:` variants open blocks
" too; without them their `End` closed the enclosing block instead.
let s:block_patterns = [
  \ '^[xf]\?\(Describe\|Context\|ExampleGroup\|It\|Specify\|Example\)\s',
  \ '^Mock\s',
  \ '^\(Data\|Parameters\)\(:\l\+\)\?\s*$',
  \ '^\(BeforeEach\|AfterEach\|BeforeAll\|AfterAll\|Before\|After\)\s*$',
  \ '^\(BeforeCall\|AfterCall\|BeforeRun\|AfterRun\)\s*$'
\ ]

" HEREDOC openers, each with one capture group holding the delimiter.
" All single-quoted: in a double-quoted Vim string an unrecognised escape drops
" its backslash, so "<<'\([^']*\)'" becomes the pattern <<'([^']*)' -- literal
" parentheses, no capture group, and quoted HEREDOCs went undetected.
" `\s*` and the optional backslash cover the POSIX spellings `<< EOF` and
" `<<\EOF`, and lowercase words are accepted; without them the terminator was
" indented and the shell never closed the HEREDOC.
let s:heredoc_patterns = [
  \ '<<-\?\s*\\\=\([A-Za-z_][A-Za-z0-9_]*\)',
  \ '<<-\?\s*''\([^'']\+\)''',
  \ '<<-\?\s*"\([^"]\+\)"'
\ ]

function! shellspec#format_buffer() abort
  if !&modifiable
    echohl ErrorMsg | echomsg 'ShellSpec: buffer is not modifiable' | echohl NONE
    return
  endif

  let l:pos = getpos('.')
  let l:formatted = shellspec#format_lines(getline(1, '$'))

  %delete _
  call setline(1, l:formatted)
  call setpos('.', l:pos)
endfunction

" Return the HEREDOC delimiter a line opens, or ''.
"
" Here-strings are rejected first: `<<<"word"` contains `<<"` at offset 1 and
" would otherwise match the double-quoted pattern, leaving the formatter in a
" HEREDOC state that no later line can end. Lines containing `((` are rejected
" too: the patterns accept a blank after `<<`, so the arithmetic shift in
" `$(( a << b ))` would otherwise open a HEREDOC that swallows the file.
function! s:detect_heredoc_start(trimmed) abort
  if stridx(a:trimmed, '<<<') >= 0 || stridx(a:trimmed, '((') >= 0
    return ''
  endif

  for l:pattern in s:heredoc_patterns
    let l:match = matchlist(a:trimmed, l:pattern)
    if !empty(l:match) && !empty(l:match[1])
      return l:match[1]
    endif
  endfor

  return ''
endfunction

function! s:is_block_keyword(trimmed) abort
  for l:pattern in s:block_patterns
    if a:trimmed =~# l:pattern
      return 1
    endif
  endfor
  return 0
endfunction

" Indent level a line sits at, from its existing leading whitespace.
" shiftwidth() rather than &shiftwidth: 'shiftwidth' 0 means "use 'tabstop'",
" and reading the raw option flattened every line to column 0.
function! s:indent_level_of(line) abort
  let l:leading = matchstr(a:line, '^\s*')
  if &expandtab
    return len(l:leading) / shiftwidth()
  endif
  return len(substitute(l:leading, '[^\t]', '', 'g'))
endfunction

" Enhanced format_lines with HEREDOC and comment support.
"
" a:000[0] seeds the indent level, defaulting to 0. Callers formatting a
" sub-range must pass the level the range sits at; without it a nested
" selection is re-indented as though it were a whole file and flattened to
" column 0 while the lines around it keep their original indent.
function! shellspec#format_lines(lines, ...) abort
  let l:result = []
  let l:indent = a:0 > 0 ? a:1 : 0
  let l:state = 'normal'  " States: normal, heredoc
  let l:heredoc_delimiter = ''
  let l:indent_comments = get(g:, 'shellspec_indent_comments', 1)
  " Honours 'shiftwidth' rather than hardcoding two spaces, so this path
  " respects the same width the Lua path takes from indent_size.
  let l:unit = &expandtab ? repeat(' ', shiftwidth()) : "\t"

  for l:line in a:lines
    let l:trimmed = trim(l:line)

    if l:trimmed ==# ''
      call add(l:result, l:line)
      continue
    endif

    if l:state ==# 'heredoc'
      " The terminator is emitted verbatim, like the body: a non-`<<-` HEREDOC
      " requires its delimiter at column 0, so indenting it leaves the shell
      " unable to close the HEREDOC and the rest of the file becomes body.
      if !empty(l:heredoc_delimiter) && l:trimmed ==# l:heredoc_delimiter
        let l:state = 'normal'
        let l:heredoc_delimiter = ''
      endif
      call add(l:result, l:line)
      continue
    endif

    " Checked before HEREDOCs so a comment that merely mentions `<<EOF` does
    " not put the formatter into a HEREDOC state.
    if l:trimmed =~# '^#'
      if l:indent_comments
        call add(l:result, repeat(l:unit, l:indent) . l:trimmed)
      else
        call add(l:result, l:line)
      endif
      continue
    endif

    if l:trimmed =~# '^End\s*$'
      let l:indent = max([0, l:indent - 1])
      call add(l:result, repeat(l:unit, l:indent) . l:trimmed)
      continue
    endif

    call add(l:result, repeat(l:unit, l:indent) . l:trimmed)

    " Checked before the HEREDOC start so a line that is both -- `It "x" <<EOF`
    " -- still opens its block.
    if s:is_block_keyword(l:trimmed)
      let l:indent += 1
    endif

    let l:delimiter = s:detect_heredoc_start(l:trimmed)
    if !empty(l:delimiter)
      let l:state = 'heredoc'
      let l:heredoc_delimiter = l:delimiter
    endif
  endfor

  return l:result
endfunction

" Format lines a:start..a:end.
"
" The range is passed in by :ShellSpecFormatRange as <line1>,<line2>. Reading
" the '< and '> marks instead ignored an explicit `:2,4ShellSpecFormatRange`.
"
" The indent level is taken from the first line's existing indentation, so a
" range whose opening keyword lies outside it keeps its place in the block
" structure instead of flattening to column 0. An `End` first line is seeded
" one level deeper, because format_lines decrements before emitting it.
"
" setline() replaces in place: format_lines never adds or removes lines, and
" the old delete-then-append left Vim's one surviving empty line behind when
" the range covered the whole buffer.
function! shellspec#format_selection(start, end) abort
  if !&modifiable
    echohl ErrorMsg | echomsg 'ShellSpec: buffer is not modifiable' | echohl NONE
    return
  endif

  let l:lines = getline(a:start, a:end)
  if empty(l:lines)
    return
  endif

  let l:seed = s:indent_level_of(l:lines[0])
  if trim(l:lines[0]) =~# '^End\s*$'
    let l:seed += 1
  endif

  call setline(a:start, shellspec#format_lines(l:lines, l:seed))
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
