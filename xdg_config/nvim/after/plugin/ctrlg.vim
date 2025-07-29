function! s:CtrlG()
  let msg = []

  let isfile = empty(expand("%:p"))==0
  let oldmsg = trim(execute("norm! 2"))
  let mtime = ""
  if isfile==1
    let mtime = strftime("%Y-%m-%d %H:%M", getftime(expand("%:p")))
  endif
  call insert(msg, printf("%s %s", oldmsg, mtime))

  call insert(msg, printf("dir: %s", fnamemodify(getcwd(), ":~")))

  if exists("*FugitiveHead")
    call insert(msg, printf("branch: %s", FugitiveHead(7)))
  endif

  let session = "?"
  if !empty(v:this_session)
    let session = fnamemodify(v:this_session, ":~")
  endif
  call insert(msg, printf("sess: %s", session))

  call insert(msg, printf("PID: %s", getpid()))

  let linenr = search("\\v^[[:alpha:]$_]", "bn", 1, 100)
  call insert(msg, printf("%d: %s", linenr, getline(linenr)))

  call foreach(reverse(msg), "echomsg v:val")
endfunction

nnoremap <c-g> <cmd> call <SID>CtrlG() <cr>
