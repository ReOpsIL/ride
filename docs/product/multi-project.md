# Several projects in one folder

A folder such as a course (`lesson01/`, `lesson02/`, … each with its own `Cargo.toml`) holds several independent projects. Ride treats each one as a project of its own.

## Discovery (`src/project/scan.rs`)

- A directory is a project root when it holds `Cargo.toml`, `CMakeLists.txt`, `Makefile`, `GNUmakefile`, `compile_commands.json` or `build/compile_commands.json`.
- The scan walks breadth-first from the opened folder and stops descending at the first root it meets: a project owns its subtree. A Cargo workspace keeps its members, a CMake tree keeps its `add_subdirectory` folders, a recursive Make tree keeps its sub-makefiles.
- Hidden directories, `target`, `node_modules`, `build` and `cmake-build-*` are skipped. Depth is capped at 5 and the walk at 4000 directories.
- When the opened folder is itself a project, it is the only project (the single-project behaviour is unchanged). When nothing is found, the folder itself is returned with kind `None`.
- `Engine::workspace_projects(root)` returns one `ProjectModel` per root, detected in parallel and cached per root; `reload_workspace_projects` rescans and redetects. A root whose detection fails comes back with kind `None` and the error as its notice.

## Active project (`ProjectModelStore`)

- The active project is the one owning the file in the focused editor: the deepest project root that contains the file (`ProjectOwner`).
- It follows the editor. A file outside every project (for example `CURRICULUM.md` at the top) keeps the current active project.
- The Targets panel and the toolbar target menu list only the active project's targets and offer a project switcher when there are two or more projects. The tree's context menu on a project folder has **Set as Active Project** and **Build Project**. The next editor switch overrides a manual choice.

## What runs where

| Action | Directory |
|---|---|
| Build, Run, Run Tests, Debug | the active project's target working directory, else the active project root |
| Check (menu, toolbar, Problems panel) | the active project (clang files still check the file) |
| Check on save, live cargo check, clang-tidy, rustfmt edition | the project owning the saved or edited file |
| Run console links | the working directory of the last run |

Cargo reports span paths relative to the Cargo workspace root of the package it checked, so the engine resolves them against `cargo locate-project --workspace` for the checked directory (cached per directory, cleared on project reload), never against the opened folder. `parse_cargo_line` takes the build's project root for the same reason.

Cargo diagnostics are stored per project root (`DiagnosticStore.cargo[root]`), so checking one lesson no longer wipes the problems of another.

## Project tree

- The tree is rendered from a flat list of visible rows (`FileTreeRows`), one lazy row per node, so any row can be scrolled to.
- When the focused editor's file changes (`AppState.activeFileDidChange`, called from the `paneLayout` observer and after Save As), the tree selects the file, expands its ancestor folders and scrolls it into view. This is the only place the tree selection follows the editor.
- With two or more projects, project folders show a box icon and the active one is set in semibold.
