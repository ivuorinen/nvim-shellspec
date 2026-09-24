" 'indentexpr' implementation for the ShellSpec DSL.
" Line continuations below need 'cpoptions' without the C flag. `vim -u NONE`
" implies 'compatible', which sets it -- and the script-local lists then never
" get defined, so every call fails with E121. This is the conventional guard for
" a distributed Vim plugin.
let s:cpo_save = &cpo
set cpo&vim

" Block keywords require a following space and standalone hooks require end of
" line, matching lua/shellspec/format.lua. Without those anchors an ordinary
" assignment such as `Items=3` matches `It` and gains an indent level.
" `Mock`, `Data:raw`/`Data:expand` and the `Parameters:` variants open blocks
" too, as in the formatter.
let s:block_pattern =
  \ '^\s*\%([xf]\?\%(Describe\|Context\|ExampleGroup\|It\|Specify\|Example\)\s' .
  \ '\|Mock\s' .
  \ '\|\%(Data\|Parameters\)\%(:\l\+\)\=\s*$' .
  \ '\|\%(BeforeEach\|AfterEach\|BeforeAll\|AfterAll\|Before\|After\)\s*$' .
  \ '\|\%(BeforeCall\|AfterCall\|BeforeRun\|AfterRun\)\s*$\)'

" Indent for v:lnum.
"
" Looks back with prevnonblank() rather than at v:lnum - 1 directly: a blank
" line has indent 0, so basing the fallback on it dropped every line typed
" after a blank line inside a block to column 0.
function! shellspec#indent#Get() abort
  let l:prevlnum = prevnonblank(v:lnum - 1)
  if l:prevlnum == 0
    return 0
  endif

  let l:line = getline(v:lnum)
  let l:prevline = getline(l:prevlnum)

  " Leave comments where the user put them
  if l:line =~# '^\s*#'
    return -1
  endif

  " End closes a block. Directly after its opener (an empty or pending example)
  " it aligns with that opener; dedenting from it put `End` a level too far out.
  if l:line =~# '^\s*End\s*$'
    if l:prevline =~# s:block_pattern
      return indent(l:prevlnum)
    endif
    return max([0, indent(l:prevlnum) - shiftwidth()])
  endif

  " A block keyword opens one
  if l:prevline =~# s:block_pattern
    return indent(l:prevlnum) + shiftwidth()
  endif

  return indent(l:prevlnum)
endfunction

let &cpo = s:cpo_save
unlet s:cpo_save
