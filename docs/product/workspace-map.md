# Workspace map

View › Workspace Map (⌘9) draws the open workspace as a nested graph on a canvas. The drawing follows the oneshot agent-graph canvas: positions live in flow space, the viewport pans and zooms, and cards and edges are painted at the final scale so text stays sharp.

Drag empty space to pan. Scroll or pinch to zoom, or use the buttons at the bottom right. The map opens on Kamada–Kawai, which places cards so the distance on screen follows how many steps apart they are in the graph. The other button in the top right switches to Fruchterman–Reingold, which treats each arrow as a spring and spreads the other cards apart. Cards with no link into the main group sit in a block against that group. Click a card to select it. Shift-click adds or removes cards. Drag a selected card to move the whole selection. Double-click a card, or press its chevron, to open the inner graph. The breadcrumb at the top steps back out. The arrow on a card opens that file in the editor and hides the map. The map sits over the editor, so the buffer stays where it was. Refresh reads the workspace again and puts the cards back on the layout.

Cards keep a gap wide enough for an arrow to pass between them. An arrow means one card depends on, or uses, the other. A solid arrow is a Cargo path dependency. A dashed arrow is a Rust `use` of a sibling module.

The graph is read from the tree:

- A Cargo workspace becomes one card per member, with path dependencies between them.
- A crate opens onto its `src/lib.rs`, `src/main.rs`, and `src/bin` entry files, then onto `mod` declarations, including `mod name;` files and inline modules.
- Rust items (`fn`, `struct`, `enum`, `trait`, `impl`, `type`, `const`) sit inside the module that declares them. An `impl` opens onto its functions.
- Folders beside the crate, such as a Swift app or a C tree, are cards of their own. Swift types and C or C++ structs, classes, namespaces, and functions are read from the file.
- `target`, `build`, hidden directories, and Xcode project bundles are skipped.

The read happens off the main thread.

Rust-analyzer and the chat model are not on this path. Module shape is already in the source. A later pass can ask the oracle for call edges, or ask the model when a folder has no recognizable structure. See `todo/app/workspace-map.md`.
