(function_declaration
  name: (identifier) @testfuncname
  parameters: (parameter_list
    .
    (parameter_declaration
      type: (pointer_type) @testtype) .)
  (#match? @testtype "*testing.(T)")
  (#match? @testfuncname "^Test.+$")) @testfunc

(function_declaration
  name: (identifier) @benchfuncname
  parameters: (parameter_list
    .
    (parameter_declaration
      type: (pointer_type) @testtype) .)
  (#match? @testtype "*testing.B")
  (#match? @benchfuncname "^Benchmark.+$")) @benchfunc

(function_declaration
  name: (identifier) @fuzzfuncname
  parameters: (parameter_list
    .
    (parameter_declaration
      type: (pointer_type) @testtype) .)
  (#match? @testtype "*testing.F")
  (#match? @fuzzfuncname "^Fuzz.+$")) @fuzzfunc

(function_declaration
  name: (identifier) @func)

(method_declaration
  receiver: (parameter_list
    (parameter_declaration
      name: (identifier)
      type: [
        (type_identifier) @method_receiver
        (pointer_type
          (type_identifier) @method_receiver)
      ]))
  name: (field_identifier) @method)
