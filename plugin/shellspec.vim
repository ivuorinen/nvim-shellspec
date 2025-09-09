" ShellSpec DSL plugin
" Neovim language support for ShellSpec testing framework
" Repository: https://github.com/ivuorinen/nvim-shellspec
" Author: Ismo Vuorinen

if exists('g:loaded_shellspec')
  finish
endif
let g:loaded_shellspec = 1

" Version information
let g:shellspec_version = '2.0.2'

" Detect Neovim and use appropriate implementation
if has('nvim-0.7')
  " Use modern Neovim Lua implementation
  " Initialize with error handling
  lua << EOF
    local ok, err = pcall(function()
      -- Initialize configuration with defaults
      require('shellspec.config').setup()

      -- Setup autocommands and commands
      require('shellspec.autocmds').setup()

      -- Debug message
      if vim.g.shellspec_debug then
        vim.notify('ShellSpec Neovim: Loaded successfully', vim.log.levels.INFO)
      end
    end)

    if not ok then
      vim.notify('ShellSpec Neovim: Failed to load - ' .. tostring(err), vim.log.levels.ERROR)
    end
EOF

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
