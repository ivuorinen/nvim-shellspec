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

" Detect Neovim and use appropriate implementation.
" 0.10 is what the Lua path actually needs: nvim_set_option_value's `buf` key
" arrived in 0.8 and vim.health.start/ok in 0.10. The gate used to say 0.7,
" which sent 0.7-0.9 down a path that errored on every FileType event and in
" :checkhealth. Older Neovim takes the VimScript fallback instead.
if has('nvim-0.10')
  " Use modern Neovim Lua implementation
  " Initialize with error handling
  lua << EOF
    local ok, err = pcall(function()
      -- Registers commands and autocommands against the default config.
      -- shellspec.config calls its own setup() at module load, so there is
      -- nothing to initialise here first. A later require('shellspec').setup()
      -- replaces these registrations rather than adding to them.
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
  " Commands. -bar so `:ShellSpecFormat | w` chains; the range is passed
  " explicitly because the '< '> marks ignore an explicit :{range}.
  command! -bar ShellSpecFormat call shellspec#format_buffer()
  command! -bar -range ShellSpecFormatRange call shellspec#format_selection(<line1>, <line2>)

  " Auto commands. No 'foldmethod': folding is the user's choice, and forcing
  " indent folds opened every spec fully folded.
  augroup ShellSpec
    autocmd!
    autocmd FileType shellspec setlocal commentstring=#\ %s
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
