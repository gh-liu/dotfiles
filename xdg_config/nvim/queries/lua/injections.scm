; Inject Lua code in child.lua("...") calls (mini.test child Neovim methods)
((function_call
  name: (_
    (identifier) @_child
    .
    (identifier) @_lua_method)
  arguments: (arguments
    (string
      content: _ @injection.content)))
  (#eq? @_child "child")
  (#any-of? @_lua_method "lua" "lua_get" "lua_func")
  (#set! injection.language "lua"))

; Inject Vimscript code in child.cmd("...") and child.cmd_capture("...") calls (mini.test child Neovim methods)
((function_call
  name: (_
    (identifier) @_child
    .
    (identifier) @_cmd_method)
  arguments: (arguments
    (string
      content: _ @injection.content)))
  (#eq? @_child "child")
  (#any-of? @_cmd_method "cmd" "cmd_capture")
  (#set! injection.language "vim"))
