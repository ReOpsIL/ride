# Tutorial: C

Open `samples/c-demo` as the workspace (**File ▸ Open…** or the welcome screen). It is a small C project for member completion through headers, go to definition into `include/`, compile-database diagnostics, and clang-format.

```
include/config.h     macros (DEMO_VERSION, MAX_SHAPES, SQUARE)
include/geometry.h   point_t / rect_t typedefs, struct shape with a union, prototypes
src/util.h           struct buffer and its API (quoted include from main.c)
src/geometry.c       implementations using SQUARE and r->width
src/main.c           uses every header: p.x, s->kind, out.data, MAX_SHAPES
CMakeLists.txt       a static library and the executable
Makefile             targets and variables
build/compile_commands.json   -Iinclude for each source
```

## Highlighting and outline

Open `src/main.c`. The outline lists `shapes`, `shape_count`, `add_point`, `add_rect`, `main`. `include/geometry.h` shows the typedefs, the enum, the struct and the prototypes.

## Member and header completion

In `main`, type `origin.` (fields `x`, `y`), `box.` (`origin`, `width`, `height`) or `s->` inside `add_point` (`kind`, `as`, `label`). The types come from `include/geometry.h` through `#include <geometry.h>` and the `-Iinclude` in the compile database.

Type `rect_` or `buffer_` anywhere; hits from `geometry.h` and `util.h` show with their file.

## Go to definition and diagnostics

`F12` (or ⌘-click) on `rect_area`, `rect_t`, `MAX_SHAPES` (two includes deep, in `config.h`) or `buffer_new`.

Save `src/main.c`, or press `⌘B`, to run `clang -fsyntax-only` with the compile database flags. Add `int unused = 1;` in `main` for a warning, or drop a semicolon for an error, then look at the Problems panel (`⌘6`).

## Format and parse errors

Reformat Document (`⌃⇧I`) runs `clang-format` with the `.clang-format` here. Delete a closing brace and watch the red underline.

`make` builds `build/demo`, `make run` runs it, and `make compile_commands` regenerates the compile database with absolute paths.
