(function_declaration
  name: (identifier) @func)


(method_declaration
  receiver: (parameter_list
	      (parameter_declaration
		name: (identifier)
		type: [(type_identifier) @type
					 (pointer_type
					   (type_identifier) @type)]))
  name: (field_identifier) @method)
