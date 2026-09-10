# cpp-demo

A small C++20 project for trying Ride's C++ support. Open this folder as the workspace (`File > Open…` or `scripts/run.sh samples/cpp-demo`).

```
include/shapes.hpp   namespace geo: using alias, constexpr, concept, Shape base class, Circle and Rect, template function
include/registry.h   a .h with C++ content (Ride sniffs it and opens it as C++)
src/shapes.cpp       out-of-class definitions using this->
src/registry.cpp     std::map-backed registry
src/main.cpp         circle., found->, geo:: qualifiers, std::vector
build/compile_commands.json   -std=c++20 -Iinclude for each source (directory is relative to build/)
```

## What to try

- **Highlighting and outline**: open `include/shapes.hpp`; the outline lists the namespace, the `Real` alias, the concept, both classes with their methods and the template. `src/shapes.cpp` lists every `Circle::…` and `Rect::…` method.
- **Member completion**: in `main.cpp`, type `circle.` (own methods and `radius_`, then the `Shape` base members `name`, `describe`, `name_`), `rect.` or `found->`. In `src/shapes.cpp`, type `this->` inside `Circle::scale` to get the `Circle` members even though the method is defined outside the class.
- **Header completion**: type `total_` or `Regis` in `main.cpp`; the hits point at `shapes.hpp` and `registry.h`.
- **Go to definition**: ⌘-click `scale_all`, `Circle`, `Registry` or `total_area`. Qualified names such as `geo::total_area` keep the `geo` qualifier.
- **Sniffed header**: open `include/registry.h`; the tab and status bar say C++ and the highlighting treats `class` and `namespace` as keywords.
- **Diagnostics**: save `src/main.cpp`, or press ⌘B, to run `clang++ -fsyntax-only` with the compile database flags. Remove the `#include <iostream>` line for an error.
- **Format**: ⌘⇧F runs `clang-format` with the `.clang-format` here (needs `clang-format` on PATH).

`make` builds `build/demo`, `make run` runs it and `make compile_commands` regenerates the compile database with absolute paths.
