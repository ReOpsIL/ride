(identifier) @variable

((identifier) @constant
 (#match? @constant "^[A-Z][A-Z0-9_]+$"))

[
  "break"
  "case"
  "const"
  "continue"
  "default"
  "do"
  "else"
  "enum"
  "extern"
  "for"
  "goto"
  "if"
  "inline"
  "register"
  "restrict"
  "return"
  "sizeof"
  "static"
  "struct"
  "switch"
  "typedef"
  "union"
  "volatile"
  "while"
  "_Atomic"
  "_Generic"
  "_Noreturn"
  "alignas"
  "alignof"
  "asm"
  "constexpr"
  "noreturn"
  "offsetof"
  "thread_local"
  "__asm__"
  "__attribute__"
  "__extension__"
  "__inline"
  "__inline__"
] @keyword

[
  "#define"
  "#elif"
  "#elifdef"
  "#elifndef"
  "#else"
  "#endif"
  "#if"
  "#ifdef"
  "#ifndef"
  "#include"
] @keyword

(preproc_directive) @keyword
(preproc_defined "defined" @keyword)

(preproc_def
  name: (identifier) @macro)
(preproc_function_def
  name: (identifier) @macro)
(preproc_ifdef
  name: (identifier) @macro)

[
  "--"
  "-"
  "-="
  "->"
  "="
  "!="
  "*"
  "&"
  "&&"
  "+"
  "++"
  "+="
  "<"
  "=="
  ">"
  "||"
  "!"
  "%"
  "%="
  "&="
  "*="
  "/"
  "/="
  "<<"
  "<<="
  "<="
  ">="
  ">>"
  ">>="
  "^"
  "^="
  "|"
  "|="
  "~"
  "?"
] @operator

[
  "."
  ";"
  ":"
  ","
  "::"
] @punctuation.delimiter

(string_literal) @string
(system_lib_string) @string
(char_literal) @string
(escape_sequence) @escape
(number_literal) @number

[
  (true)
  (false)
  (null)
] @constant.builtin

(type_identifier) @type
(primitive_type) @type.builtin
(sized_type_specifier) @type.builtin

(field_identifier) @property
(statement_identifier) @label

(enumerator
  name: (identifier) @constant)

(parameter_declaration
  declarator: (identifier) @variable.parameter)

(attribute_specifier) @attribute
(attribute_declaration) @attribute

(call_expression
  function: (identifier) @function)
(call_expression
  function: (field_expression
    field: (field_identifier) @function.method))
(function_declarator
  declarator: (identifier) @function)

(comment) @comment
