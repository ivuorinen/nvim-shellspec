" Syntax highlighting for ShellSpec DSL
if exists("b:current_syntax")
  finish
endif

" Keywords - Block structures
syn keyword shellspecBlock Describe Context ExampleGroup It Specify Example Todo End
syn keyword shellspecBlock xDescribe xContext xExampleGroup xIt xSpecify xExample
syn keyword shellspecBlock fDescribe fContext fExampleGroup fIt fSpecify fExample

" Keywords - Control flow
syn keyword shellspecControl Pending Skip
syn match shellspecControl "\<Skip\s\+if\>"

" Keywords - Evaluation
syn keyword shellspecEval When call run command script source

" Keywords - Expectation
syn keyword shellspecExpect The Assert should
syn keyword shellspecExpect output stdout error stderr status variable path
syn match shellspecExpect "\<should\s\+not\>"

" Keywords - Hooks
syn keyword shellspecHook BeforeEach AfterEach BeforeAll AfterAll Before After
syn keyword shellspecHook BeforeCall AfterCall BeforeRun AfterRun

" Keywords - Helpers
syn keyword shellspecHelper Dump Include Set Path File Dir Data Parameters
syn match shellspecHelper "\<Data:expand\>"
syn match shellspecHelper "\<Parameters:\(value\|matrix\|dynamic\)\>"

" Language chains
syn keyword shellspecChain a an as the

" Matchers and modifiers
syn keyword shellspecMatcher equal eq be exist valid satisfy
syn keyword shellspecModifier line word length contents result first second third
syn keyword shellspecModifier of

" Tags - for example groups and examples
syn match shellspecTag "\<\w\+:\w\+\>" contained

" Strings
syn region shellspecString start=+"+ skip=+\\"+ end=+"+ contains=shellspecVariable
syn region shellspecString start=+'+ end=+'+
syn match shellspecVariable "\$\w\+" contained
syn match shellspecVariable "\${\w\+}" contained

" Comments
syn match shellspecComment "#.*$" contains=shellspecTodo
syn keyword shellspecTodo TODO FIXME XXX NOTE contained

" Data blocks
syn match shellspecDataMarker "^#|" contained
syn region shellspecDataBlock start="Data\s*$" end="End" contains=shellspecDataMarker

" Numbers
syn match shellspecNumber "\<\d\+\>"

" Shell code in functions
syn include @shellCode $VIMRUNTIME/syntax/sh.vim
syn region shellspecShellCode start="^\s*\w\+\s*(" end="}" contains=@shellCode

" Highlighting groups
hi def link shellspecBlock Statement
hi def link shellspecControl Conditional
hi def link shellspecEval Function
hi def link shellspecExpect Keyword
hi def link shellspecHook PreProc
hi def link shellspecHelper Special
hi def link shellspecChain Operator
hi def link shellspecMatcher Function
hi def link shellspecModifier Type
hi def link shellspecTag Label
hi def link shellspecString String
hi def link shellspecVariable Identifier
hi def link shellspecComment Comment
hi def link shellspecTodo Todo
hi def link shellspecDataMarker SpecialChar
hi def link shellspecNumber Number

let b:current_syntax = "shellspec"
