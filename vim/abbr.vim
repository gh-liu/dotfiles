iabbrev thsi this
iabbrev cosnt const

function! SetupCommandAbbrs(from, to)
  exec 'cnoreabbrev <expr> '.a:from
        \ .' ((getcmdtype() ==# ":" && getcmdline() ==# "'.a:from.'")'
        \ .'? ("'.a:to.'") : ("'.a:from.'"))'
endfunction

call SetupCommandAbbrs('C', 'CocConfig')
call SetupCommandAbbrs('CR', 'CocRestart')
call SetupCommandAbbrs('L', 'CocList')
call SetupCommandAbbrs('S', 'CocSearch')

