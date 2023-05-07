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

" function! MyFoldText()
"   let comment_str = split(&commentstring, '%s')[0]
"   let comment_str = substitute(comment_str, ' ', '', '')

"   let level = v:foldlevel
"   let indent = repeat(comment_str, level)
"   " let indent = repeat(comment_str, level) .. level .. ": "

"   let regex = '^'.comment_str.'\+\s*\|\s*{{{\d\s*'
"   let title = substitute(getline(v:foldstart), regex, '', 'g')

"   let foldsize = (v:foldend - v:foldstart)
"   let linecount = '['.foldsize.' line'.(foldsize>1?'s':'').']'

"   return indent.' '.title.' '.linecount
" endfunction
