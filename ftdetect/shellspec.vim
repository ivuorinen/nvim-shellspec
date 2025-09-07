" Filetype detection for ShellSpec DSL
autocmd BufRead,BufNewFile *_spec.sh setfiletype shellspec
autocmd BufRead,BufNewFile *.spec.sh setfiletype shellspec
autocmd BufRead,BufNewFile spec/*.sh setfiletype shellspec
autocmd BufRead,BufNewFile test/*.sh setfiletype shellspec
