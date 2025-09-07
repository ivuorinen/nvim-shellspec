# Neovim ShellSpec DSL Support

Language support and formatter for ShellSpec DSL testing framework.

## Installation

### With [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "ivuorinen/nvim-shellspec",
  ft = "shellspec",
}
```

### With [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'ivuorinen/nvim-shellspec'
```

### Manual Installation

```bash
git clone https://github.com/ivuorinen/nvim-shellspec.git ~/.config/nvim/pack/plugins/start/nvim-shellspec
```

## Features

- **Syntax highlighting** for all ShellSpec DSL keywords
- **Automatic indentation** for block structures
- **Filetype detection** for `*_spec.sh`, `*.spec.sh`, and `spec/*.sh`
- **Formatting commands** with proper indentation

## Usage

### Commands

- `:ShellSpecFormat` - Format entire buffer
- `:ShellSpecFormatRange` - Format selected lines

### Auto-format

Add to your config to enable auto-format on save:

```vim
let g:shellspec_auto_format = 1
```

### File Types

Plugin activates for files matching:

- `*_spec.sh`
- `*.spec.sh`
- `spec/*.sh`
- `test/*.sh`

## Configuration

```vim
" Enable auto-formatting on save
let g:shellspec_auto_format = 1

" Custom keybindings
autocmd FileType shellspec nnoremap <buffer> <leader>f :ShellSpecFormat<CR>
autocmd FileType shellspec vnoremap <buffer> <leader>f :ShellSpecFormatRange<CR>
```

## Contributing

Contributions welcome! Please open issues and pull requests at:
<https://github.com/ivuorinen/nvim-shellspec>

## License

MIT License - see repository for details.

## Related

- [ShellSpec](https://github.com/shellspec/shellspec) - BDD testing framework for shell scripts
