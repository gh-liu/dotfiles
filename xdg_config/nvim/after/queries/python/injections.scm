;; extends

((call
  function: (attribute) @func_call
  arguments: (argument_list
    (string
      (string_content) @injection.content)))
  (#any-of? @func_call "conn.execute")
  (#set! injection.language "sql"))

; Inject language based on # ft:<lang> comment above a string
; [] matches either bare string or assignment (e.g., data = """...""")
; #gsub! extracts the language, @injection.language reads the modified text
(
  (comment) @injection.language
  .
  (_
    [
      (string
        (string_content) @injection.content)
      (assignment
        (string
          (string_content) @injection.content))
      (return_statement
        (string
          (string_content) @injection.content))
    ])
  (#match? @injection.language "^\\s*#\\s*ft:\\s*[a-zA-Z_]+\\s*$")
  (#gsub! @injection.language "^%s*#%s*ft:%s*([a-zA-Z_]+)%s*$" "%1"))
