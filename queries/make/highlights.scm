(comment) @comment

[
  (string)
  (raw_text)
] @string

(variable_assignment name: (word) @variable)
(define_directive name: (word) @variable)
(variable_reference (word) @variable)
(shell_assignment name: (word) @variable)

(targets (word) @function)

((targets (word) @keyword)
 (#match? @keyword "^[.][A-Z_]+$"))

(automatic_variable) @constant

((variable_reference (word) @constant)
 (#match? @constant "^(MAKE|MAKEFLAGS|MAKEFILE_LIST|MAKECMDGOALS|SHELL|CURDIR|VPATH|CC|CXX|CPP|LD|AR|AS|RM|CFLAGS|CXXFLAGS|CPPFLAGS|LDFLAGS|LDLIBS|ARFLAGS|ASFLAGS|MAKE_VERSION|[.]DEFAULT_GOAL|[.]RECIPEPREFIX|[.]VARIABLES|[.]FEATURES|[.]INCLUDE_DIRS)$"))

[
  "ifeq"
  "ifneq"
  "ifdef"
  "ifndef"
  "else"
  "endif"
  "define"
  "endef"
  "vpath"
  "undefine"
  "export"
  "unexport"
  "override"
  "private"
  "include"
  "sinclude"
  "-include"
] @keyword

[
  "subst"
  "patsubst"
  "strip"
  "findstring"
  "filter"
  "filter-out"
  "sort"
  "word"
  "words"
  "wordlist"
  "firstword"
  "lastword"
  "dir"
  "notdir"
  "suffix"
  "basename"
  "addsuffix"
  "addprefix"
  "join"
  "wildcard"
  "realpath"
  "abspath"
  "call"
  "eval"
  "file"
  "value"
  "shell"
  "error"
  "warning"
  "info"
  "if"
  "or"
  "and"
  "foreach"
] @function

[
  "="
  ":="
  "::="
  "?="
  "+="
  "!="
] @operator

[
  "$"
  "$$"
  ":"
  "&:"
  "::"
  "|"
  ";"
] @punctuation

[
  "("
  ")"
  "{"
  "}"
] @punctuation.bracket
