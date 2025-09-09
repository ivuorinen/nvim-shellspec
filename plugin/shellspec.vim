" ShellSpec DSL plugin
" Neovim language support for ShellSpec testing framework
" Repository: https://github.com/ivuorinen/nvim-shellspec
" Author: Ismo Vuorinen

if exists('g:loaded_shellspec')
  finish
endif
let g:loaded_shellspec = 1

" Detect Neovim and use appropriate implementation
if has('nvim-0.7')
  " Use modern Neovim Lua implementation
  lua require('shellspec.autocmds').setup()

  " Create commands that delegate to Lua
  command! ShellSpecFormat lua require('shellspec').format_buffer()
  command! -range ShellSpecFormatRange lua require('shellspec').format_selection(0, <line1>, <line2>)

  " Optional: Auto-format on save (handled in Lua)
  " This is now managed by the Lua autocmds module based on configuration

else
  " Fallback to VimScript implementation for older Vim
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
endif
