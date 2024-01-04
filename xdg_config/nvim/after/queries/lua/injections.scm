; extends

(function_call 
  name: (dot_index_expression  
          field: (identifier)@_prefix_1 .)
  arguments: (arguments 
               (string content: (_)@injection.content) .)
  (#any-of? @_prefix_1 "parse_query")
  (#set! injection.language "query")
  )

