id: go-pointer-receiver-nil-check
language: go
rule:
  kind: method_declaration > block
  pattern: $BODY
  has:
    kind: if_statement
    pattern: $IF
  inside:
    kind: method_declaration
    has:
      kind: parameter_list
      field: receiver
      has:
        kind: parameter_declaration
        pattern: "$R $T"
constraints:
  IF:
    not:
      has:
        kind: binary_expression
        pattern: $R == nil
transform:
  BODY_NO_BRACES:
    substring:
      source: $BODY
      startChar: 1
      endChar: -1
fix: "{\nif $R == nil {return nil}\n   $BODY_NO_BRACES}"
# severity: warning
