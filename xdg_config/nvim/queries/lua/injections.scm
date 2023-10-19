; extends

(function_call 
	name: (dot_index_expression  
                field: (identifier)@_prefix_1 .)
	arguments: (arguments 
                     (string content: (string_content)@injection.content) .)
        (#match? @_prefix_1 "set|parse_query")
        (#set! injection.language "query")
        )

