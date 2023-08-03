set foldtext=MyFoldText()

function MyFoldText()
  let line = getline(v:foldstart)
  " This shows the first line of the fold, with "/*", "*/" and "{{{" removed.
  let sub = substitute(line, '/\*\|\*/\|{{{\d\=', '', 'g')

  let foldsize = (v:foldend - v:foldstart)

  let linecount = '[' . foldsize . ' line' . (foldsize > 1 ? 's' : ''). ']'

  let padding = repeat(" ",5-len(foldsize))

  return '+' . v:folddashes . '(' . v:foldlevel . ') ' . linecount . padding . sub
endfunction
