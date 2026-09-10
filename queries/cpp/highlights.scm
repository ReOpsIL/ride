[
  "catch"
  "class"
  "co_await"
  "co_return"
  "co_yield"
  "concept"
  "consteval"
  "constinit"
  "decltype"
  "delete"
  "explicit"
  "final"
  "friend"
  "mutable"
  "namespace"
  "new"
  "noexcept"
  "operator"
  "override"
  "private"
  "protected"
  "public"
  "requires"
  "static_assert"
  "template"
  "throw"
  "try"
  "typename"
  "using"
  "virtual"
  "and"
  "and_eq"
  "bitand"
  "bitor"
  "compl"
  "not"
  "not_eq"
  "or"
  "or_eq"
  "xor"
  "xor_eq"
] @keyword

(auto) @type.builtin
(this) @variable.builtin

((namespace_identifier) @type
 (#match? @type "^[A-Z]"))

(namespace_definition
  name: (namespace_identifier) @type)

(concept_definition
  name: (identifier) @type)

(raw_string_literal) @string

(call_expression
  function: (qualified_identifier
    name: (identifier) @function))
(call_expression
  function: (template_function
    name: (identifier) @function))
(call_expression
  function: (field_expression
    field: (template_method
      name: (field_identifier) @function.method)))

(template_function
  name: (identifier) @function)
(template_method
  name: (field_identifier) @function.method)

(function_declarator
  declarator: (qualified_identifier
    name: (identifier) @function))
(function_declarator
  declarator: (field_identifier) @function.method)
(function_declarator
  declarator: (template_function
    name: (identifier) @function))

(destructor_name
  (identifier) @function)
(operator_name) @function

(field_initializer
  (field_identifier) @property)

[
  "<=>"
  "->*"
  ".*"
] @operator
