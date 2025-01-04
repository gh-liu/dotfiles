# https://ianthehenry.com/posts/tmux-copy-last-command
bind -n S-M-Up {
  copy-mode
  send -X clear-selection
  send -X start-of-line
  send -X start-of-line
  send -X cursor-up
  send -X start-of-line
  send -X start-of-line

  # check if current line match prompt
  if -F "#{m:*> *,#{copy_cursor_line}}" {
    # select the command
    send -X search-forward-text "> "
    send -X stop-selection
    # move the cursor after the > sign
    send -X -N 2 cursor-right
    send -X begin-selection
    send -X end-of-line
    send -X end-of-line
    # the > sign in the end
    if "#{m:*> ?*,#{copy_cursor_line}}" {
      send -X cursor-left
    }
  } {
    send -X end-of-line
    send -X end-of-line
    send -X begin-selection
    send -X search-backward-text "> "
    send -X end-of-line
    send -X end-of-line
    send -X cursor-right
    send -X stop-selection
  }
}

bind -n S-M-Down {
  copy-mode
  send -X clear-selection
  send -X start-of-line
  send -X start-of-line
  send -X cursor-down
  send -X start-of-line
  send -X start-of-line
  
  if -F "#{m:*> *,#{copy_cursor_line}}" {
    send -X search-forward-text "> "
    send -X stop-selection
    send -X -N 2 cursor-right
    send -X begin-selection
    send -X end-of-line
    send -X end-of-line
    if "#{m:*> ?*,#{copy_cursor_line}}" {
      send -X cursor-left
    }
  } {
    send -X start-of-line
    send -X start-of-line
    send -X begin-selection
    send -X search-forward-text "> "
    send -X cursor-up
    send -X end-of-line
    send -X end-of-line
    send -X stop-selection
  }
}
