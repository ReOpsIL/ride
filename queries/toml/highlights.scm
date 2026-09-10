(bare_key) @property
(quoted_key) @string

(table (bare_key) @type)
(table (quoted_key) @type)
(table (dotted_key (bare_key) @type))
(table (dotted_key (dotted_key (bare_key) @type)))
(table (dotted_key (dotted_key (dotted_key (bare_key) @type))))

(table_array_element (bare_key) @type)
(table_array_element (quoted_key) @type)
(table_array_element (dotted_key (bare_key) @type))
(table_array_element (dotted_key (dotted_key (bare_key) @type)))

(boolean) @constant
(comment) @comment
(string) @string
(escape_sequence) @escape

[
  (integer)
  (float)
] @number

[
  (offset_date_time)
  (local_date_time)
  (local_date)
  (local_time)
] @constant

[
  "."
  ","
] @punctuation

"=" @operator

[
  "["
  "]"
  "[["
  "]]"
  "{"
  "}"
] @punctuation.bracket
