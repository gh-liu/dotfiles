iabbrev thsi this
iabbrev cosnt const

function! SetupCommandAbbrs(from, to)
  exec 'cnoreabbrev <expr> '.a:from
       \ .' ((getcmdtype() ==# ":" && getcmdline() ==# "'.a:from.'")'
       \ .'? ("'.a:to.'") : ("'.a:from.'"))'
endfun

call SetupCommandAbbrs('H', 'h')
call SetupCommandAbbrs('LE', 'Lexplore')

" fzf.vim
call SetupCommandAbbrs('RG', 'Rg')

" coc-nvim
call SetupCommandAbbrs('CS', 'CocSearch')
call SetupCommandAbbrs('CR', 'CocRestart')
call SetupCommandAbbrs('CC', 'CocConfig')
call SetupCommandAbbrs('CL', 'CocList')
call SetupCommandAbbrs('CLD', 'CocList diagnostics')
call SetupCommandAbbrs('CLE', 'CocList extensions')
call SetupCommandAbbrs('CLC', 'CocList commands')
call SetupCommandAbbrs('CLO', 'CocList outline')
call SetupCommandAbbrs('CLS', 'CocList symbols')
call SetupCommandAbbrs('CLL', 'CocListResume')

" vim-plug
call SetupCommandAbbrs('PU', 'PlugUpdate')
call SetupCommandAbbrs('PC', 'PlugClean')

" Golang
call SetupCommandAbbrs('GA','GoTestToggle')
call SetupCommandAbbrs('GGT','GoGenTestFile')
call SetupCommandAbbrs('GGF','GoGenTestFunc')
call SetupCommandAbbrs('GGE','GoGenTestExpo')
call SetupCommandAbbrs('GTT','GoTest')
call SetupCommandAbbrs('GTF','GoTestFunc')
call SetupCommandAbbrs('GDS','GoDebugStart')
call SetupCommandAbbrs('GDQ','GoDebugStop')
call SetupCommandAbbrs('GR','GoRun')
call SetupCommandAbbrs('GI','GoImpl')
call SetupCommandAbbrs('GCE','GoCallees')
call SetupCommandAbbrs('GCR','GoCallers')
call SetupCommandAbbrs('GCK','GoCallstack')

" Splitjoin
call SetupCommandAbbrs('SJ','SplitjoinJoin')
call SetupCommandAbbrs('SS','SplitjoinSplit')

" vim-choosewin
" call SetupCommandAbbrs('CW', 'ChooseWin')

" markdown
" call SetupCommandAbbrs('MP', 'MarkdownPreview')
