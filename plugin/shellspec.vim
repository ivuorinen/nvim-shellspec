" ShellSpec DSL plugin
" Neovim language support for ShellSpec testing framework
" Repository: https://github.com/ivuorinen/nvim-shellspec
" Author: Ismo Vuorinen

if exists('g:loaded_shellspec')
  finish
endif
let g:loaded_shellspec = 1

" Commands
command! ShellSpecFormat call shellspec#format_buffer()
command! -range ShellSpecFormatRange call shellspec#format_selection()

" Auto commands
augroup ShellSpec
  autocmd!
  autocmd FileType shellspec setlocal commentstring=#\ %s
  autocmd FileType shellspec setlocal foldmethod=indent
  autocmd FileType shellspec setlocal shiftwidth=2 tabstop=2 expandtab
augroup END

" Optional: Auto-format on save
if get(g:, 'shellspec_auto_format', 0)
  augroup ShellSpecAutoFormat
    autocmd!
    autocmd BufWritePre *.spec.sh,*_spec.sh ShellSpecFormat
  augroup END
endif
