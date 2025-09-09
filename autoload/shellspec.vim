" ShellSpec DSL formatter functions with HEREDOC and comment support

function! shellspec#format_buffer() abort
  let l:pos = getpos('.')
  let l:lines = getline(1, '$')
  let l:formatted = shellspec#format_lines(l:lines)

  silent! %delete _
  call setline(1, l:formatted)
  call setpos('.', l:pos)
endfunction

" Detect HEREDOC start and return delimiter
function! s:detect_heredoc_start(line) abort
  let l:trimmed = trim(a:line)

  " Check for various HEREDOC patterns
  let l:patterns = [
    \ '<<\([A-Z_][A-Z0-9_]*\)',
    \ "<<'\([^']*\)'",
    \ '<<"\([^"]*\)"',
    \ '<<-\([A-Z_][A-Z0-9_]*\)'
  \ ]

  for l:pattern in l:patterns
    let l:match = matchlist(l:trimmed, l:pattern)
    if !empty(l:match)
      return l:match[1]
    endif
  endfor

  return ''
endfunction

" Check if line ends a HEREDOC
function! s:is_heredoc_end(line, delimiter) abort
  if empty(a:delimiter)
    return 0
  endif
  return trim(a:line) ==# a:delimiter
endfunction

" Enhanced format_lines with HEREDOC and comment support
function! shellspec#format_lines(lines) abort
  let l:result = []
  let l:indent = 0
  let l:state = 'normal'  " States: normal, heredoc
  let l:heredoc_delimiter = ''
  let l:indent_comments = get(g:, 'shellspec_indent_comments', 1)

  for l:line in a:lines
    let l:trimmed = trim(l:line)

    " Handle empty lines
    if l:trimmed == ''
      call add(l:result, l:line)
      continue
    endif

    " State machine for HEREDOC handling
    if l:state ==# 'normal'
      " Check for HEREDOC start
      let l:delimiter = s:detect_heredoc_start(l:line)
      if !empty(l:delimiter)
        let l:state = 'heredoc'
        let l:heredoc_delimiter = l:delimiter
        " Apply current indentation to HEREDOC start line
        let l:formatted = repeat('  ', l:indent) . l:trimmed
        call add(l:result, l:formatted)
        continue
      endif

      " Handle comments with proper indentation
      if l:trimmed =~ '^#' && l:indent_comments
        let l:formatted = repeat('  ', l:indent) . l:trimmed
        call add(l:result, l:formatted)
        continue
      endif

      " Handle End keyword (decrease indent first)
      if l:trimmed =~ '^End\s*$'
        let l:indent = max([0, l:indent - 1])
        let l:formatted = repeat('  ', l:indent) . l:trimmed
        call add(l:result, l:formatted)
        continue
      endif

      " Apply normal indentation for other lines
      if l:trimmed !~ '^#' || !l:indent_comments
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
      else
        " Preserve original comment formatting if indent_comments is false
        call add(l:result, l:line)
      endif

    elseif l:state ==# 'heredoc'
      " Check for HEREDOC end
      if s:is_heredoc_end(l:line, l:heredoc_delimiter)
        let l:state = 'normal'
        let l:heredoc_delimiter = ''
        " Apply current indentation to HEREDOC end line
        let l:formatted = repeat('  ', l:indent) . l:trimmed
        call add(l:result, l:formatted)
      else
        " Preserve original indentation within HEREDOC
        call add(l:result, l:line)
      endif
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
