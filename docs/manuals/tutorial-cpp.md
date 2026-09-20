# Tutorial: C++

Open `samples/cpp-demo` as the workspace (**File ▸ Open…** or the welcome screen). It is a small C++20 project for class members, `::` completion, sniffed headers, and clang-format.

```
include/shapes.hpp   namespace geo: using alias, constexpr, concept, Shape, Circle, Rect, template
include/registry.h   a .h with C++ content (Ride sniffs it and opens it as C++)
src/shapes.cpp       out-of-class definitions using this->
src/registry.cpp     std::map-backed registry
src/main.cpp         circle., found->, geo:: qualifiers, std::vector
CMakeLists.txt       project, option, a function, a static library and the executable
Makefile             targets and variables
build/compile_commands.json   -std=c++20 -Iinclude for each source
```

## Highlighting and outline

Open `include/shapes.hpp`. The outline lists the namespace, the `Real` alias, the concept, both classes with their methods and the template. `src/shapes.cpp` lists every `Circle::…` and `Rect::…` method.

Open `include/registry.h`; the tab and status bar say C++ and the highlighting treats `class` and `namespace` as keywords.

## Member and header completion

In `src/main.cpp`, type `circle.` (own methods and `radius_`, then the `Shape` base members `name`, `describe`, `name_`), `rect.` or `found->`. In `src/shapes.cpp`, type `this->` inside `Circle::scale` to get the `Circle` members even though the method is defined outside the class.

Type `total_` or `Regis` in `main.cpp`; the hits point at `shapes.hpp` and `registry.h`. Qualified names such as `geo::` keep the `geo` qualifier.

## Go to definition and diagnostics

`F12` (or ⌘-click) on `scale_all`, `Circle`, `Registry` or `total_area`.

Save `src/main.cpp`, or press `⌘B`, to run `clang++ -fsyntax-only` with the compile database flags. Remove the `#include <iostream>` line for an error, then look at the Problems panel (`⌘6`).

## Format

Reformat Document (`⌃⇧I`) runs `clang-format` with the `.clang-format` here.

`make` builds `build/demo`, `make run` runs it, and `make compile_commands` regenerates the compile database with absolute paths.
