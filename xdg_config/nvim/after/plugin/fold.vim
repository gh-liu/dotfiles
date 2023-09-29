" :h fold-foldtext
" v:foldstart	line number of first line in the fold
" v:foldend	line number of last line in the fold
" v:folddashes	a string that contains dashes to represent the foldlevel.
" v:foldlevel	the foldlevel of the fold
" set foldtext=MyFoldText()

function MyFoldText()
  let line = getline(v:foldstart)
  " This shows the first line of the fold, with "/*", "*/" and "{{{" removed.
  let sub = substitute(line, '/\*\|\*/\|{{{\d\=', '', 'g')

    let foldsize = (v:foldend - v:foldstart)

    let linecount = '[' . foldsize . ' line' . (foldsize > 1 ? 's' : ''). ']'

    let padding = repeat(" ",5-len(foldsize))

    " return '+' . v:folddashes . '(' . v:foldlevel . ') ' . linecount . padding . sub
    return [[sub, "PreProc"], ["...","NonText"], [' +' . v:folddashes . '(' . v:foldlevel . ') ' . linecount . padding, "NonText"]]
  endfunction
