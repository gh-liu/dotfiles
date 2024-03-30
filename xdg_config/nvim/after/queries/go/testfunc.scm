(function_declaration
  name: (identifier) @testfuncname
  parameters: (parameter_list
    . (parameter_declaration
      type: (pointer_type) @testtype) .)
  (#match? @testtype "*testing.(T)")
  (#match? @testfuncname "^Test.+$")) @testfunc

(function_declaration
  name: (identifier) @benchfuncname
  parameters: (parameter_list
    . (parameter_declaration
      type: (pointer_type) @testtype) .)
  (#match? @testtype "*testing.B")
  (#match? @benchfuncname "^Benchmark.+$")) @benchfunc

(function_declaration
  name: (identifier) @fuzzfuncname
  parameters: (parameter_list
    . (parameter_declaration
      type: (pointer_type) @testtype) .)
  (#match? @testtype "*testing.F")
  (#match? @fuzzfuncname "^Fuzz.+$")) @fuzzfunc
	
