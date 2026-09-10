[
  (bracket_comment)
  (line_comment)
] @comment

[
  (quoted_argument)
  (bracket_argument)
] @string

(escape_sequence) @escape

(variable) @variable

(normal_command (identifier) @function)

[
  (function)
  (endfunction)
  (macro)
  (endmacro)
  (if)
  (elseif)
  (else)
  (endif)
  (foreach)
  (endforeach)
  (while)
  (endwhile)
  (block)
  (endblock)
] @keyword

[
  "ENV"
  "CACHE"
] @keyword

(function_command (argument_list . (argument) @function))
(macro_command (argument_list . (argument) @macro))

((normal_command (identifier) @_set (argument_list . (argument) @variable))
 (#match? @_set "^(?i:set|unset|option|list|string|math|file|get_filename_component|find_package|find_library|find_program|find_path|cmake_parse_arguments)$"))

((normal_command (identifier) @_target (argument_list . (argument) @type))
 (#match? @_target "^(?i:project|add_executable|add_library|add_custom_target|add_test|add_subdirectory)$"))

((argument) @constant
 (#match? @constant "^[A-Z][A-Z0-9_]*$"))

((argument) @constant
 (#match? @constant "^(on|off|true|false|yes|no)$"))

((normal_command (identifier) @keyword)
 (#match? @keyword "^(?i:return|break|continue)$"))

[
  "$"
  "{"
  "}"
] @punctuation

[
  "("
  ")"
] @punctuation.bracket
