# nvim-shellspec Project Overview

## Purpose

This is a Neovim/Vim plugin that provides advanced language support and formatting for the ShellSpec DSL testing framework.
ShellSpec is a BDD (Behavior-Driven Development) testing framework for shell scripts.

## Key Features

- **🚀 First-class Neovim support** with modern Lua implementation
- **🎨 Syntax highlighting** for all ShellSpec DSL keywords
- **📐 Smart indentation** for block structures  
- **📄 Enhanced filetype detection** for `*_spec.sh`, `*.spec.sh`, `spec/*.sh`, `test/*.sh`, and nested spec directories
- **✨ Advanced formatting** with HEREDOC and comment support
- **⚡ Async formatting** to prevent blocking (Neovim 0.7+)
- **🔄 Backward compatibility** with Vim and older Neovim versions

## Advanced Formatting Features

- **HEREDOC Preservation**: Maintains original formatting within `<<EOF`, `<<'EOF'`, `<<"EOF"`, and `<<-EOF` blocks
- **Smart Comment Indentation**: Comments are indented to match surrounding code level
- **Context-Aware Formatting**: State machine tracks formatting context for accurate indentation

## Tech Stack

- **Primary language**: Vim script (VimL) + Lua (Neovim)
- **Target environment**: Neovim 0.7+ (with Vim fallback)
- **Architecture**: Modular Lua implementation with VimScript compatibility layer
- **Shell scripting**: Bash (for standalone formatter in `bin/shellspec-format`)
- **Configuration formats**: YAML, JSON, EditorConfig

## Dual Implementation

- **Neovim 0.7+**: Modern Lua implementation with native APIs
- **Vim/Older Neovim**: Enhanced VimScript with same formatting features

## Target Files

Plugin activates for files matching:

- `*_spec.sh`
- `*.spec.sh`
- `spec/*.sh`
- `test/*.sh`
- Files in nested `spec/` directories

## Related Project

- [ShellSpec](https://github.com/shellspec/shellspec) - BDD testing framework for shell scripts
