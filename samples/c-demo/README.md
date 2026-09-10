# c-demo

A small C project for trying Ride's C support. Open this folder as the workspace (`File > Open…` or `scripts/run.sh samples/c-demo`).

```
include/config.h     macros (DEMO_VERSION, MAX_SHAPES, SQUARE)
include/geometry.h   point_t / rect_t typedefs, struct shape with a union, prototypes
src/util.h           struct buffer and its API (quoted include from main.c)
src/geometry.c       implementations using SQUARE and r->width
src/main.c           uses every header: p.x, s->kind, out.data, MAX_SHAPES
build/compile_commands.json   -Iinclude for each source (directory is relative to build/)
```

## What to try

- **Highlighting and outline**: open `src/main.c`; the outline lists `shapes`, `shape_count`, `add_point`, `add_rect`, `main`. `include/geometry.h` shows the typedefs, the enum, the struct and the prototypes.
- **Member completion**: in `main`, type `origin.` (fields `x`, `y`), `box.` (`origin`, `width`, `height`) or `s->` inside `add_point` (`kind`, `as`, `label`). The types come from `include/geometry.h` through `#include <geometry.h>` and the `-Iinclude` in the compile database.
- **Header completion**: type `rect_` or `buffer_` anywhere; hits from `geometry.h` and `util.h` show with their file.
- **Go to definition**: ⌘-click `rect_area`, `rect_t`, `MAX_SHAPES` (two includes deep, in `config.h`) or `buffer_new`.
- **Diagnostics**: save `src/main.c`, or press ⌘B, to run `clang -fsyntax-only` with the compile database flags. Add `int unused = 1;` in `main` for a warning, or drop a semicolon for an error, then look at the Problems panel.
- **Format**: ⌘⇧F runs `clang-format` with the `.clang-format` here (needs `clang-format` on PATH).
- **Parse errors**: delete a closing brace and watch the red underline.

`make` builds `build/demo`, `make run` runs it and `make compile_commands` regenerates the compile database with absolute paths.
