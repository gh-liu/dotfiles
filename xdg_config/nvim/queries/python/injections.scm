((call
  function: (attribute) @func_call
  arguments: (argument_list
    (string
      (string_content) @injection.content)))
  (#any-of? @func_call "conn.execute")
  (#set! injection.language "sql"))
