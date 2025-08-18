; top declarations
([
  (type_declaration)
  (function_declaration)
  (method_declaration)
  (var_declaration)
  (const_declaration)
  (import_declaration)
] @context
  (#has-parent? @context source_file))
