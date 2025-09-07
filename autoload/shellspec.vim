" ShellSpec DSL formatter functions

function! shellspec#format_buffer() abort
  let l:pos = getpos('.')
  let l:lines = getline(1, '$')
  let l:formatted = shellspec#format_lines(l:lines)

  silent! %delete _
  call setline(1, l:formatted)
  call setpos('.', l:pos)
endfunction

function! shellspec#format_lines(lines) abort
  let l:result = []
  let l:indent = 0

  for l:line in a:lines
    let l:trimmed = trim(l:line)

    " Skip empty lines and comments
    if l:trimmed == '' || l:trimmed =~ '^#'
      call add(l:result, l:line)
      continue
    endif

    " Decrease indent for End
    if l:trimmed =~ '^End\s*$'
      let l:indent = max([0, l:indent - 1])
    endif

    " Apply current indentation
    let l:formatted = repeat('  ', l:indent) . l:trimmed
    call add(l:result, l:formatted)

    " Increase indent after block keywords
    if l:trimmed =~ '^\(Describe\|Context\|ExampleGroup\|It\|Specify\|Example\)'
      let l:indent += 1
    elseif l:trimmed =~ '^\([xf]\)\(Describe\|Context\|ExampleGroup\|It\|Specify\|Example\)'
      let l:indent += 1
    elseif l:trimmed =~ '^\(Data\|Parameters\)\s*$'
      let l:indent += 1
    endif
  endfor

  return l:result
endfunction

function! shellspec#format_selection() abort
  let l:start = line("'<")
  let l:end = line("'>")
  let l:lines = getline(l:start, l:end)
  let l:formatted = shellspec#format_lines(l:lines)

  call deletebufline('%', l:start, l:end)
  call append(l:start - 1, l:formatted)
endfunction
