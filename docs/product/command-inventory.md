# Ride: command and option inventory

This is a snapshot of the working tree on 2026-09-27 (branch `main`, uncommitted changes included). It comes from static analysis only: every handler was traced through the source, and nothing was built or run.

**Coverage since this snapshot.** Main-menu coverage is now enforced at runtime. The self-test step `menu coverage` (`app/Ride/Debug/SelfTestMenuCoverage.swift`) walks the live menu bar at the end of every suite. It fails when an item is neither claimed by a passing step (registry: `SelfTestCoverage+FileEdit.swift`, `+Code.swift`, `+Run.swift`, `+Git.swift`) nor exempt with a reason (system-injected items only). Steps press the real `NSMenuItem` through `SelfTestMenu.perform`. `menu-coverage.txt` beside each self-test report is the current per-item list. The Coverage column in the tables below shows the state before that round; open gaps are in `todo/app/remaining.md` under "Menu coverage follow-ups".

**Legend**
- **Coverage classes:**
  - `SELFTEST`: an in-app self-test step in `SelfTestSteps*.swift`, reachable from `SelfTestSteps.all`, calls the handler or its underlying method and checks the effect.
  - `UNIT`: an XCTest in `app/RideTests` exercises the command's logic.
  - `RUST`: a test in `tests/*.rs` covers the engine behaviour behind the command. RUST is counted under UNIT in the totals.
  - `NONE`: no test exercises the command.
- `demo: "<scene>"` marks a DemoScene screenshot scene. These scenes have no assertions, so they are not counted as coverage.
- ⚠ marks one of these problems: the behaviour does not match the title, the handler is broken, dead or duplicated, or the shortcut conflicts with another.
- Global caveats:
  - Live-debug self-test steps run only in developer mode.
  - In demo mode, every `Confirm.ask`, `confirmClose` and breakpoint-editor dialog answers itself. No dialog button is exercised by the self-test.

**Contents**
1. App menu, Help, File, Edit, and their sheets
2. View and Navigate, with the overlays, Hierarchy, Usages, Outline, Preview, and Rename/Safe Delete
3. Code and Build, with the Generate/Surround/Intention popups, Cheat Sheet, Completion, Docs/Peek, AI and Install Tools
4. Run and Debug, with Run output, Run config, Tests, Debug panel, Evaluate, breakpoints, Terminal, Toolbar and Targets; then the Git menu and the Changes panel
5. Editor keyboard and mouse, gutter, tabs, splits, status bar, notices, Welcome, confirm dialogs, and external entry points
6. Project sidebar and tree, Problems, Find bar, Find/Replace in Project, and other controls
7. Preferences
8. Summary: counts, cross-cutting issues, NONE list, ⚠ list

---

## App menu, Help, File, Edit (+ their sheets)

### App menu and Help (RideApp.swift)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Ride › About Ride` | — | `AboutPanel.show()` → Design/AboutPanel.swift | Opens the standard AppKit About panel with the bundle version/build and a credits line "Engine 0.1.0 · tree-sitter · Tantivy". | NONE | ⚠ `AboutPanel.engineVersion` is a hard-coded "0.1.0" (Cargo.toml says 1.0.0) and is also the fallback app version; not read from the engine. tests/version.rs checks Cargo against the marketing version, not this constant. |
| `Ride › Check for Updates…` | — | `updater.checkForUpdates()` → UpdateController.swift / UpdateController+Sparkle.swift | Calls Sparkle `SPUStandardUpdaterController.checkForUpdates`. The item only exists when Info.plist `SUPublicEDKey` is set and is not the placeholder. | UNIT: UpdateControllerTests.testPlaceholderKeyIsNotConfigured, .testEmptyKeyIsNotConfigured, .testOtherKeyIsConfigured | Hidden in builds without a real key. Tests cover only the "is configured" gate. |
| `Ride › Quit Ride` (system) | ⌘Q | `RideAppDelegate.applicationShouldTerminate` → `state.confirmQuit()` (AppState+Workspace.swift) | For each dirty buffer: makes it active and asks Save / Don't Save / Cancel (`confirmClose`). Any Cancel returns `.terminateCancel`. No state means quit right away. | NONE | In demo mode `confirmClose` returns true, so nothing is asked. Buffers saved before a later Cancel stay saved. |
| `Help › Keyboard Shortcuts` | ⌘? | `ShortcutsPanel.show()` → Design/ShortcutsPanel.swift | Opens (or brings back) one utility NSPanel that shows `Shortcuts.entries` as key caps in three columns (ShortcutsView). | UNIT: ShortcutsManualTests.testCommittedManualMatchesEntries | ⚠ The list is hand-written and incomplete. In this scope it lacks New Project ⇧⌘N, Move Statement ⇧⌘↑/↓, Copy Reference ⌥⇧⌘C, Use Selection for Find ⌥⌘E and Replace in Project ⇧⌘H. The test compares entries to the committed manual, not to the menus. ⚠ The panel's appearance and background are set once, when it is first created, so a later theme change leaves them stale. Replaces the default Help group (no Ride Help item). |

Keyboard Shortcuts panel: no Ride controls, only the title-bar close box. About panel: standard AppKit panel, no Ride controls.

### File menu (Menus/FileCommands.swift)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `File › New Project…` | ⇧⌘N | `state.newProject()` → Project/AppState+NewProject.swift | Sets `showNewProjectSheet = true`. RootView then shows `NewProjectSheet` (controls in the table below). | UNIT: ProjectScaffoldTests.testRustBinaryScaffold, .testWriteCreatesTreeAndRefusesExistingFolder, .testNameValidation +4 more | Always enabled. |
| `File › New File…` | ⌘N | `state.newFile()` → Editor/Buffers+File.swift | NSSavePanel in the selected tree folder (or the workspace root) with "untitled.rs" and a SaveLanguagePicker accessory. Creates an empty file if missing, then `fileCreated`: `engine.workspaceFileChanged`, reload tree, open it. Disabled when `!hasWorkspace` (no workspace root). | UNIT: NewFilePromptTests.testLanguageListMatchesTheSavePanel | ⚠ Always defaults to Rust / `.rs`, whatever the project kind. The tree's New File prompt uses `NewFilePrompt.language(for:)` instead, so there are two New File flows that behave differently. ⚠ If the user picks an existing file and confirms the panel's "Replace", the file is only opened; its contents are kept. |
| `File › New Buffer` | ⌥⌘N | `state.newUntitled()` → Editor/Buffers.swift | Appends an untitled `BufferDocument` (sequence number) and makes it active. | NONE | Always enabled. |
| `File › New Folder…` | — | `state.newFolder()` → Buffers+File.swift → `TreeActions.newFolder(in:)` | Asks for a name in an NSAlert ("untitled"), creates the folder under the selected tree folder (or the root), then reloads the tree. Disabled when `!hasWorkspace`. | NONE | ⚠ `createDirectory` runs with `try?`, so failures (name exists, bad name) are silent. |
| `File › Open…` | ⌘O | `state.openAnything()` → Buffers+File.swift | NSOpenPanel for a file or folder. A folder becomes the workspace through `open(_:)`. A file outside the workspace first opens its parent folder as the workspace (closing all buffers), then opens the file. | NONE | Always enabled. Opening one outside file replaces the whole workspace. |
| `File › Open Recent › <folder name>` (dynamic) | — | `state.open(url)` → AppState+Workspace.swift | Lists `menu.recent` (up to 12 recent workspace roots, from `RecentProjects`, mirrored by `AppState.recent.didSet`). Picking one flushes the workspace, closes all buffers (asks about dirty ones), stops the run and terminals, sets the root, `RideEngineClient.openWorkspace` (engine `openWorkspace` plus the indexer), loads the project model and git, and restores the saved layout. The submenu is hidden when the list is empty. | SELFTEST: "sample project reopen" (rust) | ⚠ Titles are `lastPathComponent` only, so two folders with the same name look identical. There is no "Clear Menu". Missing folders are dropped only when the list loads at launch. |
| `File › Close Workspace` | — | `state.closeWorkspace()` → Buffers+File.swift | Flushes the workspace state, closes all buffers (can be cancelled), clears root, tree, selection, quick files, git and project model. Disabled when `!hasWorkspace`. | NONE | ⚠ Never calls `RideEngineClient.closeWorkspace()` (defined in Engine/RideEngineClient.swift:71 but never called) and never calls `watcher.stop()`. The engine workspace and the FSEvents watcher of the old root stay alive. Run and terminals stop only through the `$workspaceRoot` observers. |
| `File › Save` | ⌘S | `state.saveActive()` → `save(_:)` (Editor/Buffers.swift) | Asks about disk changes (`confirmOverwrite`). Untitled or read-only buffers get the Save panel and a rebind. Then `persist`: `BufferDocument.save` with the line-ending policy, then `didSave` (usage index, format-on-save, check-on-save). Disabled when `!hasEditor` (no active buffer). | UNIT: LineEndingsTests.testKeepWritesCRLFWhenTheBufferLoadedCRLF, .testLFPolicyWritesLFAndClearsTheCRLFFlag, .testCRLFBufferRoundTripsWithoutDoubledCarriageReturns +3 more | Tests cover only the line-ending encoding inside `save`. |
| `File › Save As…` | ⇧⌘S | `state.saveAs()` → Buffers+File.swift | `chooseSaveURL` (NSSavePanel with the SaveLanguagePicker), then `rebind` (new URL, re-detect language, reattach the engine session if the language changed), then `persist`. Disabled when `!hasEditor`. | NONE | Skips `confirmOverwrite`, unlike Save. |
| `File › Save All` | ⌥⌘S | `state.saveAll()` → Buffers+File.swift | Persists every dirty buffer that has a file and is not read-only, with `allowFormat: false`. Disabled when `!hasEditor`. | SELFTEST: "save all" (rust) | ⚠ Untitled buffers are skipped silently, and format-on-save is off here (Save runs it). Also used as setup in the Run, Breakpoint and CppDebug steps. demo: "problems". |
| `File › Revert to Saved` | — | `state.revertToSaved()` → Buffers+File.swift | For a buffer with a file: asks first if dirty, then `reloadFromDisk` (replace text, `markLoaded`). Disabled when `!hasEditor`. | NONE | ⚠ Enabled for untitled buffers, where it does nothing (`fileURL == nil` guard). |
| `File › Close Editor` | ⌘W | `state.closeFrontmost()` → AppState+Workspace.swift | If the key window is not the main window (Settings, Shortcuts panel…), closes that window. Otherwise closes the active buffer (asks if dirty). | NONE | Never disabled. With no buffer in the main window it does nothing and does not close the window. |
| `File › Close All` | ⌥⌘W | `state.closeAll()` → Buffers+File.swift | Asks about each dirty buffer (Cancel stops). Closes every session, clears buffers and history, and resets pane and split layout. Disabled when `!hasEditor`. | NONE | Also runs inside `open(_:)` and `closeWorkspace()`. |
| `File › Close Others` | — | `state.closeOthers()` → Buffers+File.swift | Closes every buffer except the active one, asking about dirty ones one by one. Disabled when `!hasEditor`. | NONE | |
| `File › Reindex` | — | `state.reindex()` → AppState+Tree.swift → `IndexerProcess.run(force: true)` | Starts the bundled `Contents/Helpers/ride-engine … index --force` process on the workspace root, output sent to /dev/null. Disabled when `!hasWorkspace`. | UNIT: RUST tests/index_runs.rs::incremental_reindex_shares_segment_files_with_the_previous_generation, ::concurrent_runs_on_one_index_dir_both_succeed | ⚠ Nothing waits on the process. If the helper is missing or fails, nothing happens and the user sees nothing. No test covers `--force`. |

### New Project sheet (Project/NewProjectSheet.swift)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `New Project › Name` (TextField) | — | `$name` | Project name. Typing clears the error. The preview line shows the validation message or `<location>/<name>/<mainFile>`. | UNIT: ProjectScaffoldTests.testNameValidation | |
| `New Project › Language` (segmented Picker) | — | `$language` | Rust / C / C++. On change, switches the build system to the first one valid for the language. | UNIT: ProjectScaffoldTests.testLanguagesOfferMatchingBuildSystems | |
| `New Project › Build` (segmented Picker) | — | `$buildSystem` | Cargo for Rust; CMake or Make for C/C++. Disabled when only one option (Rust). | UNIT: ProjectScaffoldTests.testLanguagesOfferMatchingBuildSystems, .testCMakeScaffoldUsesTargetNameAndExportsCompileCommands, .testMakeScaffoldRecipesUseTabs | |
| `New Project › Kind` (segmented Picker, Rust only) | — | `$library` | Binary or Library. Library uses `src/lib.rs` as the main file. | UNIT: ProjectScaffoldTests.testRustLibraryScaffold, .testRustBinaryScaffold | The `library` flag stays set after switching to C/C++, but it has no effect there. |
| `New Project › Location › Choose…` | — | `chooseLocation()` | NSOpenPanel (folders, can create) to pick the parent folder. Default is `~/develop` if it exists, else `~`. | NONE | |
| `New Project › Cancel` | Esc | `state.showNewProjectSheet = false` | Closes the sheet. | NONE | |
| `New Project › Create` | ↩ | `create()` → `state.createProject(_:in:)` | Validates, writes the scaffold (`ProjectScaffold.write`, which refuses an existing folder), closes the sheet, opens the new root as the workspace and opens the main file. Errors show in the sheet. Disabled while the name is invalid. | UNIT: ProjectScaffoldTests.testWriteCreatesTreeAndRefusesExistingFolder, .testRustBinaryScaffold | ⚠ The validation branch inside `create()` can never run, because the button (and ↩) is disabled by the same check. |

### New File prompt (tree/sidebar "New File" → Workspace/TreeActions.swift `newFile` + `LanguageNameField` in Editor/SaveLanguagePicker.swift; defaults from Workspace/NewFilePrompt.swift)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `New File prompt › Language:` (popup) | — | `LanguageNameField.changed()` | Lists `NewFilePrompt.languages` (Rust, C, C++, TOML, Make, CMake, Markdown). The default follows the project kind (CMake→C++, Make→C, else Rust). Changing it rewrites the name's extension. | UNIT: NewFilePromptTests.testDefaultLanguageFollowsProjectKind, .testUntitledNameUsesTheLanguageExtension | Opened from the tree/sidebar, not from the File menu (see the New File… ⚠). |
| `New File prompt › name field` | — | `picker.field` | File name, prefilled `untitled.<ext>`. | UNIT: NewFilePromptTests.testUntitledNameUsesTheLanguageExtension | |
| `New File prompt › OK` | ↩ | `TreeActions.newFile` | Trims the name, creates an empty file in the folder if missing, and returns the URL for the caller to open. | NONE | An existing name just returns that file, with no warning. |
| `New File prompt › Cancel` | Esc | NSAlert | Returns nil. | NONE | |

### Save panel language picker (Editor/SaveLanguagePicker.swift, used by File › New File… and Save/Save As…)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Save panel › Language:` (popup accessory) | — | `SaveLanguagePicker.changed()` | Same 7 languages. Changing it replaces the extension in the panel's name field. | UNIT: NewFilePromptTests.testLanguageListMatchesTheSavePanel | ⚠ A buffer language not in the list (JSON, plain text, …) preselects Rust (index 0) while the name keeps its real extension, so the popup and the file name disagree. |
| `Save panel › Save / Cancel` (system) | ↩ / Esc | NSSavePanel `runModal` | Save returns the URL to `newFile` (create and open) or to `chooseSaveURL` (rebind and persist). Cancel does nothing. | NONE | |

### Edit menu, group 1 (Menus/EditCommands.swift, `CommandGroup(after: .pasteboard)`)

All `EditorCommands.*` go through `EditorCommands.target()`. It needs the focused `RideTextView` to be first responder and editable, otherwise the command does nothing. None of these items is ever `.disabled`.

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Edit › Duplicate Line` | ⌘D | `EditorCommands.duplicate()` → `LineOps.duplicate` | Duplicates the caret line, or the selection. | SELFTEST: "duplicate line" (rust, c, cpp); UNIT: LineOpsTests.testDuplicateLinesAndSelections | |
| `Edit › Delete Line` | ⌘⌫ | `EditorCommands.deleteLines()` → `LineOps.deleteLines` | Deletes the touched lines and keeps the column. | SELFTEST: "delete line" (rust, c, cpp); UNIT: LineOpsTests.testDeleteLinesKeepsTheColumn | ⚠ Replaces the standard ⌘⌫ (delete to line start). In the file tree (TreeKeyView treats keyCode 51 as trash whatever the modifiers) and in text fields, the menu takes ⌘⌫ and does nothing. |
| `Edit › Join Lines` | ⌃⇧J | `EditorCommands.joinLines()` → `LineOps.joinLines` | Joins the next line onto this one and collapses the whitespace between them. | SELFTEST: "join lines", "undo join" (rust); UNIT: LineOpsTests.testJoinLinesCollapsesWhitespace | |
| `Edit › Move Line Up` | ⌥⇧↑ | `EditorCommands.moveLines(up: true)` | Swaps the touched lines with the line above. | SELFTEST: "move line up" (rust, c, cpp); UNIT: LineOpsTests.testMoveLinesUpAndDown, .testMoveLinesStopsAtTheEdges | Replaces the standard select-to-paragraph-start. |
| `Edit › Move Line Down` | ⌥⇧↓ | `EditorCommands.moveLines(up: false)` | Swaps the touched lines with the line below. | SELFTEST: "move line down" (rust, c, cpp); UNIT: LineOpsTests.testMoveLinesUpAndDown, .testMoveLinesStopsAtTheEdges | |
| `Edit › Move Statement Up` | ⇧⌘↑ | `EditorCommands.moveStatement(up: true)` → engine `statementBounds` | Asks the engine session for the statement bounds around the caret and swaps with the previous statement (`LineOps.moveStatement`). | SELFTEST: "move statement up" (rust, cpp); UNIT: LineOpsTests.testMoveStatementSwapsGivenRanges; RUST: tests/editing.rs::statement_bounds_siblings_skip_comments_and_stop_at_edges, ::rust_statement_bounds_covers_each_kind | ⚠ Enabled for every language, but the engine returns none outside Rust/C/C++ (`statement_bounds_none_for_other_languages`), so it does nothing silently. ⚠ Replaces the standard ⇧⌘↑ (select to document start). |
| `Edit › Move Statement Down` | ⇧⌘↓ | `EditorCommands.moveStatement(up: false)` | Same, with the next statement. | SELFTEST: "move statement down" (rust, cpp); UNIT: LineOpsTests.testMoveStatementKeepsWhenRangesCannotSwap; RUST: tests/editing.rs::c_and_cpp_statement_bounds_covers_each_kind | ⚠ Same as above (replaces select to document end). |
| `Edit › Start New Line` | ⇧↩ | `EditorCommands.newLine(before: false)` → `LineOps.newLineAfter` | Opens an indented line below, wherever the caret is in the line. | SELFTEST: "new line after" (rust), "complete statement prep" (cpp); UNIT: LineOpsTests.testNewLineAfterAndBefore | demo: live-diagnose scene (`typeTypo`). ⇧↩ is taken in every text field (find bar, go-to-line, terminal) and does nothing there. |
| `Edit › Start New Line Before` | ⌥⌘↩ | `EditorCommands.newLine(before: true)` → `LineOps.newLineBefore` | Opens an indented line above. | SELFTEST: "new line before" (rust); UNIT: LineOpsTests.testNewLineAfterAndBefore | |
| `Edit › Toggle Case` | ⇧⌘U | `EditorCommands.toggleCase()` → `LineOps.toggleCase` | Cycles the word or selection lower → UPPER → lower. | SELFTEST: "toggle case", "toggle case back" (rust); UNIT: LineOpsTests.testToggleCaseCyclesLowerUpperLower | |
| `Edit › Sort Lines` | — | `EditorCommands.sortLines()` → `LineOps.sortLines` | Sorts the selected lines. | SELFTEST: "sort lines", "undo sort" (rust); UNIT: LineOpsTests.testSortLines | |
| `Edit › Select Line` | ⇧⌘L | `EditorCommands.selectLine()` | Selects the full line(s), trailing newline included. | SELFTEST: "select line" (rust) | ⚠ Does nothing on read-only buffers (the `isEditable` guard in `target()`), even though it changes no text. |
| `Edit › Select Word` | ⌃W | `EditorCommands.selectWord()` → `IdentifierRange.at` | Selects the identifier under the caret. | SELFTEST: "select word", "surround" (rust); UNIT: NavigationTests.testIdentifierRangeUnderCursor | ⚠ ⌃W is a global key equivalent. SwiftTerm's Mac view has no `performKeyEquivalent`, so in the terminal panel the menu takes ⌃W (the shell's delete-word) and does nothing. Also does nothing on read-only buffers. |
| `Edit › Extend Selection` | ⌥↑ | `EditorCommands.extendSelection()` → engine `enclosingRanges` | Pushes the current selection onto `selectionStack` and selects the next enclosing syntax node. | SELFTEST: "extend selection" (rust); RUST: tests/editing.rs::rust_enclosing_grows_from_word_through_string_block_and_fn, ::other_languages_enclose_by_node, ::c_enclosing_includes_compound_statement_inside | Replaces the standard ⌥↑ (paragraph move). Does nothing on read-only buffers. |
| `Edit › Shrink Selection` | ⌥↓ | `EditorCommands.shrinkSelection()` | Pops `selectionStack` and restores the previous selection. | SELFTEST: "shrink selection" (rust) | Replaces the standard ⌥↓. Does nothing on read-only buffers. |
| `Edit › Copy Reference` | ⌥⇧⌘C | `state.copyReference()` → Navigate/AppState+Jumps.swift | Copies `relative/path:line` (absolute path outside the workspace, display name when untitled) and shows a 2 s notice. Needs an active buffer. | SELFTEST: "copy reference" (rust) | Line only, no column. |

### Edit menu, Find group (second `CommandGroup(after: .pasteboard)`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Edit › Find…` | ⌘F | `state.toggleFind()` → Search/SearchActions.swift | Hides Quick Open and toggles the editor find bar (`showFind`). When opening, sets `findOrigin` to the caret and hides the replace field. | NONE | ⚠ Toggles: ⌘F while the bar is open closes it instead of focusing it. Does not close the other overlays (only Quick Open). demo: "findbar". |
| `Edit › Find and Replace…` | ⌥⌘F | `state.toggleFind(replace: true)` | Opens the find bar with the replace field. If the bar is open without replace, only shows the replace field. If it is already open with replace, closes it. | NONE | |
| `Edit › Find Next` | ⌘G | `state.findNext()` → `find(backwards: false)` → `FindMatcher.next` | Selects the next match of `findQuery` from `findOrigin`, wrapping around. Needs a focused editor and a non-empty query. | SELFTEST: "find next" (rust); UNIT: FindMatcherTests.testNextWrapsAround | Works with the bar hidden if a query is left over. demo: "findbar". |
| `Edit › Find Previous` | ⇧⌘G | `state.findPrevious()` → `find(backwards: true)` | Selects the previous match, from the current match's start. | UNIT: FindMatcherTests.testNextWrapsAround | |
| `Edit › Use Selection for Find` | ⌥⌘E | `state.useSelectionForFind()` | Sets `findQuery` to the selected text and moves `findOrigin` to the selection's end. Does nothing with an empty selection. | NONE | ⚠ Does not open the find bar. plan/roadmap/must_have.md asks for ⌘E, which Navigate › Recent Files already uses. |
| `Edit › Find in Project…` | ⇧⌘F | `state.toggleProjectFind()` → AppState+Nav.swift | `closeOverlays()`, then toggles `showProjectFind` (ProjectFindView: search field, replace row, preview). | NONE | Only the toggle; the panel's search and replace are tested in ProjectFindTests and ProjectReplaceTests. demo: "find". |
| `Edit › Replace in Project…` | ⇧⌘H | `state.toggleProjectFind()` | Same handler as Find in Project. | NONE | ⚠ Same handler as Find in Project, so nothing puts focus on the replace field. ⇧⌘H while the panel is open closes it. |

### System Edit items that Ride overrides (Editor/RideTextView+Undo.swift, +Clipboard.swift, RideTextView.swift)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Edit › Undo` (system) | ⌘Z | `RideTextView.undo(_:)` → `undoSteps.manager.undo()` | Undoes through the buffer's own `BufferUndo` manager (the view's `undoManager` returns nil). Enabled from `manager.canUndo`. | SELFTEST: "undo is one step" (rust, c, cpp), "undo join", "undo sort" (rust); UNIT: UndoStepTests.testEachPerformIsOneUndoStep, BufferTextUndoTests.testUndoRestoresPreviousText +more | The menu title has no action name ("Undo Typing" and similar never show). |
| `Edit › Redo` (system) | ⇧⌘Z | `RideTextView.redo(_:)` → `undoSteps.manager.redo()` | Redoes through the same manager. Enabled from `manager.canRedo`. | UNIT: BufferTextUndoTests.testRedoReappliesText, UndoStepTests.testCloseKeepsTheRedoGroupWhileUndoing | No selftest calls `redo`. |
| `Edit › Cut` (system) | ⌘X | `RideTextView.cut(_:)` | With a selection: standard cut. With none: copies the whole line (newline included) and deletes it. | NONE | |
| `Edit › Copy` (system) | ⌘C | `RideTextView.copy(_:)` | With a selection: standard copy. With none: copies the whole caret line, newline included. | NONE | Paste does not know the text came from a whole-line copy, so it lands mid-line at the caret instead of above the line. |
| `Edit › Paste` / `Paste and Match Style` (system) | ⌘V / ⌥⇧⌘V | `RideTextView.paste(_:)`, `pasteAsRichText(_:)` → `pasteAsPlainText` | Always pastes plain text. | NONE | |
| `Edit › Select All` (system) | ⌘A | NSTextView default | Not overridden. | n/a (system, not counted) | |


---

## View & Navigate menus, their overlays and panels

Sources: `Menus/ViewCommands.swift`, `Menus/NavigateCommands.swift`, `Search/QuickOpen.swift`, `Search/SearchActions.swift`, `Navigate/*`, `Search/SymbolPicker*.swift`, `Outline/*`, `Design/PickerCard.swift`, `Design/PickerRow.swift`, `Design/OverlayCard.swift`, `Hierarchy/*`, `Usages/*`, `Preview/*`, `Rename/*`.
`Design/OverlayPanel.swift` is only an `NSPanel` factory used by completion, signature help, hover, doc, peek and cheat sheet popups. It is borderless, non-activating, floating and hides on app deactivate (except in demo mode). It has no key handling, so it has no rows here; the popup keys live in `Editor/RideTextView+Keys.swift`.
The SwiftUI pickers (Quick Open, Recent Files, Go to Line, both Symbol pickers) all render through `PickerCard` inside `RootView.overlay`.

### View menu

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| View › Project Sidebar | ⌘1 | `state.showSidebar.toggle()` (inline) | Shows or hides the left sidebar. The state is saved per workspace. | NONE | Checkmark comes from `menu.showSidebar`. The toolbar sidebar button does the same thing. |
| View › Outline | ⌘7 | `toggleOutlinePanel()` → `AppState+View.swift` | Flips `prefs.outlinePanel` through `updatePrefs`, which saves prefs and layout. This shows or hides `FileOutlineView` on the right of the editor row. | NONE | Settings › "Outline panel" does the same. demo: "outline" |
| View › Problems | ⌘6 | `toggleProblems()` → `AppState+Check.swift` | Toggles the bottom Problems panel. | NONE | The panel also opens itself on errors (`checkFinished`). Self-test steps ("type at end", live steps) set `showProblems` directly and never assert the toggle. |
| View › Run Output | ⌘4 | `toggleRunOutput()` → `Run/AppState+RunOutput.swift` | Toggles the Run Output panel. | NONE | "run output close" sets the flag directly and does not assert it. |
| View › Tests | ⌘5 | `toggleTests()` → `Tests/AppState+Tests.swift` | Toggles the Tests panel. | NONE | |
| View › Usages | — | `toggleUsages()` → `Usages/AppState+Usages.swift` | Toggles the Usages panel, which shows the last Find Usages result. | NONE | No shortcut. "find usages" opens the panel through `findUsages()`, not through this toggle. |
| View › AI Chat | ⌘8 | `AIAssistant.shared.showPanel.toggle()` | Shows or hides the AI chat side panel. `onPanelChange` keeps the menu checkmark in sync. | SELFTEST: "menu ai toggle", "menu ai restore" | |
| View › Terminal | ⌥F12 | `toggleTerminal()` → `Terminal/AppState+Terminal.swift` | Toggles the terminal panel. On show it opens a tab in the workspace root if none exist, otherwise it focuses the selected tab. Hiding leaves the sessions running. | SELFTEST: "terminal open" (rust; calls `openTerminal`, the no-tabs branch) | The hide path and the focus-existing path are untested. |
| View › Toggle Markdown Preview | ⇧⌘V | `togglePreview()` → `AppState+Preview.swift` | Flips `showPreview`. When visible it renders the active buffer through engine `renderMarkdown` into `PreviewPane`. Disabled unless the active buffer is Markdown (`previewAvailable`). | RUST: tests/markdown.rs::renders_tables_task_lists_and_line_anchors, rust_fences_are_highlighted_in_html | ⚠ This is a `Button`, not a `Toggle`, so it gets no checkmark, unlike the other panel items. `showPreview` persists across buffers: it hides for non-md files and comes back on md. demo: "preview" |
| View › Zoom In | ⌘= | `zoom(1)` → `AppState+View.swift` | Adds 1 to `prefs.fontSize`, clamped to 10…24. | SELFTEST: "zoom" (rust, c, cpp) | |
| View › Zoom Out | ⌘- | `zoom(-1)` | Subtracts 1 from the font size, with the same clamp. | NONE | Only `zoom(+1)` is exercised. |
| View › Actual Size | ⌃⌘0 | `resetZoom()` | Resets the font size to `Preferences.defaults.fontSize`. | SELFTEST: "zoom reset" (rust, c, cpp) | |
| View › Line Numbers | — | `toggleLineNumbers()` | Flips `prefs.lineNumbers`. The gutter hides the number column and narrows. | SELFTEST: "line numbers hidden", "line numbers shown" (rust `gutterSteps`) | The steps set `state.prefs.lineNumbers` directly, bypassing the toggle and `updatePrefs` persistence. |
| View › Soft Wrap | — | `toggleSoftWrap()` | Flips `prefs.softWrap`. | NONE | |
| View › Show Whitespace | — | `toggleWhitespace()` | Flips `prefs.visibleWhitespace`. | NONE | |
| View › Indent Guides | — | `toggleIndentGuides()` | Flips `prefs.indentGuides`. | NONE | |
| View › Code Vision | — | `toggleCodeVision()` | Flips `prefs.codeVision`, which controls the inline usage-count labels. | NONE | "code vision" tests the labels, not the toggle. demo: "codevision" |
| View › Open in Split | — | `openInSplit()` → `AppState+Panes.swift` | If there is no split, it opens a right pane and moves the active tab into it. If already split, it moves the active tab to the other pane. Disabled `!hasEditor`. | SELFTEST: "split header source" (rust; `openInSplit(other.id)` with an explicit id); UNIT: PaneLayoutTests.testMoveTakesTabToOtherPane, PaneLayoutTests.testOpenRemovesTabFromOtherPanes | It moves the tab rather than duplicating it, so the source pane can end up empty. demo: "split" |
| View › Toggle Split | ⌘\ | `toggleSplit()` | If split, calls `closeSplit()`. Otherwise `openSplit()` adds an empty, focused right pane. Disabled only when there is no editor and no split. | UNIT: SplitLayoutTests.testToggleOpensHorizontalThenReturnsToSingle, PaneLayoutTests.testClosePaneKeepsLastPane | "split header source" calls it only in a fallback branch that the rust fixture doesn't reach, because other buffers are open. |
| View › Close Split | — | `closeSplit()` | Closes `panes[1]` whichever pane is focused, merges its tabs into the left pane and refocuses the editor. Disabled `!hasSplit`. | SELFTEST: "breakpoint shift settle" (rust; asserts 1 pane); UNIT: PaneLayoutTests.testClosePaneMergesTabsIntoNeighbour, SplitLayoutTests.testCloseRightPaneFocusesLeft | Also called as cleanup in "move statement open". |

### Navigate menu

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Navigate › Open Quickly… | ⌘P | `toggleQuickOpen()` → `Search/SearchActions.swift` | Toggles the Quick Open overlay. The file list loads off the main thread (`FileIndex.list`, honours `showHidden`) and is fuzzy-matched with `FileIndex.matches`. The item is never disabled. | NONE | ⚠ Only hides Find. It does not call `closeOverlays()`, so it stacks on top of Go to Line, Recent Files or the Symbol pickers (two cards, two backdrops). ⚠ Enabled with no workspace, while the toolbar button is disabled then. The overlay then stays empty ("Type a file name" / "No matching files"). demo: "quickopen" |
| Navigate › Recent Files… | ⌘E | `toggleRecentFiles()` → `Navigate/AppState+Navigate.swift` | Toggles a picker over the session's recent files (max 30, newest first). The 2nd entry, the previous file, is preselected. | NONE | The "recent files" step only checks the list filled by `noteOpened`; it never opens the picker. The list is not persisted and not scoped to the workspace. ⌘E replaces the macOS convention "Use Selection for Find", which is on ⌥⌘E here. |
| Navigate › Back | ⌘[ | `goBack()` | Steps `NavigationHistory` back from the current caret. It switches buffer if needed and forgets closed buffers. Disabled `!canGoBack`. | SELFTEST: "back" (rust, c, cpp); UNIT: NavigationHistoryTests.testBackAndForwardWalkTheRing, NavigationHistoryTests.testSameLineReplacesInsteadOfAppending, NavigationHistoryTests.testNewRecordDropsForwardEntriesAndForgetRemovesBuffer | |
| Navigate › Forward | ⌘] | `goForward()` | Steps history forward. Disabled `!canGoForward`. | SELFTEST: "forward" (rust, c, cpp); UNIT: NavigationHistoryTests.testBackAndForwardWalkTheRing | |
| Navigate › Last Edit Location | ⇧⌘⌫ | `goToLastEdit()` | Records the current location, then jumps to `history.lastEdit` (set by `noteEdit`). | NONE | Never disabled. Does nothing if nothing was edited, although Back and Forward next to it are gated. |
| Navigate › Go to Line… | ⌘L | `toggleGoToLine()` | Toggles the "line or line:column" overlay. Return runs `confirmGoToLine`, which clamps the line to 1…count and the column to the line end, records the location and focuses the editor. Disabled `!hasEditor`. | SELFTEST: "go to line" (rust, c, cpp; sets the query and calls `confirmGoToLine` directly) | The toggle and overlay are not exercised. |
| Navigate › Go to Symbol in File… | ⌥⌘O | `toggleSymbolInFile()` → `AppState+Nav.swift` | Opens a picker over the active buffer's outline: the first 60 rows, filtered by substring on name or kind. Return jumps to the item. | NONE | ⚠ The toggle is broken. `closeOverlays()` sets `showSymbolInFile=false`, then `.toggle()` sets it true, so ⌥⌘O never closes the picker. The other toggles capture `next` first. The outline data is engine-tested (tests/outline_docs.rs), the picker is not. |
| Navigate › Go to Symbol in Project… | ⇧⌥⌘O | `toggleSymbolPicker()` | Toggles a picker backed by engine `queryCompletions` (items mode, limit 50, 50 ms debounce, keywords removed). It accepts `fn:`/`struct:`… prefixes, parsed in `src/query/parse.rs`. Return runs `HitNavigation.open`, which opens the file, read-only outside the workspace. | RUST: tests/query.rs::rustdoc_kind_filter, tests/query.rs::prefix_finds_workspace_struct | Hits with no source path and no byte do nothing. demo: "symbols" |
| Navigate › Go to Definition | F12 | `goToDefinition()` → `Editor/Definitions.swift` | If a Quick Definition peek is visible, opens its excerpt. Otherwise calls engine `findDefinitions` at the caret and opens the first hit. | RUST: tests/definition.rs::local_definition_comes_first, tests/definition.rs::qualified_path_narrows_hits, tests/definition.rs::c_prototype_then_definition | Never disabled; does nothing without an editor. Uses only the first hit, with no chooser. |
| Navigate › Switch Header / Source | F10 | `switchHeaderSource()` → `Navigate/AppState+Jumps.swift` | Opens the `SiblingSource` of the active buffer, or of the neighbour pane's buffer. When split, it opens in the other pane. | SELFTEST: "header source switch" (cpp); UNIT: SiblingSourceTests.testHeaderFindsSourceInSameDirectoryFirst, SiblingSourceTests.testSourceFindsHeaderAndOtherFilesHaveNoSibling | ⚠ Also bound to ⌃⌥↑ in `RideTextView.keyDown`. That binding is not in the menu or the Shortcuts sheet. Never disabled; does nothing for files without a sibling. |
| Navigate › Find Usages | ⌥F7 | `findUsages()` → `Usages/AppState+Usages.swift` | Needs an engine session. Opens the Usages panel, calls engine `noteSaved` then `findUsages` at the caret, and groups rows by file. Definition-scope hits go under "Other matches". Disabled `!hasEditor`. | SELFTEST: "find usages" (rust); RUST: tests/refs.rs::find_usages_groups_and_replaces, tests/refs.rs::usages_in_the_open_buffer_follow_unsaved_edits; UNIT: UsageModelTests.testGroupsByFileInFirstSeenOrder, UsageModelTests.testSplitSeparatesDefinitionScope | Silent no-op for buffers without a session. demo: "usages" |
| Navigate › Call Hierarchy | ⌃⌥H | `showCallHierarchy()` → `Hierarchy/AppState+Hierarchy.swift` | Runs `queryHierarchy(.callers)`: engine `callers` at the caret, shown in the Hierarchy panel. The panel then re-queries 0.35 s after the caret moves (`HierarchyFollower`). Disabled `!canRefactor` (C/C++/Rust). | SELFTEST: "call hierarchy", "call hierarchy follows caret" (rust); RUST: tests/hierarchy.rs::callers_of_record_are_the_two_calls; UNIT: HierarchyModelTests.testSetRootExpandsAndShowsChildren, HierarchyModelTests.testRefreshKeepsTheTreeUntilANewRootArrives, HierarchyModelTests.testGenerationIgnoresStaleBegin +6 more | demo: "hierarchy" |
| Navigate › Type Hierarchy | ⌃H | `showTypeHierarchy()` | Runs `queryHierarchy(.types)`: engine `typeHierarchy` (supertypes and subtypes) at the caret. Disabled `!canRefactor`. | RUST: tests/hierarchy.rs::rust_trait_impls_link_counter_and_recorder, tests/hierarchy.rs::cpp_bases_and_derived_classes | ⚠ ⌃H takes over the Cocoa text-system ⌃H (deleteBackward) in the editor. C has no types, so the panel shows "No hierarchy at the caret". |
| Navigate › Rename… | ⇧F6 | `beginRename()` → `RenameController.begin` | Needs a session, a writable document and the caret on an identifier. Shows an inline field over the name. On Return, engine `renameLocal` is applied in place if the name is local. Otherwise engine `renamePlan` opens the Rename preview sheet. Disabled `!hasEditor`. | SELFTEST: "rename local", "rename workspace preview", "rename review apply", "rename skips edited buffer" (rust; `RenameController.prepare` + `applyLocalDirect`/`buildPreview`, bypassing the inline box); RUST: tests/rename.rs::rename_local_edits_every_counter_occurrence, tests/rename.rs::rename_plan_lists_unresolved_matches_for_review, tests/rename.rs::rename_local_refuses_non_local | ⚠ Silent when `prepare` fails (read-only, no identifier, no session) or the plan is empty. Safe Delete shows a notice for the same cases. demo: "rename" (calls `commit` directly) |
| Navigate › Safe Delete… | ⌥⌘⌫ | `beginSafeDelete()` → `RenameController.beginSafeDelete` | Calls engine `safeDeletePlan` for the outline item whose name is under the caret. The plan has one edit that deletes the item, plus a review list of usages outside it. It opens `RenamePreviewSheet` titled "Safe Delete X" with a "Delete" button. If nothing is found it shows the notice "Place the caret on an item name to delete". Disabled `!hasEditor`. | SELFTEST: "safe delete", "safe delete undo" (rust; via `applySafeDeleteDirect`, which applies locally only when review is empty; the sheet path is not exercised); RUST: tests/safe_delete.rs::unused_fn_has_one_file_and_empty_review, tests/safe_delete.rs::record_review_lists_both_call_sites | ⚠ The same "place the caret" notice appears for read-only or session-less buffers, which is misleading. There is no separate NSAlert: the "dialog" is the rename sheet. The summary reads "1 occurrence in 1 file" for the definition. |
| Navigate › Next Problem | F2 | `nextProblem(1)` → `Navigate/AppState+Jumps.swift` | Jumps to the first diagnostic after the caret, ordered by (path, byte) across all files, and wraps. It records the location and opens the file read-only outside the workspace. | NONE | Never disabled. The ordering relies on `DiagnosticStore.snapshot`, which is sorted (DiagnosticStoreTests.testSnapshotOrderedByPathThenByte covers the order only). |
| Navigate › Previous Problem | ⇧F2 | `nextProblem(-1)` | Jumps to the last diagnostic before the caret and wraps. | NONE | |
| Navigate › Next Method | ⌃↓ | `nextMethod(1)` | Jumps to the next outline-item start after the caret in the active buffer. No wrap. Goes through `jumpTo`, which records the location. | SELFTEST: "next method" (rust) | ⚠ The title says "Method", but it walks every outline row (structs, enums, consts, fields, headings…). ⚠ ⌃↓/⌃↑ are the macOS default App Exposé/Mission Control keys, so the system takes them unless the user turns those off. |
| Navigate › Previous Method | ⌃↑ | `nextMethod(-1)` | Jumps to the previous outline-item start. | NONE | Only delta +1 is tested. |
| Navigate › Matching Brace | ⌃M | `EditorCommands.matchingBrace()` → `Editing/EditorCommands+Selection.swift` | Calls engine `bracketPair` at the caret. If the caret is within 1 of the opener it jumps to the closer, otherwise to the opener. Records the location. | SELFTEST: "matching brace" (rust `rustSelect`; cpp); RUST: tests/editing.rs::brackets_match_with_depth_and_skip_strings_and_comments, tests/editing.rs::brackets_in_other_languages_and_unterminated_c_string | Never disabled. |

### Shared picker mechanics (PickerCard / PickerRow / PickerList / OverlayBackdrop)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Picker › Esc | esc | `PickerCard.onExitCommand(perform: onDismiss)` | Clears the overlay's `show…` flag. | NONE | There is no explicit editor refocus, unlike the Return paths, which call `select(focus:)` or `makeFirstResponder`. |
| Picker › click outside card | — | `OverlayBackdrop.onTapGesture(dismiss)` | Dismisses the overlay (dimmed 25% backdrop). | NONE | |
| Picker › Return in query field | ↩ | `TextField.onSubmit(onSubmit)` | Confirms the current selection for that picker (see the tables below). | NONE | The query field is auto-focused `onAppear`. |
| Picker › click row | — | `PickerRow.onTapGesture(action)` | Each picker sets its selection to the row, then confirms. | NONE | Hover only highlights. |
| Picker › selection follows keys | — | `PickerList.onChange(selected)` → `scrollTo` | Scrolls the list (max 12 rows visible) to keep the selection visible. | NONE | |

### Open Quickly overlay (`QuickOpenOverlay`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Open Quickly › type query | — | `onChange(quickQuery)` → `refreshQuickOpen()` | Re-matches files with `FileIndex.matches`. Keeps the selection if it still matches, otherwise selects the first hit. The trailing text shows "N files". | NONE | demo: "quickopen" |
| Open Quickly › ↓ / ↑ | ↓ ↑ | `onKeyPress` → `selectNextQuick()` / `selectPreviousQuick()` | Moves the selection and wraps. | NONE | |
| Open Quickly › ↩ / click row | ↩ | `confirmQuickOpen()` | Closes the overlay and calls `openFile(selection ?? first)`. | NONE | |

### Recent Files overlay (`RecentFilesOverlay`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Recent Files › type query | — | `recentHits` + `onChange(recentQuery)` | Filters by filename substring and resets the selection to the first match. | NONE | Empty states: "No files opened yet" / "No matching files". |
| Recent Files › ↓ / ↑ | ↓ ↑ | `moveRecentSelection(±1)` | Moves the selection and wraps. | NONE | |
| Recent Files › ↩ / click row | ↩ | `confirmRecentFile()` | Closes the overlay and opens the selected file, or the first hit. | NONE | |

### Go to Line overlay (`GoToLineOverlay`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Go to Line › type query | — | computed `hint` / `lineCount` | Live hint: "Currently at line X", "Go to line N" or "Past the last line, jumps to line N". The trailing text shows "of N". | NONE | Footer shows only ↩ go / esc. There are no ↑/↓ keys. |
| Go to Line › ↩ | ↩ | `confirmGoToLine()` | Parses `line[:col]`, clamps both, records the location, selects and focuses. Non-numeric or empty input just closes. | SELFTEST: "go to line" (rust, c, cpp) | |

### Go to Symbol in File overlay (`SymbolInFileOverlay`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Symbol in File › type query | — | `rows` + `onChange(symbolQuery)` | Filters the outline by name or kind label (max 60) and selects the first row. | NONE | |
| Symbol in File › ↓ / ↑ | ↓ ↑ | private `move(±1)` | Moves the selection and wraps. | NONE | |
| Symbol in File › ↩ / click row | ↩ | private `confirm()` → `state.jumpTo(byte:)` | Closes the overlay and jumps to the item start, recording the location. | NONE | `jumpTo` itself runs in "next method". |

### Go to Symbol in Project overlay (`SymbolPickerOverlay` + `SymbolPickerModel`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Symbol in Project › type query | — | `onChange(query)` → `model.refresh()` | Runs a debounced (50 ms) engine `queryCompletions` in the background and drops stale query ids. Selects the first hit. | RUST: tests/query.rs::rustdoc_kind_filter, tests/query.rs::stale_query_id_is_dropped | Row tooltip shows `docFirstSentence`. demo: "symbols" |
| Symbol in Project › ↓ / ↑ | ↓ ↑ | `model.move(±1)` | Moves the selection and wraps. | NONE | |
| Symbol in Project › ↩ / click row | ↩ | private `confirm()` → `HitNavigation.open` | Closes the overlay. Opens the source path at its byte (read-only outside the workspace), or jumps in the current file when there is no path. | NONE | |
| Symbol in Project › copy path | ⌘C | `.onCopyCommand` on `PickerList` | Should put `hit.path` on the pasteboard. | NONE | ⚠ The modifier sits on the list, which never takes focus. The query field keeps focus, so ⌘C most likely copies the field text. This is from reading the code, not tested. |

### Hierarchy panel (`HierarchyPanel`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Hierarchy header › Callers segment | — | `setHierarchyMode(.callers)` → `queryHierarchy(.callers)` | Re-queries callers at the current caret. | SELFTEST: "call hierarchy" (rust; `showCallHierarchy` makes the same `queryHierarchy(.callers)` call) | Switching segment re-roots at the caret, not at the old root. |
| Hierarchy header › Callees segment | — | `setHierarchyMode(.callees)` | Calls engine `callees`. Lists the call sites inside the enclosing function (current file). Rows are not expandable. | RUST: tests/hierarchy.rs::callees_of_main_list_buffer_calls; UNIT: HierarchyModelTests.testCalleesAreNotExpandable | |
| Hierarchy header › Types segment | — | `setHierarchyMode(.types)` | Calls engine `typeHierarchy` at the caret. | RUST: tests/hierarchy.rs::rust_trait_impls_link_counter_and_recorder, tests/hierarchy.rs::cpp_bases_and_derived_classes | |
| Hierarchy header › Hide Hierarchy (xmark) | — | `hideHierarchy()` | Sets `showHierarchy=false` and clears the follower anchor. | NONE | ⚠ There is no View-menu toggle to bring the panel back. Only re-running a hierarchy command reopens it. `showHierarchy.didSet` calls `syncMenu()`, but `MenuModel` has no flag for it. |
| Hierarchy › click row | — | `openHierarchyRow(node)` | Calls `jumpTo(byte)` if the node has no path. Otherwise `openUsage(path, byte)`, which opens read-only outside the workspace. | NONE | |
| Hierarchy › click chevron | — | `toggleHierarchyRow(id)` | Collapses, or expands (depth < 6, not callees) and lazily loads children with engine `callers`/`typeHierarchy` on that node. Unopened files get a temporary session. Cycles are dropped. | UNIT: HierarchyModelTests.testCollapseHidesChildrenButKeepsThemLoaded, HierarchyModelTests.testExpandOfUnloadedChildAsksForAFetch, HierarchyModelTests.testDepthSixCannotExpand +2 more | |

### Usages panel (`UsagesPanel`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Usages header › Hide Usages (xmark) | — | `state.showUsages = false` | Hides the panel. | NONE | |
| Usages › click usage row | — | `openUsage(path, byteStart)` | Opens the file at the usage byte, read-only outside the workspace. | NONE | File-group header rows are not clickable. |
| Usages › "Other matches · N" disclosure | — | `@State showOther.toggle()` | Shows or hides the definition-scope ("other") groups. | UNIT: UsageModelTests.testSplitSeparatesDefinitionScope | The state is per view and resets when the panel is rebuilt. |

### Outline panel (`FileOutlineView`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Outline header › Hide Outline (xmark) | — | `updatePrefs { $0.outlinePanel = false }` | Hides the panel, the same as unticking View › Outline. | NONE | |
| Outline › click row | — | `state.jumpTo(byte: row.startByte)` | Jumps the focused editor to the item and records the location. | NONE | `jumpTo` runs indirectly in "next method". |
| Outline › click chevron | — | `OutlineList.collapsed` | Collapses or expands a row's children. Rows nest by byte-range containment (`OutlineTree.nodes`): trait and mod members under their item, Rust impl members under a synthesized `impl …` row built from the engine's `OutlineItem.scope`. Collapse state is keyed by the row's name path, so it survives edits that shift bytes. | `OutlineTreeTests` | Markdown headings stay flat (each heading's range is its own line). |

### Preview pane (`PreviewPane` / `MarkdownPreview`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Preview header › Close Preview (xmark) | — | `state.showPreview = false` | Hides the preview. | NONE | |
| Preview › click link | — | `Coordinator.webView(_:decidePolicyFor:)` | Opens http/https links in the default browser. All other navigation is cancelled silently, including relative `.md` links, anchors and `file:`. | NONE | |

### Rename inline box (`RenameInlineBox`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Rename box › Return | ↩ | `insertNewline` → `onCommit` → `RenameController.commit` | Hides the box, then `resolve`: a local rename is applied in place, otherwise the workspace plan opens the preview sheet. An empty or unchanged name does nothing. | NONE | `resolve()` is covered through the Rename… steps (via `applyLocalDirect`/`buildPreview`). The box key path is not. |
| Rename box › Esc | esc | `cancelOperation` → `onCancel` → `box.hide()` | Removes the field and refocuses the editor. | NONE | |
| Rename box › Tab / click away | ⇥ | none | Nothing handles the end of editing. | NONE | ⚠ There is no `controlTextDidEndEditing`. Clicking elsewhere or pressing Tab leaves the field stuck over the editor text until Return or Esc is pressed inside it. |

### Rename preview sheet, also the Safe Delete dialog (`RenamePreviewSheet`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Rename sheet › Select All | — | `selection.selectAllFiles(true)` | Ticks every "Occurrences" file. Disabled when there are no files. | NONE | |
| Rename sheet › Select None | — | `selection.selectAllFiles(false)` | Unticks every file. | SELFTEST: "rename review apply", "rename skips edited buffer" (`chooseOnly`) | |
| Rename sheet › Cancel | esc (`.cancelAction`) | `onCancel` → `showRenamePreview = false` | Closes the sheet. | NONE | `renamePlan` and `renameExpected` stay set until the next load. They are stale but harmless. |
| Rename sheet › Rename / Delete | ↩ (`.defaultAction`) | `RenameController.applyWorkspace()` → `RenameApply.applyWorkspace` | Applies the chosen file and review edits to open views, buffers or disk. Files changed since the plan are skipped (`RenameExpected`, "changed since indexing" notice). Posts a summary notice. Disabled unless `canApply`. | SELFTEST: "rename review apply", "rename skips edited buffer" (rename plans only; never run with a safe-delete plan); UNIT: RenameSelectionTests.testUntickFileDropsItFromApply, RenameSelectionTests.testEmptyFilesShowsBannerAndReviewTickEnablesApply | The button reads "Delete" for Safe Delete. |
| Rename sheet › file checkbox | — | `selection.setFile(path, on)` | Includes or excludes one file's edits. | SELFTEST: "rename review apply" (`chooseOnly`); UNIT: RenameSelectionTests.testFilesTickedReviewUntickedByDefault, RenameSelectionTests.testUntickFileDropsItFromApply | |
| Rename sheet › Review "All"/"None" | — | `selection.selectAllReview(!allReviewSelected)` | Ticks or unticks every review row. | SELFTEST: "rename review apply" (`chooseOnly`); UNIT: RenameSelectionTests.testSelectAllReviewToggles | |
| Rename sheet › review row checkbox | — | `selection.setReview(id, on)` | Includes one unverified file's edits. | SELFTEST: "rename review apply" (`chooseOnly`); UNIT: RenameSelectionTests.testTickReviewAddsEditsAndTargets | ⚠ In Safe Delete mode the review rows are "Usages that would break". Ticking one applies its engine edit, which deletes only the identifier at that call site and leaves broken code. |


---

## Code and Build menus (+ popups, panels, sheets they open)

Source: `app/Ride/Menus/CodeCommands.swift`. Enablement flags from `MenuModel.sync`: `hasEditor` = `activeBuffer != nil`; `canGenerate` = `canRefactor` = active buffer is C, C++ or Rust; `hasWorkspace` = `workspaceRoot != nil`.
Most editor commands go through `EditorCommands.target()`. It returns nil (so the command does nothing) unless the focused pane's text view is first responder and editable.

### Code menu

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Code › Comment Line | ⌘/ | `EditorCommands.commentLine()` → `CommentToggle.toggleLine` | Toggles the language line comment on each touched line. Falls back to a block comment when the language has no line token (Markdown). | SELFTEST: "comment line", "uncomment line" (rust, cpp); UNIT: CommentToggleTests.testCaretLineGetsCommentedAndCaretMoves, testUncommentHandlesMissingSpace, testHashLanguagesAndFallbacks +5 more | No `.disabled`. Does nothing without a focused, editable editor. |
| Code › Comment Block | ⌥⌘/ | `EditorCommands.commentBlock()` → `CommentToggle.toggleBlock` | Wraps the trimmed selection (or the caret line's content) in `/* */` or `<!-- -->`, or unwraps it. Does nothing for TOML, Make and CMake. | SELFTEST: "comment block", "uncomment block" (rust); UNIT: CommentToggleTests.testBlockWrapsAndUnwraps | No `.disabled`. |
| Code › Indent | — | `EditorCommands.indent()` → `LineOps.indent` | Indents every touched line by one unit (a tab for Makefiles, otherwise tabWidth spaces). | SELFTEST: "indent keeps selection" (rust, c, cpp); UNIT: LineOpsTests.testIndentShiftsEveryTouchedLine, testIndentWithTabsForMakefiles | The selftest reaches `LineOps.indent` through Tab (`insertTab` → `indentSelection`), not through `EditorCommands.indent`. The menu item has no shortcut; Tab/⇧Tab do this in the editor. |
| Code › Unindent | — | `EditorCommands.unindent()` → `LineOps.unindent` | Removes up to one indent unit (or one tab) from each touched line. | SELFTEST: "unindent keeps selection" (rust, c, cpp); UNIT: LineOpsTests.testUnindentRemovesUpToWidthOrOneTab | The selftest goes through ⇧Tab (`insertBacktab`) and ends at the same `LineOps.unindent`. |
| Code › Auto-Indent Lines | ⌃⌥I | `EditorCommands.autoIndent()` → `SmartIndent.autoIndent` | Re-indents the selected lines based on the line above. | UNIT: SmartIndentTests.testAutoIndentReindentsFromThePreviousLine | No `.disabled`. |
| Code › Reformat Document | ⌃⇧I | `state.formatActive()` → `formatNow` → `engine.formatBuffer` | Runs the language's formatter (rustfmt, clang-format, Makefile normalizer, …) on the whole buffer off-main. Shows a notice on error, on "already formatted", or when the text changed meanwhile. | SELFTEST: "format document" (rust); RUST: tests/check.rs::rustfmt_formats_and_reports_errors, makefile_formatter_normalizes_recipes, rustfmt_honours_the_project_config_next_to_the_file | No `.disabled`. Read-only buffers are skipped silently. demo: "unformatted". |
| Code › Reformat Selection | ⌥⌘L | `state.formatSelection()` → `engine.formatC` / `engine.formatRust` (byte range) | Formats only the selected byte range for C, C++ and Rust. | RUST: tests/check.rs::clang_format_selection_changes_only_selected_function, rustfmt_selection_formats_enclosing_fn_only, format_range_makefile_formats_whole_file | ⚠ For any other language it falls through to `formatBuffer` and formats the whole document, even though the title says Selection. The engine test says this is intended for Makefiles. |
| Code › Complete Statement | ⇧⌘↩ | `EditorCommands.completeStatement()` → `engine.completeStatement` | Applies the engine's edit at the caret, such as adding `;`, closing a header `{}` or moving to a new line. | SELFTEST: "complete statement" (cpp); RUST: tests/editing.rs::rust_complete_statement_semicolon_header_and_new_line, c_complete_statement_semicolon_header_and_new_line, complete_statement_engine_none_without_session | No `.disabled`. Does nothing, with no feedback, in languages other than C, C++ and Rust. |
| Code › Generate… | ⌃⌘G | `EditorCommands.generate()` → `engine.generateOptions` → NSMenu (`IntentionMenu.pop`) | Lists generators for the struct/class/union around the caret (it needs at least one field) and pops a menu at the caret. Shows "Nothing to generate here" when the list is empty. | RUST: src/generate/tests.rs::options_present_with_fields_absent_without, plain_c_offers_no_cpp_members; src/generate/rust/mod.rs::options_offer_all_on_bare_struct +2 more | ⚠ Enabled for C (`canGenerate` includes `.c`), but `generate::options` returns nothing for `Lang::C`, so in C it always shows "Nothing to generate here". The selftests call `applyGenerator` directly, so `generate()` and its popup are never exercised. |
| Code › Extract Variable | ⌥⌘V | `EditorCommands.extractVariable()` → `engine.extractVariable` | Extracts the selected expression into a `let` (Rust) or `auto` (C++) local and selects the new name. Shows "Select an expression to extract" on failure. | SELFTEST: "extract variable" (rust, cpp); RUST: src/refactor/tests.rs::rust_binary_expression, rust_call_expression, src/refactor/tests_boundary.rs::refuses_plain_c +more | ⚠ Enabled for C (`canRefactor`), but the engine refuses plain C (`extract::keyword` returns None). In C it always shows the notice. |
| Code › Introduce Constant | ⌥⌘C | `EditorCommands.introduceConstant()` → `engine.introduceConstant` | Replaces the selected literal with a new constant: `const` in Rust, `constexpr` in C++, `static const` in C. Shows "Select a literal to introduce" on failure. | SELFTEST: "introduce constant" (rust, cpp); RUST: src/refactor/tests_constant.rs::rust_integer_literal, rust_string_literal, rust_float_and_bool +more | |
| Code › Inline Variable | ⌃⌥N | `EditorCommands.inlineVariable()` → `engine.inlineVariable` | Inlines the local under the caret into its uses and removes the declaration. Shows a notice when the caret is not on a local. | SELFTEST: "inline variable" (rust, cpp); RUST: src/refactor/tests_inline.rs (13 tests), tests_inline_scope.rs | |
| Code › Show Intention Actions | ⌥↩ | `EditorCommands.showIntentions()` → `IntentionActions.fetch` → `engine.intentions` → `IntentionMenu.pop` | Collects the intentions at the caret (see the Intention menu table) and pops them as a menu. Shows "No intention actions here" when there are none or no session exists. | SELFTEST: "intention underscore", "intention constant" (rust); RUST: tests/intentions.rs::diagnostic_fix_at_the_caret_comes_first, missing_import_is_offered +6 more | The selftests use `EditorCommands.applyIntention(matching:)`, which is test-only. It shares `fetch` and `apply` with the menu but skips the popup. demo: "intentions". |
| Code › Ask AI from Comment… | ⌃? | `AIAssistant.shared.askFromEditor(state:)` | Captures the focused editor and its selection, pre-fills the prompt from the comment at or above the caret, and opens the Ask AI sheet. | UNIT: AICommentPromptTests.testCaretOnCommentLineJoinsTheCommentRun, testCommentAboveTheCaretLineIsUsed, testBlockCommentsAndHashComments | ⚠ When no comment is found it keeps the previous prompt (`?? prompt`), so old text reappears. ⚠ `⌃?` needs Shift on US layouts (really ⌃⇧/). It also does nothing silently when the active buffer has no focused pane. |
| Code › Surround With… | ⌥⌘T | `EditorCommands.surroundWith()` → `SurroundWith.templates` → NSMenu | Pops the list of per-language wrap templates at the caret. The chosen one wraps the selection and re-selects the inner text. | SELFTEST: "surround" (rust) | The selftest calls `SurroundWith.apply` with an ad-hoc `(`…`)` template. It skips `surroundWith()` and `templates(for:)`. ⚠ ⌥⌘T probably clashes with SwiftUI's automatic View › Show/Hide Toolbar: RootView has `.toolbar` and the `.toolbar` command group is not replaced (not verified). No `.disabled`. |
| Code › Fold | ⌥⌘← | `FoldController.shared.fold()` → `engine.foldRanges` | Folds the innermost fold range containing the caret. | SELFTEST: "fold" (rust, cpp), "gutter fold" (rust); UNIT: FoldSetTests.testHidesParagraphsStrictlyInsideAndClampsCaret; RUST: tests/editing.rs::rust_folds_cover_every_kind | |
| Code › Unfold | ⌥⌘→ | `FoldController.shared.unfold()` | Removes the fold that contains the caret. | SELFTEST: "gutter unfold" (rust, via `toggle(line:)` → `unfold()`) | |
| Code › Fold All | ⇧⌥⌘← | `FoldController.shared.foldAll()` | Adds every engine fold range to the view. | UNIT: FoldSetTests.testHidesParagraphsStrictlyInsideAndClampsCaret; RUST: tests/editing.rs::rust_folds_cover_every_kind, c_folds_cover_every_kind +5 more | No selftest. |
| Code › Unfold All | ⇧⌥⌘→ | `FoldController.shared.unfoldAll()` | Removes all folds in the view. | SELFTEST: "unfold all" (rust, cpp) | |
| Code › Trigger Completion | ⌥Space | `EditorCommands.triggerCompletion()` → `CompletionSession.trigger` | Starts an AI completion request and, when completions are on and the language supports them, schedules an engine completion popup. | SELFTEST: "completion doc trigger" (rust); UNIT: CompletionTriggerTests.testLanguagesWithoutCompletions | With Preferences › Completions off, only the AI path runs. demo: "completion". |
| Code › Cheat Sheet | ⌥⇧Space | `EditorCommands.toggleCheatSheet()` → `CheatSheetController.toggle` | Closes the sheet if pinned. Otherwise pins it and fetches `engine.cheatSheet` for the caret context. Only for languages with completions. | UNIT: CheatSheetRowsTests.testRowsFlattenWithHeaders +4 more; RUST: tests/cheatsheet.rs::every_sheet_parses, rust_contexts, engine_cheat_sheet_uses_site_prefix_and_indent +10 more | When the sheet is auto-shown next to completion (unpinned), this pins it rather than hiding it. The hint "⌥⇧space pin" says so. demo: "cheatsheet". |
| Code › Quick Documentation | ⌃J | `DocController.showFocused()` | Upgrades a visible hover to the doc panel, or fetches `quickDoc` at the caret and shows the doc panel. | SELFTEST: "quick doc" (rust, via `state.showQuickDocumentation()`); RUST: tests/outline_docs.rs::quick_doc_renders_fenced_example, quick_doc_doxygen_brief_and_params, quick_doc_resolves_intra_doc_link +4 more | ⚠ This is one of two visible menu rows with the identical title "Quick Documentation" (see F1). demo: "quickdoc". |
| Code › Quick Documentation | F1 | `DocController.showFocused()` | Same as the ⌃J item. | SELFTEST: "quick doc" (rust) | ⚠ A duplicate menu row with the same title and handler. A second shortcut could be a hidden alternate instead of a second visible item. |
| Code › Quick Definition | ⌘Y | `PeekController.showFocused()` → `quickDefinition` | Shows the peek panel with the definition excerpts for the symbol at the caret. Does nothing if there are none. | SELFTEST: "quick definition" (rust, cpp), "quick definition enumerator" (c); RUST: tests/definition.rs::c_prototype_then_definition, rust_trait_method_two_impls, long_function_is_truncated | demo: "peek". |
| Code › Type Info | ⌃⇧P | `DocController.showTypeInfoFocused()` → `typeInfo` → the server's `textDocument/hover` | Shows the type of the binding or expression at the caret (rust-analyzer, clangd) in the documentation popup: the server's code line as the signature and its notes as the body. Says so when no server answers. | SELFTEST: "menu type info" (rust); RUST: tests/oracle_live.rs::type_info_names_the_inferred_type_of_a_binding, tests/oracle_clangd_live.rs::type_info_names_the_type_behind_auto | Needs the language servers on (Preferences › Editor). |
| Code › External Documentation | ⇧F1 | `DocController.showExternalFocused()` → `Definitions.lookup` → `DocExternal.url` → `NSWorkspace.open` | Opens a docs.rs search for crate symbols, or a cppreference search for `std::` names, in the browser. | UNIT: DocPageTests.testCatalogItemOpensDocsRs, testStdCppNameOpensCppreference, testCrateWinsOverStdPath +1 more | ⚠ Does nothing silently (no notice) for workspace symbols or when there is no definition hit. |
| Code › Signature Help | ⇧⌘Space | `state.showSignatureHelp()` → `SignatureHelpController.show` → `signatureHelp` | Shows the parameter-hint panel for the call around the caret. Rust, C and C++ only. Hides if there is no call. | SELFTEST: "outer signature after )" (rust, reached by typing `(`/`,` → same `show`); RUST: tests/edits_and_signatures.rs::signature_help_from_buffer_and_catalog, c_signature_help_from_buffer_prototype, signature_help_outer_call_after_inner_close | No `.disabled`. The explicit command ignores the `prefs.signatureHelp` auto setting (intended). |

### Build menu

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Build › Check | ⌥⌘B | `state.runCheck()` → `CheckService.run(file:)` / `run(root:)` → `engine.runCheckC` / `engine.runCheck` | Checks the file with clang for a saved C/C++ buffer. Otherwise runs cargo check on `activeProjectRoot`. Results go to Problems. | RUST: tests/check.rs::cargo_check_on_fixture_crate, tests/clang_check.rs::runs_clang_on_a_c_file_without_a_database, runs_clang_on_a_cpp_file_with_std_headers | ⚠ Any non-clang buffer (Markdown, TOML, untitled C) triggers `cargo check`, even in a CMake or Make project. No `.disabled`. Without a project root it does nothing silently. |
| Build › Check Project | ⇧⌥⌘B | `state.runProjectCheck()` → `CheckService.runProject` → `engine.runCheckCProject` | Runs clang on every source in compile_commands.json under the project root, using 4 workers. | RUST: tests/clang_check.rs::project_check_on_clean_cpp_demo_has_no_diagnostics, shuffled_job_order_yields_the_same_project_check, project_check_keeps_diagnostics_when_one_file_fails | ⚠ It only does a C/C++ check. In a Cargo workspace it fails with "clang: no compile_commands.json", but the item is enabled on `hasWorkspace`. The title suggests a generic project check. |
| Build › Install Tools… | — | `state.showToolsSheet = true` → RootView `.sheet` → `ToolsInstallView` | Opens the Tools sheet. On appear it refreshes `engine.toolStatus()`. | RUST: tests/discover.rs::tool_status_lists_every_tool_with_a_hint | demo: "tools". The Welcome setup and the launch prompt (AppState+View) open the same sheet. |

### Generate popup (NSMenu from `engine.generateOptions`; pick → `GenerateMenuTarget.pick` → `EditorCommands.applyGenerator(kind)` → `engine.generateApply`)

Needs the caret inside a struct/class/union with at least one own field. Rust options are left out when already present. C++ always lists all five. C lists none.

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Generate › new (Rust) | — | `applyGenerator(.new)` | Inserts `impl T { pub fn new(fields…) -> Self }` after the struct. | SELFTEST: "generate new" (rust); RUST: src/generate/rust/mod.rs::new_uses_field_name_and_full_type, options_omit_new_when_impl_new_exists | Hidden when an inherent impl already has `fn new`. |
| Generate › impl block (Rust) | — | `applyGenerator(.implBlock)` | Inserts an empty `impl T {}` after the struct. | RUST: src/generate/rust/mod.rs::impl_block_is_empty | ⚠ Only hidden when an inherent impl has `fn new`. If an impl without `new` exists, it still offers a second empty impl. |
| Generate › Default impl (Rust) | — | `applyGenerator(.defaultImpl)` | Inserts `impl Default for T` that fills each field. | RUST: src/generate/rust/mod.rs::default_impl_fills_fields, options_omit_default_when_derived | Hidden when `#[derive(Default)]` or `Default for T` is present. |
| Generate › Display impl (Rust) | — | `applyGenerator(.displayImpl)` | Inserts `impl std::fmt::Display for T` that writes the fields. | RUST: src/generate/rust/mod.rs::display_impl_writes_fields | Hidden when `Display for T` is present. |
| Generate › Constructor (C++) | — | `applyGenerator(.constructor)` | Inserts a constructor with an init list for own fields (base fields skipped) before the closing `}`. | SELFTEST: "generate constructor" (cpp); RUST: src/generate/tests.rs::constructor_has_params_and_init_list, constructor_omits_base_fields | ⚠ Offered even when a constructor already exists (C++ has no already-present filter). |
| Generate › Getters (C++) | — | `applyGenerator(.getters)` | Inserts one const getter per field, dropping a trailing `_`. | SELFTEST: "generate getters" (cpp); RUST: src/generate/tests.rs::getters_one_per_field, getter_prefixes_without_underscore, getter_keeps_namespace_qualifier | |
| Generate › Setters (C++) | — | `applyGenerator(.setters)` | Inserts one setter per field. | RUST: src/generate/tests.rs::setters_one_per_field | |
| Generate › Equality operators (C++) | — | `applyGenerator(.equalityOps)` | Inserts `operator==` and `operator!=` comparing all fields. | RUST: src/generate/tests.rs::equality_pair | |
| Generate › Stream operator (C++) | — | `applyGenerator(.streamInsert)` | Inserts `operator<<` for `std::ostream` that prints the fields. | RUST: src/generate/tests.rs::stream_insert_operator | |

### Surround With popup (`SurroundWith.templates(for:tokens:)`; pick → `SurroundMenuTarget.pick` → `SurroundWith.apply`)

Every template replaces the selection with open + selection + close and selects the inner text. With no selection it inserts the empty pair.

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Surround › { … } (all languages) | — | `SurroundWith.apply` | Wraps in `{` `}`. | NONE | |
| Surround › ( … ) (all languages) | — | `SurroundWith.apply` | Wraps in `(` `)`. | SELFTEST: "surround" (rust, ad-hoc template with the same open/close) | |
| Surround › [ … ] (all languages) | — | `SurroundWith.apply` | Wraps in `[` `]`. | NONE | |
| Surround › " … " (all languages) | — | `SurroundWith.apply` | Wraps in double quotes. | NONE | |
| Surround › if (Rust) | — | `SurroundWith.apply` | Wraps in `if condition {\n` … `\n}`. | NONE | ⚠ The placeholder `condition` is not selected, and the wrapped body is not re-indented. |
| Surround › loop (Rust) | — | `SurroundWith.apply` | Wraps in `loop {\n` … `\n}`. | NONE | No re-indent. |
| Surround › unsafe (Rust) | — | `SurroundWith.apply` | Wraps in `unsafe {\n` … `\n}`. | NONE | No re-indent. |
| Surround › match (Rust) | — | `SurroundWith.apply` | Wraps in `match value {\n` … `\n}`. | NONE | The placeholder `value` is not selected. The result is not valid match syntax until arms are written. |
| Surround › Some( … ) (Rust) | — | `SurroundWith.apply` | Wraps in `Some(` `)`. | NONE | |
| Surround › Ok( … ) (Rust) | — | `SurroundWith.apply` | Wraps in `Ok(` `)`. | NONE | |
| Surround › if (C/C++) | — | `SurroundWith.apply` | Wraps in `if (condition) {\n` … `\n}`. | NONE | Same placeholder and indent issue as the Rust `if`. |
| Surround › while (C/C++) | — | `SurroundWith.apply` | Wraps in `while (condition) {\n` … `\n}`. | NONE | |
| Surround › #if 0 … #endif (C/C++) | — | `SurroundWith.apply` | Wraps in `#if 0\n` … `\n#endif`. | NONE | |
| Surround › /* … */ (Rust/C/C++) | — | `SurroundWith.apply` | Wraps in `/* ` … ` */`. | NONE | Comes from `CommentTokens` block tokens. |
| Surround › <!-- … --> (Markdown) | — | `SurroundWith.apply` | Wraps in `<!-- ` … ` -->`. | NONE | TOML, Make, CMake and plain text get only the four generic templates. |

### Intention Actions popup (`engine.intentions` → `IntentionMenu.menu`; pick → `IntentionMenuTarget.pick` → `IntentionActions.apply`)

Engine order is: diagnostic fixes, then import/include, then underscore, missing arms and refactors. Entries without edits are dropped (`intentions::number`).

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Intentions › <diagnostic fix title> | — | `intentions::fix_drafts` | Offers the fixes attached to diagnostics covering the caret (cargo machine-applicable suggestions, clang fix-its), taken from `CheckService.diagnostics`. | RUST: tests/intentions.rs::diagnostic_fix_at_the_caret_comes_first; tests/check.rs::machine_applicable_children_become_fixes; tests/clang_check.rs::parseable_fixits_attach_to_their_diagnostic | Only appears after a Check or live check has produced fixes. |
| Intentions › Import <path> (Rust) | — | `intentions::import_drafts` | Adds a `use` for up to 5 catalog/workspace matches of the unresolved name at the caret. | RUST: tests/intentions.rs::missing_import_is_offered; tests/edits_and_signatures.rs::import_edit_inserts_sorted_into_the_last_use_block | |
| Intentions › Include <header> (C/C++) | — | `IncludeJob.drafts` → `intentions::include_draft` | Adds `#include "…"` or `<…>` for a header that defines the symbol, when it is not already included. | NONE | No engine test covers include intentions. |
| Intentions › Rename to _<name> | — | `intentions::underscore_drafts` | Prefixes an unused local (single occurrence) with `_`. Skipped when the local is used inline in a Rust format string. | SELFTEST: "intention underscore" (rust); RUST: tests/intentions.rs::unused_local_is_offered_an_underscore, local_used_only_in_a_format_string_is_not_offered_an_underscore | |
| Intentions › Add missing arms (Rust) | — | `engine::intentions::arm_drafts` → `intentions::arm_text` | Adds `Type::Variant => todo!()` style arms for enum variants the match does not cover. | RUST: tests/intentions.rs::missing_match_arm_is_offered, covered_match_offers_no_arms, wildcard_match_offers_no_arms | |
| Intentions › Extract Variable | — | `intentions::refactor_drafts` → `refactor::extract_variable` | Extracts the smallest enclosing expression (up to 3 levels) without a selection. | RUST: src/refactor/tests.rs::rust_binary_expression +8 more | No intention-specific test. Never offered in C. |
| Intentions › Introduce Constant | — | `refactor_drafts` → `refactor::introduce_constant` | Turns the literal around the caret into a constant. | SELFTEST: "intention constant" (rust); RUST: tests/intentions.rs::literal_at_the_caret_offers_introduce_constant | |
| Intentions › Inline Variable | — | `refactor_drafts` → `refactor::inline_variable` | Inlines the local at the caret. | RUST: src/refactor/tests_inline.rs (13 tests) | |

### Cheat Sheet popup (`CheatSheetPopup`; keys in `RideTextView.keyDown` → `handleCheatSheetKey`, `doCommand`)

"Shared" means the completion popup is also visible. In that case plain keys go to completion unless the sheet is focused (clicked or arrowed) or ⌥ is held.

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Cheat Sheet › Move selection | ↑ / ↓ (⌥↑ / ⌥↓ when shared) | `CheatSheetController.move` → `CheatSheetRows.step` | Focuses the sheet and moves to the previous or next entry, skipping headers. | UNIT: CheatSheetRowsTests.testStepSkipsHeadersAndClamps, testSelectionKeepsNameOrFallsBackToFirstEntry | |
| Cheat Sheet › Insert entry | ↩ / Enter / ⇥ (⌥↩ when shared) | `CheatSheetController.insert` → `CompletionSession.insertSnippet` | Hides completion and the sheet, then inserts the entry's snippet over the typed prefix. Tab stops are pushed onto an active snippet. | UNIT: SnippetStackTests.testCheatSheetInsertPushesOntoOuterStack; RUST: tests/cheatsheet.rs::snippet_placeholders_parse_like_the_app | The footer hint for shared mode omits ⇥. |
| Cheat Sheet › Close | Esc | `cancelPopups()` / `cancelOperation` | Hides completion and the cheat sheet together and unpins. | NONE | |
| Cheat Sheet › Search | ⌘F (sheet alone or focused), click the search bar | `PopupSearchRouter` → `CheatSheetController.changeSearch` → `CheatSheetRows.rows(_:search:)` | Filters entries by name, doc, snippet and section title; sections with no match are dropped. Starting it focuses the sheet so ↑↓ and ↩ act on it. Esc or ⌘F ends it. | UNIT: CheatSheetSearchTests; SELFTEST: "cheat sheet search opens", "cheat sheet search filters", "cheat sheet search escape keeps sheet" (rust) | With the completion popup also open and the sheet not focused, ⌘F goes to the completion popup; click the sheet's bar to search it instead. Only one popup searches at a time. |
| Cheat Sheet › Click row | click | `CheatSheetPopup.clickRow` → `onBrowse` → `focus()` | Selects the entry, shows its preview, and gives the sheet key focus. | NONE | |
| Cheat Sheet › Click same row again / double-click | click twice, double-click | `clickRow` (second click) / `doubleClickRow` → `onInsert` → `insert()` | Inserts the clicked entry. | NONE | Two routes to insertion. The footer only mentions "click twice". |

### Completion popup and snippet session (keys in `RideTextView+Keys.swift`; `CompletionPopup.clickRow`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Completion › Accept | ↩ / Enter | `handleCompletionKey` / `insertNewline` → `CompletionSession.accept()` | Replaces the typed prefix with the item, as a snippet if it has one. Also closes `#include` quotes, applies the auto-import edit, re-triggers after a module path, and opens signature help for callables. | UNIT: SnippetParserTests.testPlaceholdersWithDefaults, testFinalStopInsideText +7 more | Only snippet parsing is unit-tested. `accept()` itself has no test. |
| Completion › Accept | ⇥ | `handleCompletionKey` / `insertTab` → `accept()` | Same as ↩. | UNIT: SnippetParserTests (as above) | Handled in both `keyDown` (keyCode 48) and `insertTab`. The duplicate is harmless. |
| Completion › Dismiss | Esc | `CompletionSession.hide()` | Hides the popup and repositions signature help and the cheat sheet. | NONE | |
| Completion › Move selection | ↑ / ↓ | `CompletionPopupController.move` | Moves the selected row (clamped) and updates the doc card. | NONE | Handled in both `keyDown` and `doCommand(moveUp/moveDown)`. |
| Completion › Show docs | ⌘I | `DocController.showCompletion(in:)` | Opens the Quick Documentation panel for the selected item, fetched from the item's source file when it lives elsewhere. | SELFTEST: "completion doc" (rust) | |
| Completion › Click row | click | `clickRow` → `accept()` | Accepts the clicked item. | UNIT: SnippetParserTests (as above) | |
| Completion › Open source | ⌘-click | `clickRow` → `openSelectedSource()` | Posts `.rideOpenCatalog` with the item's source path and hides the popup. | NONE | |
| Completion › Search | ⌘F, click the search bar | `PopupSearchRouter.key` / `begin` → `CompletionSession.changeSearch` → `PopupSearch.filter` | Starts a free-text search over every listed row: engine, rust-analyzer and AI items alike. While it is on, typed text goes to the search bar instead of the buffer. Every whitespace-separated term must appear in the name, detail, signature, docs, path, crate or import path; name matches come first. ⌘F again or Esc ends it and restores the list. | UNIT: PopupSearchTests; SELFTEST: "completion search opens", "completion search matches beyond names", "completion search escape keeps popup" (rust) | ⌘F is claimed before the menus only while a popup is open. Search covers the items the engine returned, so a truncated list is searched as delivered. |
| Completion › Type / Backspace | typing | `CompletionSession.textChanged` → `narrow` / `schedule` | Narrows the list client-side (case-insensitive prefix or humps). Re-queries on trigger characters and hides on whitespace or when nothing matches. | UNIT: CompletionNarrowingTests.testCaseInsensitivePrefixKeepsOrder, testHumpMatch, testSelectionKeepsPreviousRow +2 more; CompletionTriggerTests.testRustTriggers, testCTriggers +4 more | |
| Snippet › Next tab stop | ⇥ (no popup) | `insertTab` → `CompletionSession.snippetNext` → `SnippetSession.next` | Selects the next placeholder. After the last stop it moves the caret to the final `$0` and ends the session. | UNIT: SnippetStackTests.testSingleSnippetWalksStopsThenFinishesAtFinalCaret, testInnerNextPopsAndAdvancesOuterWithRangeShift, testNestedPushSelectsInnerStop +more | Tab only indents a multi-line selection when no snippet is active. |
| Snippet › Previous tab stop | ⇧⇥ | `insertBacktab` → `snippetPrevious` → `SnippetSession.previous` | Selects the previous placeholder. | UNIT: SnippetStackTests.testPreviousStaysOnInnerStops | |
| Snippet › End snippet | Esc | `cancelOperation` → `endSnippet` → `SnippetSession.end` | Leaves the innermost nested snippet, resuming the outer placeholder, or ends the session. It only runs after completion, cheat sheet, signature help, peek and doc panels are closed. | UNIT: SnippetStackTests.testCancelInnerResumesShiftedOuterPlaceholder, testCancelAfterInnerTypingUsesNetInsertedLength | Esc closes the popups first, one per press. |

### Signature help panel (`SignatureHelpController`, `SignatureHelpView`: display only, no buttons)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Signature help › Auto show | type `(` `,` `)` | `SignatureHelpController.textChanged` → `show` | Shows or refreshes the parameter hint while typing a call, when `prefs.signatureHelp` is on. Follows caret moves while visible. | SELFTEST: "outer signature after )" (rust) | |
| Signature help › Hide | Esc | `cancelOperation` → `SignatureHelpController.hide` | Hides the panel. Completion and the cheat sheet are closed first if they are open. | NONE | |
| Signature help › Hide on newline | ↩ | `insertNewline` / `textChanged` (inserted `\n`) → `hide` | Hides the panel on newline. | NONE | |

### Quick Documentation / External Documentation panel (`DocController`, `DocPanel`, `DocWebView`, `CaretPopup`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Doc panel › Pin button | click (pin icon) | `DocPanel.pinClicked` → `DocController.togglePin` → `CaretPopup.togglePin` | Toggles pinned. A pinned panel survives caret moves, typing and clicks. | NONE | ⚠ The "doc pin" selftest calls `DocController.pin()`, a test-only method, instead of `togglePin()` which the button uses. The pin semantics are exercised but not the button handler. |
| Doc panel › Symbol link | click link | `DocWebView` decidePolicy → `DocLinkTarget.item` → `DocController.open(target:)` | Re-fetches docs for the link's last path segment, from the buffer outline or the first text match. | UNIT: DocPageTests.testRideDocTargetKeepsPathWithColons; RUST: tests/outline_docs.rs::quick_doc_resolves_intra_doc_link, quick_doc_unknown_link_stays_code | Cross-file targets only resolve if the name appears in the current buffer. |
| Doc panel › Web link | click http(s) link | `DocWebView` decidePolicy → `NSWorkspace.open` | Opens the URL in the default browser. | NONE | |
| Doc panel › Hide | Esc | `cancelOperation` → `docs.hide()` | Hides the panel even when pinned. Peek is closed first if it is visible. | NONE | |
| Doc panel › Auto hide | caret move / keyDown / click in editor | `docsCaretMoved` / `hideUnpinnedDocs` → `CaretPopup.caretMoved` / `hideIfUnpinned` | Hides an unpinned panel once the caret leaves the identifier it was opened on, or on any key or click. | NONE | The panel is also resizable and can be moved by dragging its background. |

### Quick Definition (peek) panel (`PeekController`, `PeekPanel`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Peek › Open button | click "Open" | `PeekPanel.openClicked` → `PeekController.openIfVisible` | Hides the peek and jumps to the shown excerpt (read-only if outside the workspace). | NONE | |
| Peek › Open | F12 (while peek visible) | Navigate › Go to Definition → `Definitions` → `peek.openIfVisible()` | Opens the current excerpt instead of doing a fresh go-to-definition. | NONE | The button tooltip says "Open (F12)". |
| Peek › Definition segments | click segment | `PeekPanel.segmentChanged` | Switches to another definition, e.g. trait vs impl or prototype vs body. | UNIT: PeekSegmentsTests.testShortListIsUnchanged, testLongListCapsAtEightWithMore, testSelectionClampsWhenCollapsed | |
| Peek › "more" segment | click last segment | `segmentChanged` → `PeekSegments.isMore` | Expands the capped list (8) to show every definition. | UNIT: PeekSegmentsTests.testMoreIsTheLastCappedSegment, testExpandedShowsEverything | |
| Peek › Pin button | click (pin icon) | `pinClicked` → `PeekController.togglePin` | Toggles pinned, so the peek survives caret moves and clicks. | NONE | |
| Peek › Hide | Esc | `cancelOperation` → `peek.hide()` | Hides the peek even when pinned. | NONE | |

### Ask AI sheet (`AIAskSheet`, presented from RootView `.sheet($assistant.showPrompt)`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Ask AI › Prompt editor | — | `TextEditor($assistant.prompt)` | An editable request, pre-filled from the comment at or above the caret. | UNIT: AICommentPromptTests.testCaretOnCommentLineJoinsTheCommentRun, testCommentAboveTheCaretLineIsUsed, testBlockCommentsAndHashComments | |
| Ask AI › Context picker | — | `Picker($assistant.level)` | Chooses the context sent: Code block, Function, File, Directory or Project. It starts from `prefs.aiContext`. | NONE | The choice applies to this request only and is not saved to prefs. |
| Ask AI › Cancel | Esc | `assistant.showPrompt = false` | Closes the sheet without sending. | NONE | |
| Ask AI › Send | ⌘↩ | `AIAssistant.send()` → `AIChatContext.selection` (+ file and directory/project files by level) → `AIChatStore.send` | Starts a chat thread with the request and its context chips and streams the answer into the AI chat panel. Disabled while the prompt is blank. | NONE | ⚠ Return is the default action, but the focused `TextEditor` probably takes ↩ as a newline (not verified). If the captured document or view is gone, it closes the sheet and silently drops the request. |

### AI chat panel and Explain (`AI/Chat/`, added 2026-10-06)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Code › Suggest with AI | ⌥\ | `suggestInline()` → `AIInlineController.trigger` | Requests an inline suggestion at the caret now, whatever the AI suggestions preference; the result is ghost text (⇥ / ⌥⇥ accept, ⌘→ one word, esc dismiss). | SELFTEST: "menu suggest with ai without key"; UNIT: AIInlineGhostTests | Needs the rest of the caret line to be blank. |
| Code › Explain | ⌃⌘E | `explainSelection()` → `AIChatContext.selection` → `engine.aiContext` | New thread with the selection (or the item under the caret), its enclosing item and the definitions it uses, streaming an explanation. | SELFTEST: "menu explain without key"; RUST: tests/ai_context.rs | |
| Code › Explain File | — | `explainFile()` | New thread with the whole file (60k characters, marked truncated beyond). | SELFTEST: "menu explain file without key" | |
| Code › Add Selection to Chat | ⌃⌘L | `addSelectionToChat()` | Adds the selection pack as chips to the next message and focuses the chat input. | SELFTEST: "menu add selection to chat" | |
| Chat › history menu, New Chat, close | — | `AIChatStore.select/delete/newThread`, `showPanel = false` | Switches, deletes or starts threads (in memory for the session). | NONE | |
| Chat › input ↩ / ⇧↩, Send, Stop | ↩ | `sendChat()` / `AIChatStore.stop()` | Sends the message with its chips; Stop cancels the stream and keeps what arrived. | UNIT: AIChatPromptTests | |
| Chat › Selection / File buttons, chip × | — | `addSelectionToChat()`, `addFileToChat()`, `detach` | Attach or remove context for the next message. | NONE | |
| Chat › code block Copy / Insert | — | `rideChat` message → pasteboard / `insertAtCaret` | Copies the block, or inserts it over the selection of the focused editor. | NONE | |
| Chat › `path:line` link and chips | — | `openChatLocation(path:line:)` | Opens the file at that line (workspace-relative or absolute). | UNIT: AIChatLocationTests | |

### Install Tools sheet (`ToolsInstallView`, `CopyCommandButton`; plus `RideCommandRow`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Tools › Row checkbox | — | `Toggle($row.selected)` | Selects a missing, auto-installable tool. Rows that are installed or manual show an icon instead. Disabled while installing. | NONE | By default a row is selected if it has an install command (`ToolsModel.refresh`). |
| Tools › Copy / Copied | — | `CopyCommandButton` | Copies a manual tool's install command. The label changes to "Copied". | NONE | ⚠ `copied` never resets, so it stays "Copied" for the life of the view. The same component is used in Welcome setup. |
| Tools › Don't ask again at launch | — | `Toggle($dontAsk)` | Local state. It is written to `prefs.askMissingTools` only when Close is pressed. | NONE | |
| Tools › Close | Esc | `ToolsInstallView.close()` | Saves the don't-ask preference if it changed and dismisses the sheet. | NONE | |
| Tools › Install Selected | ↩ | `ToolsModel.installSelected()` → `ToolInstaller.run` (`/bin/zsh -lc <cmd>`) | Runs each selected install command in turn, appends output to the log, marks rows installed or failed, then refreshes `toolStatus`. Disabled while installing or when nothing is selected. The label reads "Installing…" while running. | NONE | |
| Settings › Install `ride` command › Install | — | `RideCommand.install()` | Symlinks `/usr/local/bin/ride` to the bundled helper through an admin-privileges AppleScript. | NONE | ⚠ `RideCommandRow` is not part of the Install Tools sheet. It appears only in Settings (`SettingsPanes.swift:73`). |
| Settings › Install `ride` command › Retry | — | `RideCommand.install()` | Retries after a failure and shows the error message next to it. | NONE | Same as Install. |


---

## Run, Debug, Tests, Terminal, Targets

Self-test steps below come from the lists reached through `SelfTestSteps.all`. Where a step is marked "(dev)", it runs only when `DeveloperMode.isEnabled`. Otherwise the list swaps in a "skipped" placeholder. Language list: rust = `rust(...)`, c = `c(...)`, cpp = `cpp(...)`.

### Run menu (`Run/RunCommands.swift`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Run › Build` | ⌘B | `state.runAction(.build)` → `Run/AppState+Run.swift` | Builds a `RunPlan` from the selected target's build argv plus the run config (args, env, sanitizers). It then starts it in Run Output as a `.build` session, and `BuildSession` parses diagnostics into Problems. Enabled when `canBuild` is true, i.e. `runPlan(.build) != nil`: the target has a non-empty build argv. | SELFTEST: "build target" (rust), "build stopped" (rust), "build stop and rerun" (rust), "build diagnostic" (rust, c), "c build" (c), "cpp debug build" (cpp, dev); UNIT: RunPlanTests.testBuildUsesTheTargetBuildArgv, BuildSessionStateTests.testFinishPublishesForItsOwnRun; RUST: tests/build_output.rs::cargo_error_line_yields_one_primary_diagnostic | ⚠ Dirty buffers are not saved first: it relies on the 1 s autosave, so the self-tests call `saveAll()` before building. ⚠ The config "Arguments" are appended to the build argv too (see Run config sheet). |
| `Run › Run` | ⌘R | `state.runAction(.run)` | Runs the selected target's run argv with config args (adding `--` for `cargo run`), env and working dir as a plain session. Enabled when `canRunTarget` is true: the target has a run argv. | SELFTEST: "run target" (rust), "c run" (c); UNIT: RunPlanTests.testRunUsesTheTargetRunArgv, RunPlanTests.testArgsEnvAndBacktraceAreApplied, RunPlanTests.testRunIsNilWithoutARunArgv | ⚠ Does not save dirty buffers first. demo: "run" |
| `Run › Run Tests` | ⇧⌘R | `state.runAction(.test)` | Runs the project's test target, or falls back to `cargo test` / `ctest --test-dir build/<profile>` / `make test`. `TestSession` parses the output into the Tests panel, which opens. Enabled when `canRunTests` is true. | SELFTEST: "run tests" (rust), "test stop and rerun" (rust); UNIT: RunPlanTests.testTestsPreferTheTestTarget, RunPlanTests.testCargoTestFallsBackWithoutATestTarget, RunPlanTests.testCMakeTestsUseCtestWithTheProfile +1 more; RUST: tests/test_output.rs::cargo_output_carries_status_and_failure_text, gtest_output_pairs_run_with_result, ctest_output_attaches_failure_text | ⚠ Uses the *selected run target's* config, so program arguments meant for Run are appended to the test argv (e.g. `cargo test -p x --fast`). demo: "tests" |
| `Run › Run File` | ⌃⇧R | `state.runFile()` → `Run/AppState+RunFile.swift` | Calls engine `singleFileCommand(path:outDir:)` to compile the active file into `~/Library/Application Support/Ride/single/<sha>`. It then chains the run step through `SingleFileChain` once the compile exits cleanly. Enabled when `canRunFile` is true: the extension is c/cpp/cc/cxx/c++/rs. | SELFTEST: "run file error" (cpp; covers only the link-failure path); UNIT: SingleFileRunTests.testSupportedExtensions, SingleFileRunTests.testChainReleasesOnCleanExit, SingleFileRunTests.testChainHoldsOnCompileFailure +8 more; RUST: tests/single.rs::c_file_compiles_and_runs, cpp_file_compiles_and_runs, rust_file_compiles_and_runs | ⚠ Does not save the dirty buffer first. The successful compile→run chain is never asserted in the app. Not listed in the Shortcuts manual. |
| `Run › Recompile File` | ⇧⌘F9 | `state.recompileFile()` | Calls engine `recompileCommand(path:)` to get the compile-database entry for the active file and runs it as a single-file session, so diagnostics are parsed. Enabled when `canRecompileFile` is true: the active buffer has a file URL. | SELFTEST: "recompile file" (c, cpp); RUST: tests/single.rs::recompile_command_comes_from_the_database, project_source_uses_the_database_flags | Enabled for any file, even Rust or Markdown. For those it only shows the notice "No compile database entry for this file". Not listed in the Shortcuts manual. |
| `Run › Stop` | ⌘. | `state.stopRun()` → `Run/AppState+RunOutput.swift` | Cancels the Debug, Build, Test and SingleFile chains and stops the Run Output process group. Enabled when `isRunning` is true (`runOutput.isRunning`). | SELFTEST: "build stopped" (rust); UNIT: ProcessRunnerTests.testStopTerminatesTheWholeProcessGroup, SingleFileRunTests.testChainClearsOnStop, BuildSessionStateTests.testStoppedRunDiscards | Does not end a debug session. That is `Debug › Stop`. |
| `Run › Edit Configurations…` | — | `state.editRunConfig()` | Sets `showRunConfigSheet = true` when a run target exists. The sheet is presented from `RootView`. Enabled when `canBuild` is true. | NONE | ⚠ The enablement (`canBuild`, which needs a build argv) differs from the handler guard (`runTarget != nil`). A target with no build argv cannot open its config. |

### Debug menu (`Menus/DebugCommands.swift`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Debug › Debug` | ⌃⌘R | `state.startDebug()` → `Debug/AppState+Debug.swift` | Resolves the debuggee with `DebugProgram.resolve`. For Cargo that is `<root>/target/<profile>/<name>`; otherwise it is `argv[0]`. It then builds first when possible and uses `DebugChain` to launch `engine.debugLaunch` (lldb-dap) with breakpoints and the enabled exception filters. Enabled when `canDebug && !isDebugging`. | SELFTEST: "debug" (rust, dev), "cpp debug stops in Circle::area" (cpp, dev); RUST: tests/debug_session.rs::the_scripted_session_stops_inspects_and_steps, the_live_adapter_stops_in_the_rust_demo | ⚠ When another process is running, the chain is keyed to `runOutput.runId` (the old run) instead of the new build's id. "Stop and Rerun" then never launches the debugger, and "Cancel" launches it when the old process exits 0. ⚠ The Cargo path ignores `--target <triple>` (sanitizers) and `examples/`, so it can debug a stale or missing binary. demo: "debug", "cppdebug" |
| `Debug › Continue` | ⌥⌘R | `state.debugCommand(.continue)` → `DebugController.send` | Sends DAP `continue` through `engine.debugCommand` and marks the state running. Enabled when `isDebugStopped` is true. | UNIT: RUST: tests/debug_protocol.rs::execution_commands_round_trip | Only the protocol serialisation is tested. No self-test continues. |
| `Debug › Step Over` | F8 | `state.debugCommand(.next)` | Sends DAP `next` (statement granularity). Enabled when stopped. | SELFTEST: "debug step over" (rust, dev); RUST: tests/debug_session.rs::the_scripted_session_stops_inspects_and_steps | Plain F7/F8 are media keys on Mac keyboards unless fn is held or the "standard function keys" setting is on. |
| `Debug › Step Into` | F7 | `state.debugCommand(.stepIn)` | Sends DAP `stepIn`. Enabled when stopped. | UNIT: RUST: tests/debug_protocol.rs::execution_commands_round_trip | Same media-key caveat. |
| `Debug › Step Out` | ⇧F8 | `state.debugCommand(.stepOut)` | Sends DAP `stepOut`. Enabled when stopped. | SELFTEST: "cpp debug step out" (cpp, dev) | — |
| `Debug › Pause` | — | `state.debugCommand(.pause)` | Sends DAP `pause`. Enabled when `isDebugRunning` is true. | UNIT: RUST: tests/debug_protocol.rs::execution_commands_round_trip | Protocol round-trip only. |
| `Debug › Stop` | ⌘F2 | `state.stopDebug()` | Cancels `DebugChain`, sets the state to terminated and sends `disconnect` in the background. Enabled when `isDebugging` is true. | SELFTEST: "debug stop" (rust, dev), "cpp debug stop" (cpp, dev); RUST: tests/debug_session.rs::a_disconnect_kills_an_adapter_that_never_answers, a_disconnect_terminates_once_and_leaves_the_registry_once | It is disabled while the pre-debug build runs (the session is not active yet). Only `Run › Stop` cancels at that point. |
| `Debug › Toggle Breakpoint` | ⌘F8 | `state.toggleBreakpointAtCaret()` → `Debug/AppState+Breakpoints.swift` | Toggles a breakpoint on the caret line of the focused editor, re-syncs it to a live session (`debugSetBreakpoints`), refreshes the gutters and saves the workspace. Enabled when `hasEditor` is true. | SELFTEST: "breakpoint toggle" (rust), "breakpoint persists" (rust), "cpp debug breakpoint" (cpp, dev), "breakpoint shift prep" (rust); UNIT: BreakpointsTests.testToggleAddsAndRemoves, BreakpointsTests.testMarksAreSortedAndUnique; RUST: tests/debug_session.rs::breakpoints_can_be_edited_while_the_session_runs | Untitled buffers are a silent no-op. There is no path. |
| `Debug › Debug Panel` (toggle) | ⌘3 | `state.toggleDebugPanel()` → `Debug/AppState+DebugPanel.swift` | Flips `DebugPanelModel.visible` and syncs the menu. The checkmark is `menu.showDebugPanel`. | SELFTEST: "debug panel toggle" (rust), "debug watch persists" (rust) | — |
| `Debug › Evaluate Expression…` | ⌥F8 | `state.showEvaluateSheet()` | Shows the Debug panel and sets `showEvaluate` so the Evaluate sheet opens. Enabled when stopped. | NONE | — |
| `Debug › <exception filter>` (dynamic toggles, e.g. "C++ Throw", "C++ Catch") | — | `state.toggleExceptionFilter(id:)` → `DebugFilters.toggle` | The toggles are loaded once from engine `debugExceptionFilters()`, which probes lldb-dap. They flip `enabled`, and the enabled ids are sent on the *next* `debugLaunch`. | UNIT: RUST: tests/debug_session.rs::the_adapter_advertises_its_exception_filters, the_launch_sends_only_the_advertised_enabled_filters | ⚠ A toggle during a live session does not reach the adapter (no `setExceptionBreakpoints`). ⚠ The toggles are not persisted in the workspace and reset to adapter defaults every launch. When lldb-dap is missing, the menu has no entries (no hint shown). |

### Run output panel (`Run/RunOutputPanel.swift`, `RunOutputText.swift`, `ConsoleLinks.swift`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Run header › Stop` (stop.fill) | — | `output.stop()` → `RunOutput.stop` | Clears any queued rerun and stops the process group. Disabled when not running. | SELFTEST: "build stopped" (rust; reaches `runOutput.stop()` through `stopRun`) | It bypasses `state.stopRun()`, so it does not cancel the chains. The signalled finish still drops them, so the effect is equivalent. |
| `Run header › Rerun` (arrow.clockwise) | — | `state.rerunOutput()` | Restarts `runOutput.lastRequest` with its original session kind. Disabled while running or when nothing has run. | NONE | ⚠ After `Run File`, `lastRequest` is the chained *run* step, so Rerun re-executes the old binary without recompiling. After `Debug`, it reruns only the build, not the debugger. |
| `Run header › Clear` (trash) | — | `output.clear()` | Empties the buffer and status. It works even while running. | SELFTEST: "run output close" (rust); UNIT: RunOutputBufferTests.testClearResetsSequence, RunOutputBufferTests.testPlanResetsOnRestyleAndOnClear | — |
| `Run header › Hide Run` (xmark) | — | `state.showRunOutput = false` | Hides the panel. The process keeps running. | SELFTEST: "run output close" (rust) | — |
| `Run output › click file:line link` | — | `RunOutputCoordinator.textView(_:clickedOnLink:)` → `state.openConsoleLink` | `ConsoleLinks` finds `path.ext:line[:col]` for known source extensions. A click opens the file at that line, resolved against the run's working dir or the workspace, and read-only when outside the workspace. | SELFTEST: "run output link" (rust; calls `openConsoleLink` directly); UNIT: ConsoleLinksTests.testRelativePathWithLineAndColumn, ConsoleLinksTests.testClangStyleDiagnostic, ConsoleLinksTests.testRelativePathResolvesAgainstRoot +7 more | The column is parsed but ignored when opening (`.line` only). The click and decode path (`RunOutputRender.decode`) is not tested. Missing files are a silent no-op. |

### Run configuration sheet (`Run/RunConfigSheet.swift`, `RunConfigDraft.swift`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Run Config › Arguments` field | — | `draft.args` → `RunArgs.split` on save | Quote-aware split into `config.args`. They are appended to **build, run, test and debug** argv, with `--` added only for `cargo run`. | UNIT: RunPlanTests.testArgsEnvAndBacktraceAreApplied, RunPlanTests.testBuildArgsNeedNoSeparator | ⚠ One field means Cargo flags for Build and Test (e.g. `--release`) but program args for Run and Debug. A program arg breaks `cargo build`, and a Cargo flag goes to the program on Run. `RunArgs.split` and `join` have no unit test. |
| `Run Config › Working Directory` field | — | `draft.workingDir` | Overrides the plan cwd. An empty value means the target's working dir. | UNIT: RunPlanTests.testArgsEnvAndBacktraceAreApplied, RunConfigTests.testDefaultConfigHasNoArgsAndInheritsWorkingDir | No folder chooser and no validation. A bad path fails only at spawn. |
| `Run Config › RUST_BACKTRACE=1` toggle | — | `draft.rustBacktrace` | Adds `RUST_BACKTRACE=1` to the env of every action. | UNIT: RunPlanTests.testArgsEnvAndBacktraceAreApplied | It is shown for C/C++ projects too, where it is harmless. |
| `Run Config › address` toggle | — | `binding(for: .address)` | Cargo: `RUSTFLAGS=-Zsanitizer=address` plus `--target <host>`. CMake: computes `-DCMAKE_CXX_FLAGS=-fsanitize=address`. | UNIT: RunConfigTests.testCargoSanitizerFlagsUseRustflagsAndHostTriple, RunPlanTests.testSanitizersAddTheTargetTripleAndRustflags | ⚠ CMake flags are computed but never applied. `RunPlanner` appends `flags.args` only for Cargo, and the engine's `cmake configure` (src/project/cmake.rs) takes no sanitizer flags. `docs/product/feature-inventory.md` claims "at configure time". ⚠ For Make and compile-db projects the toggles show but do nothing. |
| `Run Config › undefined` toggle | — | `binding(for: .undefined)` | Same flow with `undefined`. | UNIT: RunConfigTests.testCargoSanitizerFlagsUseRustflagsAndHostTriple | ⚠ `-Zsanitizer=undefined` is not a rustc sanitizer, so a Cargo build fails. The unit test asserts this invalid flag. Same CMake no-op. |
| `Run Config › thread` toggle | — | `binding(for: .thread)` | Same flow with `thread`. | UNIT: RunConfigTests.testCMakeSanitizerFlagsAreConfigureArguments | Same CMake no-op. address+thread can be combined, which the toolchains reject. |
| `Run Config › Environment › Add` | — | `rows.append(RunConfigEnvRow())` | Adds an empty KEY/value row. | NONE | — |
| `Run Config › Environment row KEY / value` fields | — | `$row.key` / `$row.value` | Rows with a non-empty key become `config.env` and are merged over the sanitizer env. | UNIT: RunPlanTests.testArgsEnvAndBacktraceAreApplied | The draft→config mapping (`RunConfigDraft.config`) is untested. Duplicate keys: the last wins silently. |
| `Run Config › Environment row remove` (minus.circle) | — | `rows.removeAll { id }` | Deletes the row. | NONE | — |
| `Run Config › Cancel` | Esc | `state.showRunConfigSheet = false` | Closes without saving. | NONE | — |
| `Run Config › Save` | ↩ | `save()` → `state.saveRunConfig` | Merges the config by target name into `runConfigs`, which is persisted in the workspace state. | UNIT: RunConfigTests.testMergedReplacesTheConfigForTheSameTarget, RunConfigTests.testWorkspaceStateCarriesRunConfigsAndSelectedTarget, RunConfigTests.testRoundTripsThroughJson | Configs are keyed by name only. A bin and the test target of the same crate (both "ride-demo") share one config. |

### Tests panel (`Tests/TestsPanel.swift`, `TestTreeList.swift`, `TestMarkers.swift`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Tests header › Filter` field | — | `$store.filter` → `TestTree.groups(filter:)` | Filters rows by suite or name substring. | UNIT: TestTreeTests.testFilterMatchesSuiteAndName | — |
| `Tests header › Rerun Failed` (arrow.clockwise) | — | `state.rerunFailedTests()` → `Tests/AppState+Tests.swift` | Builds a filtered command (`cargo test -- --exact names`, `--gtest_filter=`, catch2 names, `ctest -R`) with `TestFilterCommand` and runs it as a test session. Disabled while running or when there are no failures. | UNIT: TestTreeTests.testCountsAndFailedNames, TestTreeTests.testFailedNamesAreQualifiedPerFramework, TestTreeTests.testFilterCommandPerFramework | — |
| `Tests header › Clear` (trash) | — | `store.clear()` | Clears rows, status, command and framework. | NONE | It is not disabled while running, and the next parse republishes the rows. |
| `Tests header › Hide Tests` (xmark) | — | `state.showTests = false` | Hides the panel. | NONE | — |
| `Tests list › row click` | — | `selected = row.id` | Selects the test and shows its captured output in the right pane. | NONE | There is no context menu, no jump-to-source and no per-row run. |
| `Gutter › run marker click` (marker column) | — | `GutterView.mouseDown` → `state.runTestMarker` | Runs one test through `TestFilterCommand` for its framework. For a marker with no framework (`fn main`), it calls `runAction(.run)`. Markers come from engine `testMarkers`. | UNIT: TestTreeTests.testFilterCommandPerFramework; RUST: tests/test_markers.rs::rust_test_functions_are_module_qualified, rust_file_scope_test_and_main, cpp_macros_carry_their_framework | ⚠ The `main` marker runs the *selected* target, not the binary that owns this `main` (e.g. `src/bin/other.rs`). The self-test "gutter run markers" (rust) only asserts that markers exist and never clicks one. |

### Debug panel (`Debug/DebugPanel.swift`, `DebugPanelLists.swift`, `DebugWatchesList.swift`, `VariableTree.swift`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Debug header › Evaluate Expression` (plus.magnifyingglass) | — | `model.showEvaluate = true` | Opens the Evaluate sheet. Disabled unless stopped. | NONE | Its help says "(⌥F8)", which matches the menu. |
| `Debug header › Hide Debug` (xmark) | — | `model.visible = false` | Hides the panel. | NONE | ⚠ It bypasses `toggleDebugPanel()`, so `syncMenu()` is not called and the `Debug › Debug Panel` checkmark stays on until the next sync. |
| `Debug frames › thread picker` | — | `model.selectThread(id)` → `reloadFrames` | Loads the stack for the chosen thread (`engine.debugStack`) and selects its top frame. | UNIT: RUST: tests/debug_session.rs::the_scripted_session_stops_inspects_and_steps; UNIT: DebugLoadStateTests.testSelectionKeepsUnscopedLoads | The picker is never driven by a self-test. Auto-selection on stop goes through `apply(threads:)`. |
| `Debug frames › frame row click` | — | `model.selectFrame(id)` (jump: true) | Loads the frame's scopes and variables, refreshes watches and jumps the editor to the frame location (`onFrame` → `showDebugLocation`). | SELFTEST: "cpp debug vector local" (cpp, dev; `selectFrame(jump: false)`); UNIT: DebugLoadStateTests.testSelectingAnotherFrameDropsTheOldFramesChildren | The editor jump (`jump: true`) is untested. |
| `Debug variables › row click` (expand/collapse) | — | `model.toggle(row)` → `loadChildren` | Toggles expansion and lazily fetches a page of 100 children (`engine.debugVariables`). | SELFTEST: "cpp debug vector local" (cpp, dev), "debug panel loads variables" (rust, dev; auto-expanded first scope); UNIT: VariableTreeTests.testRootsAreTheOnlyRowsUntilExpanded, VariableTreeTests.testCollapseHidesChildrenButKeepsThemLoaded | — |
| `Debug variables › more…` | — | `model.loadMore(node)` | Fetches the next page of children. | UNIT: VariableTreeTests.testPagingStopsWhenTheCountIsReached, VariableTreeTests.testAShortPageEndsThePaging, VariableTreeTests.testAppendIgnoresDuplicateIds | — |
| `Watches › expression field (Return) / + Add Watch` | ↩ | `add()` → `model.addWatch` | Adds a trimmed, de-duplicated watch, evaluates it in the selected frame (`engine.debugEvaluate`, watch context) and saves the workspace. | SELFTEST: "debug watch persists" (rust); RUST: tests/debug_session.rs::the_scripted_session_stops_inspects_and_steps | The watch list is visible only while stopped, because the whole panel body is hidden otherwise. |
| `Watches › row Remove Watch` (xmark) | — | `model.removeWatch(id:)` | Removes the watch and saves the workspace. | NONE | It is called and asserted only inside the *check* closure of "debug watch persists", not its run closure. |

### Evaluate sheet (`Debug/DebugEvaluateSheet.swift`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Evaluate › Evaluate` button / Return in field | ↩ | `evaluate()` → `model.evaluate(_, context: .repl)` | Evaluates the expression in the selected frame through `engine.debugEvaluate` and shows `value · type` or the error text. It shows "not stopped" when there is no frame or the stop has changed. | UNIT: RUST: tests/debug_protocol.rs::evaluate_contexts_round_trip, tests/debug_protocol.rs::variables_and_evaluate_round_trip, tests/debug_session.rs::the_scripted_session_stops_inspects_and_steps | Errors are shown in the same colour as values. |
| `Evaluate › Watch` | — | `model.addWatch(expression)` | Adds the expression as a watch. Disabled when the field is empty. | SELFTEST: "debug watch persists" (rust; same `addWatch`) | A whitespace-only expression enables the button, but `addWatch` then does nothing. |
| `Evaluate › Close` | Esc | `model.showEvaluate = false` | Dismisses the sheet. | NONE | — |

### Breakpoint gutter and editor (`Editor/GutterView.swift`, `Debug/BreakpointEditor.swift`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Gutter › click number/breakpoint column` | — | `GutterView.mouseDown` → `state.toggleBreakpoint(path:line:)` | Adds or removes a breakpoint on that line and syncs a live session. | SELFTEST: "breakpoint clear" (rust), "cpp debug step out" (cpp, dev; removes one); UNIT: BreakpointsTests.testToggleAddsAndRemoves | — |
| `Gutter › right-click number/breakpoint column` | — | `GutterView.rightMouseDown` → `state.editBreakpoint` | Opens the breakpoint editor when a breakpoint exists. Otherwise it *adds* a breakpoint. | NONE | ⚠ This is the only entry point: no menu item or context menu leads to the editor. Right-clicking an empty line silently toggles a breakpoint on instead of showing a menu. |
| `Breakpoint editor › Condition` field | — | `BreakpointEditor.run` (NSAlert) | Sets the DAP condition, e.g. `i == 3`. | UNIT: BreakpointsTests.testEditKeepsLineAndTrims; RUST: tests/debug_session.rs::breakpoints_can_be_edited_while_the_session_runs | ⚠ The editor has only condition and hit count. It has no log message, no enable/disable and no remove button. In demo mode it returns nil (no-op). |
| `Breakpoint editor › Hit count` field | — | same | Sets the DAP hitCondition, e.g. `>5`. | UNIT: BreakpointsTests.testEditKeepsLineAndTrims | — |
| `Breakpoint editor › Save` | ↩ | `debug.breakpoints.edit(...)` → `breakpointsChanged` | Stores the condition and hit count, re-syncs the session, refreshes the gutters and saves. | UNIT: BreakpointsTests.testEditKeepsLineAndTrims, BreakpointsTests.testEditOnMissingLineDoesNothing, BreakpointsTests.testRoundTripsThroughJSON | The gutter does not mark conditional breakpoints differently. |
| `Breakpoint editor › Cancel` | Esc | returns nil | Leaves the breakpoint unchanged. | NONE | — |

### Debug hover (`Debug/DebugHover.swift`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Editor › hover word while stopped` | — | `HoverController.fire` → `DebugHover.request` → `model.evaluate(_, .hover)` | While stopped with a selected frame, it shows `expr = value` with the type in place of the definition hover. | UNIT: RUST: tests/debug_protocol.rs::evaluate_contexts_round_trip | ⚠ The request returns `started = true` before the result is known. When the evaluation fails or is empty (keywords, types, functions), nothing is shown, and the normal definition hover is suppressed for the whole stop. |

### Terminal panel (`Terminal/TerminalPanel.swift`, `TerminalTabStrip.swift`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Terminal header › New Terminal` (plus) | — | `state.newTerminal()` → `openTerminal(directory: workspaceRoot)` | Shows the panel, applies the theme and font, spawns a login shell tab in the workspace root and focuses it. | SELFTEST: "terminal open" (rust; same `openTerminal`); UNIT: TerminalTabsTests.testAddSelectsNewTab, TerminalTabsTests.testTitleForDirectory | It opens in the workspace root, not the active project root. demo: "terminal" |
| `Terminal header › Hide Terminal` (xmark) | — | `state.showTerminal = false` | Hides the panel. The shells keep running. | SELFTEST: "terminal close" (rust) | — |
| `Terminal empty state › New Terminal` button | — | `state.newTerminal()` | Same as the + button, shown when no tab exists. | SELFTEST: "terminal open" (rust) | — |
| `Terminal tabs › tab click` | — | `state.selectTerminal(id)` | Selects the tab and focuses its session. | UNIT: TerminalTabsTests.testSelectAndRenameIgnoreUnknownIds, TerminalTabsTests.testCloseOtherTabKeepsSelection | — |
| `Terminal tabs › Close Terminal` (xmark) | — | `store.close(id)` | Terminates the shell, removes the tab and selects the neighbour. | SELFTEST: "terminal close" (rust; `terminals.close`); UNIT: TerminalTabsTests.testCloseSelectedFallsBackToNeighbour, TerminalTabsTests.testCloseOtherTabKeepsSelection | The newly selected tab is not focused (`focusSelected` is not called). |

### Toolbar (`Design/AppToolbar.swift`, `Project/TargetPicker.swift`)

The toolbar has **no Run, Stop or Debug buttons**. Its items are Toggle Sidebar, Target picker, Markdown Preview, Check, Problems and Open Quickly.

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Toolbar › Toggle Sidebar` (sidebar.left) | (⌘1 in help) | `state.showSidebar.toggle()` | Shows or hides the project sidebar. | NONE | — |
| `Toolbar › Target picker › Project › <project>` (toggle) | — | `store.choose(root:)` | Makes that sub-project active. Targets, profiles and notice are reloaded from its model. Shown only when the folder has 2 or more projects. | NONE | Ticking the already-active project is a no-op, and it cannot be unticked. |
| `Toolbar › Target picker › <group> › <target>` | — | `state.selectTarget(row)` → `projectModel.select` + `scheduleWorkspaceSave` | Selects the target used by Build, Run, Debug and Edit Configurations, and persists it. The label shows `defaultRow`, which is the selected target, else the first bin, lib or row. | SELFTEST: "target selection restore" (rust); UNIT: TargetRowsTests.testGroupsFollowKindOrderAndSkipEmptyKinds, TargetRowsTests.testRowsAreSortedByDisplayNameWithinAGroup +3 more | "project targets" (rust) also calls `selectTarget`, but inside its check closure. demo: "targets" |
| `Toolbar › Markdown Preview` (doc.richtext) | (⇧⌘V in help) | `state.togglePreview()` | Toggles the preview pane. Shown only when `previewAvailable` is true. | NONE | — |
| `Toolbar › Check` (play.circle) | (⌥⌘B in help) | `state.runCheck()` → `CheckService.run(file:)` / `run(root:)` | Runs clang on the active C/C++ file, else a project check on the active project root. Disabled without a workspace. | UNIT: RUST: tests/check.rs::parses_primary_spans_only, machine_applicable_children_become_fixes | ⚠ The play icon reads as "Run" but runs Check. ⚠ The toolbar disables it without a workspace, while `Build › Check` has no `.disabled`, so the enablement differs. |
| `Toolbar › Problems` (exclamationmark.triangle) | (⌘6 in help) | `state.toggleProblems()` | Toggles the Problems panel. | NONE | — |
| `Toolbar › Open Quickly` (magnifyingglass) | (⌘P in help) | `state.toggleQuickOpen()` | Toggles the quick-open palette. Disabled without a workspace. | NONE | — |

### Targets panel (`Project/TargetsPanel.swift`, `ProjectSwitcher.swift`)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Targets › project switcher` picker | — | `store.choose(root:)` | Switches the active sub-project, the same as the toolbar project toggles. Shown with 2 or more projects. | NONE | The active project also follows the focused editor file (`focus(file:)`), so a manual choice is overridden by the next file switch into another project. |
| `Targets › profile picker` (Debug/Release/RelWithDebInfo, debug/release) | — | `$store.profile` | Sets `ProjectModelStore.profile`. It is only read by the ctest fallback (`build/<profile>`) and the Cargo debug binary path (`target/<profile>`). | NONE | ⚠ It does not reload or configure CMake targets, which stay on `build/Debug`, and it adds no `--release` for Cargo. Build and Run ignore it, and Cargo Release makes Debug look for `target/release/<name>`, which was never built. ⚠ There is no `onChange` call, so the menu enablement is not re-synced. The profile is not persisted in the workspace. |
| `Targets › target row click` | — | `store.select(row)` | Selects the target (highlighted) and syncs the menu. The hover tooltip shows the build command. | SELFTEST: "target selection restore" (rust; via `selectTarget` → `projectModel.select`) | ⚠ It bypasses `state.selectTarget`, so `scheduleWorkspaceSave()` is not called. A target picked in the sidebar is not persisted, unlike the toolbar picker. |


### Git menu (`Git/GitCommands.swift`, added 2026-10-06)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| `Git › Changes` | ⌘0 | `toggleGit()` → `Git/AppState+Git.swift` | Toggles the Changes panel; showing it refreshes status, the diff and the branch list. Enabled with a workspace. | SELFTEST: "menu git changes toggle", "menu git changes restore" | |
| `Git › Commit…` | ⌘K | `showGitCommit()` | Opens the Changes panel and focuses the commit message. Enabled inside a repository. | NONE | Exempt from menu coverage: it would commit into the repository under test. |
| `Git › Push` | ⇧⌘K | `gitPush()` → `Git/AppState+GitOps.swift` → `engine.gitPush` | Pushes; without an upstream pushes `HEAD` to `origin` (or the first remote) and sets it. Notice with git's last line. | RUST: tests/git.rs::push_sets_the_upstream_and_pull_fast_forwards, push_without_a_remote_says_so | Exempt from menu coverage. |
| `Git › Pull` | — | `gitPull()` → `engine.gitPull` | `pull --ff-only`. | RUST: tests/git.rs::push_sets_the_upstream_and_pull_fast_forwards | Exempt from menu coverage. |
| `Git › Fetch` | — | `gitFetch()` → `engine.gitFetch` | `fetch --prune`. | NONE | Exempt from menu coverage. |
| `Git › New Branch…` | — | `gitNewBranch()` → `TreePrompt.name` → `engine.gitCreateBranch(checkout: true)` | Prompts for a name, creates the branch and switches to it. | RUST: tests/git.rs::branches_create_switch_and_reject_bad_names | Exempt from menu coverage. |
| `Git › Refresh Status` | — | `refreshGit()` | Reloads status now instead of waiting for the file watcher. | NONE | Exempt from menu coverage. |

### Changes panel (`Git/GitPanel.swift`, `GitChangeList`, `GitChangeRow`, `GitCommitBox`, `GitDiffView`, `GitBranchMenu`)

| Control | Handler | What it does | Coverage |
|---|---|---|---|
| Branch menu › New Branch… / Fetch / a branch | `gitNewBranch()` / `gitFetch()` / `gitCheckout(branch)` | Creates and switches, fetches, or switches to a local branch (`switch`) or a remote one (`switch --track`). | RUST: tests/git.rs::branches_create_switch_and_reject_bad_names |
| Pull / Push buttons | `gitPull()` / `gitPush()` | Same as the menu items. | RUST (see menu) |
| Refresh, close (×) | `refreshGit()` / `showGit = false` | | NONE |
| Section Stage All / Unstage All | `gitStage(paths)` / `gitUnstage(paths)` | Stages every unstaged file or unstages every staged one. | RUST: tests/git.rs::stage_and_unstage_work_before_the_first_commit |
| Row checkbox | `gitStage` / `gitUnstage` | Moves one file between sections. | RUST (as above) |
| Row click / double-click | `selectGitChange` / `openGitChange` | Shows that side's diff / opens the file. | RUST: tests/git.rs::diffs_cover_unstaged_staged_and_untracked_sides |
| Row menu › Open File, Stage/Unstage, Discard Changes…, Copy Path | `openGitChange`, `gitStage`/`gitUnstage`, `gitDiscard` (confirms), `TreeActions.copyPath` | Discard restores tracked files from the index and deletes untracked ones. | RUST: tests/git.rs::discard_restores_tracked_and_removes_untracked_files |
| Amend checkbox | `gitAmendChanged()` | Loads the last message into an empty box. | RUST: tests/git.rs::commit_amend_and_last_message |
| Commit / Commit All / Amend, … and Push | `gitCommit(push:)` | Commits the staged files (all files when none are staged), then pushes when asked; clears the box. | RUST: tests/git.rs::commit_amend_and_last_message |
| Status bar branch segment | `toggleGit()` | Shows the branch (or `detached at <sha>`) with ↑ahead ↓behind and toggles the panel. | NONE |


---

## Editor keys, mouse, tabs, status bar, welcome, entry points

Scope notes: the app has no `addLocalMonitorForEvents` and no `performKeyEquivalent` overrides. The only `keyDown` overrides are `RideTextView+Keys.swift` (below) and `Workspace/TreeKeyView.swift` (tree, covered elsewhere). SwiftUI `.onKeyPress(↑/↓)` in the pickers is also covered elsewhere. AppKit sends menu key equivalents before `keyDown`, so a `keyDown` branch for a key the menu also binds never runs while that menu item is enabled.

### Editor keyboard (RideTextView)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Editor › Tab (caret or single-line selection) | ⇥ | `insertTab` → `RideTextView+Keys.swift` | If no popup or snippet is active, inserts `tabWidth` spaces (a real `\t` in Makefiles) over the selection. | SELFTEST: "tab inserts spaces" (rust, c, cpp) | A single-line selection gets replaced, not indented. No test covers the Makefile `\t` branch. |
| Editor › Tab (multi-line selection) | ⇥ | `indentSelection(unindent:false)` → `LineOps.indent` (`+Typing.swift`) | Indents every touched line by one unit and keeps the selection. | SELFTEST: "indent keeps selection" (rust, c, cpp); UNIT: LineOpsTests.testIndentShiftsEveryTouchedLine, LineOpsTests.testIndentWithTabsForMakefiles | Same logic as Code › Indent, which has no shortcut. |
| Editor › Shift-Tab | ⇧⇥ | `insertBacktab` → `snippetPrevious()` or `indentSelection(unindent:true)` → `LineOps.unindent` | Unindents the touched lines by up to `tabWidth` spaces or one tab. Works with a bare caret too. | SELFTEST: "unindent keeps selection" (rust, c, cpp); UNIT: LineOpsTests.testUnindentRemovesUpToWidthOrOneTab | The `super.insertBacktab` fallback runs only when the view has no binding. |
| Editor › Tab / Shift-Tab inside an inserted snippet | ⇥ / ⇧⇥ | `CompletionSession.snippetNext/Previous` (`CompletionSession+Snippet.swift`) | Moves to the next or previous placeholder. Past the last stop the snippet ends. | UNIT: SnippetStackTests.testSingleSnippetWalksStopsThenFinishesAtFinalCaret, SnippetStackTests.testPreviousStaysOnInnerStops, SnippetStackTests.testNestedPushSelectsInnerStop +10 more | While a snippet is active, Tab never indents or inserts. Esc ends the snippet. |
| Editor › Return | ↩ | `insertNewline` → `smartNewline()` → `SmartIndent.newline` | Accepts the completion if the popup is open. Otherwise hides signature help and inserts a newline that keeps indent, adds a unit after an opener, splits `{}` and continues comments. | SELFTEST: "smart newline" (rust); UNIT: SmartIndentTests.testNewlineKeepsIndentation, SmartIndentTests.testNewlineAddsAUnitAfterOpeners, SmartIndentTests.testNewlineBetweenBracesOpensABlock +2 more | With a selection the smart path is skipped and a plain newline replaces the selection. Only `#` is passed as `lineComment`; SmartIndent handles `//` itself. |
| Editor › type `}` on a whitespace-only line | } | `insertText` → `SmartIndent.closingBrace` | Dedents the line to match its opener, then inserts `}`. Also hides completion. | SELFTEST: "closing brace dedent" (rust); UNIT: SmartIndentTests.testClosingBraceDedentsAWhitespaceOnlyLine, SmartIndentTests.testClosingBraceLeavesOtherLinesAlone | — |
| Editor › type an opener or quote | ( [ { " ' | `insertText` → `BracketPairing.onType` → `.insertPair` | Inserts the matching closer and puts the caret between the pair. Depends on context (before whitespace or closers; quotes respect identifiers, escapes and Rust lifetimes). | SELFTEST: "bracket pairing" (rust); UNIT: BracketPairingTests.testOpenersPairBeforeNothingWhitespaceOrClosers, BracketPairingTests.testQuotesRespectIdentifiersEscapesAndRustLifetimes | Only for single-character typing with `editSource == .user`. Pastes and IME text skip it. |
| Editor › type a closer in front of its twin | ) ] } " ' | `BracketPairing.onType` → `.typeOver` | Moves the caret past the existing closer instead of inserting another. | UNIT: BracketPairingTests.testClosersTypeOverTheirTwin | — |
| Editor › type an opener with text selected | ( [ { " ' | `BracketPairing.onType` → `.wrap` | Wraps the selection in the pair and keeps the inner text selected. | UNIT: BracketPairingTests.testSelectionsGetWrapped | — |
| Editor › Backspace inside an empty pair | ⌫ | `deleteBackward` → `BracketPairing.deletesPair` | Deletes both characters of `()`, `""` and similar pairs. | SELFTEST: "pair backspace" (rust); UNIT: BracketPairingTests.testBackspaceDeletesAnEmptyPair | — |
| Editor › typing identifier or trigger characters | a–z, `.`, `::`, `->` … | `EditorCoordinator.textDidChange` → `assist` → `CompletionSession.textChanged` | Narrows an open list or schedules a completion fetch when `CompletionTriggerGate.trigger` fires. Deletions re-evaluate. Also notifies the AI source. | UNIT: CompletionTriggerTests.testRustTriggers, CompletionTriggerTests.testCTriggers, CompletionTriggerTests.testIdentifierCharacters +3 more; CompletionNarrowingTests.testHumpMatch +4 more | Needs `prefs.completions` and a language with completions. |
| Editor › type `(` `,` `)` | ( , ) | `assist` → `SignatureHelpController.textChanged` | Shows signature help for the enclosing call. A newline hides it. | SELFTEST: "outer signature after )" (rust); RUST: tests/edits_and_signatures.rs::signature_help_outer_call_after_inner_close, tests/edits_and_signatures.rs::signature_help_from_buffer_and_catalog | Needs `prefs.signatureHelp` and `language.hasSignatureHelp`. |
| Editor › typing while the cheat sheet is pinned | any | `assist` → `CheatSheetController.textChanged` | Fetches the cheat sheet again for the new caret context. | RUST: tests/cheatsheet.rs::rust_contexts, tests/cheatsheet.rs::c_contexts | — |
| Editor › Switch header/source (keyDown) | ⌃⌥↑ | `keyDown` → `state.switchHeaderSource()` | Opens the sibling header or source file (C/C++ via `SiblingSource`). | SELFTEST: "header source switch" (cpp) | ⚠ Hidden shortcut: not in the menu (the menu uses F10), not in `Shortcuts.swift`, not in the manual. |
| Completion popup › move selection | ↑ / ↓ | `handleCompletionKey` → `popup.move(±1)` | Moves the highlighted row. | NONE | ⚠ Modifiers are ignored: ⇧↑ and ⌘↑ move the list instead of extending the selection or jumping to the document start. ⌥↑ is taken by the Extend Selection menu item. |
| Completion popup › accept | ↩ / ⌅ / ⇥ | `handleCompletionKey` → `CompletionSession.accept()` (`CompletionAccept.swift`) | Replaces the prefix with the item, expanding snippets. Also adds an auto-import, closes `#include`, and opens signature help for callables. | UNIT: SnippetParserTests.testPlaceholdersWithDefaults, SnippetParserTests.testFinalStopInsideText +3 more; RUST: tests/completion_sites.rs::import_edit_inserts_sorted_into_the_last_use_block | `insertTab` and `insertNewline` also call `accept()`, but `keyDown` has already handled Tab and Return, so those calls are redundant. |
| Completion popup / cheat sheet › close | Esc | `handleCompletionKey` → `hide()`; `handleCheatSheetKey` → `cancelPopups()` | Hides the completion popup (and the cheat sheet when it has focus). | NONE | — |
| Cmd-I in completion popup | ⌘I | `handleCompletionKey` → `DocController.showCompletion(in:)` | Opens the quick-doc panel for the highlighted item. | SELFTEST: "completion doc" (rust) | Only while the popup is visible. No menu item uses ⌘I. |
| Cheat sheet › move selection | ↑ / ↓ (⌥↑ / ⌥↓ when completion is also open) | `handleCheatSheetKey` → `sheet.move(±1)` | Moves the cheat-sheet row. When both popups are open, the sheet takes keys only if it has focus or ⌥ is held. | UNIT: CheatSheetRowsTests.testStepSkipsHeadersAndClamps, CheatSheetRowsTests.testSelectionKeepsNameOrFallsBackToFirstEntry | ⚠ ⌥↑ and ⌥↓ are Edit › Extend / Shrink Selection. The menu wins, so the ⌥ route never reaches the sheet. |
| Cheat sheet › insert entry | ↩ / ⌅ / ⇥ (⌥ variants) | `handleCheatSheetKey` → `sheet.insert()` | Inserts the entry's snippet, pushed onto the snippet stack. | UNIT: SnippetStackTests.testCheatSheetInsertPushesOntoOuterStack | ⚠ ⌥↩ is Code › Show Intention Actions, so the ⌥↩ route is shadowed. |
| Editor › Esc chain | Esc | `cancelOperation` (`+Keys.swift`) | Closes the first of: completion or cheat sheet → signature help → peek → docs → active snippet. If none is open it calls `super`. | NONE | ⚠ The fallback `super.cancelOperation` is NSTextView's default. In AppKit that runs `complete:` (the system word-completion list), and nothing overrides `complete:` or `completions(forPartialWordRange:)`. Not checked at runtime. |
| Popup navigation via Emacs keys | ⌃P / ⌃N | `doCommand(by:)` for `moveUp:` / `moveDown:` | Moves within the cheat sheet or completion list. | NONE | Arrow keys are handled earlier in `keyDown`, so these branches run only for the ⌃P/⌃N key bindings. The navigation logic is duplicated. |
| Editor › any key press | any | `keyDown` → `HoverController.hide()`, `hideUnpinnedDocs()` | Hides the hover panel and any unpinned docs or peek. | NONE | Arrow keys also dismiss an unpinned peek. |
| Edit › Copy with no selection | ⌘C | `copy` override (`RideTextView+Clipboard.swift`) | Copies the whole current line, including its newline. | NONE | — |
| Edit › Cut with no selection | ⌘X | `cut` override | Copies the current line and deletes it. | NONE | — |
| Edit › Paste / Paste as Rich Text | ⌘V | `paste` / `pasteAsRichText` → `pasteAsPlainText`; `insertText` → `LineEndings.normalized` | Always pastes plain text with CR and CRLF turned into LF. Services input goes the same way (`readSelection`). | UNIT: LineEndingsTests.testNormalizedTurnsCRLFAndLoneCRIntoLF | Multi-character input skips bracket pairing and reindent (no format on paste). |

### Editor mouse and gutter

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Editor › Cmd-click symbol | ⌘-click | `mouseDown` → `hooks.goToDefinition` → `AppState.goToDefinition(document:view:utf16:)` (`Definitions.swift`) | Puts the caret at the click, looks up definitions (`engine.findDefinitions`) and opens the first hit via `HitNavigation.open`. | RUST: tests/definition.rs::local_definition_comes_first, tests/definition.rs::qualified_path_narrows_hits, tests/definition.rs::catalog_symbol_resolves_to_source | No self-test calls the Go to Definition path. Replaces NSTextView's ⌘-click multi-selection. No hover underline cue. |
| Editor › click a code-vision label ("N usages") | click | `mouseDown` → `visionHit` → `placeCaretOnVisionItem` → `state.findUsages()` | Puts the caret on the outline item for that line and runs Find Usages. | SELFTEST: "find usages" (rust; covers `findUsages` only); UNIT: VisionLayoutTests.testLabelRectSitsInExtraBandAtIndent | Only when View › Code Vision is on. The hit test and caret placement are untested. |
| Editor › hover on identifier | mouse rest | `mouseMoved` → `HoverController.mouseMoved` → `DebugHover.request` or `hooks.definitions` → `HoverText.content` | After a delay (throttled), shows the variable value while debugging, otherwise the definition and doc hover. Click, key, scroll or mouse exit hides it. | RUST: tests/definition.rs::local_definition_comes_first | Off when `prefs.hoverDocs == false`. No self-test. |
| Editor › Option-click / middle-click in text | ⌥-click, button 3 | none (stock NSTextView) | No custom behaviour. ⌥-drag gives the stock rectangular selection. | NONE | Middle-click is handled only on tabs. |
| Editor › right-click in text | right-click / ⌃-click | none (no `menu(for:)` override) | Shows the stock NSTextView context menu (Cut / Copy / Paste, Spelling, Substitutions …). | NONE | ⚠ No IDE actions (Go to Definition, Find Usages, Rename, Refactor, Intentions) in the editor context menu. The stock menu can re-enable substitutions that `RideTextView+Apply` turns off. |
| Gutter › click line-number / breakpoint column | click | `GutterView.mouseDown` (x ≥ marker+glyph columns) → `state.toggleBreakpoint(path:line:)` | Adds or removes a breakpoint on that line. Syncs the debugger, refreshes gutters, saves the workspace, updates the menu. | SELFTEST: "breakpoint clear" (rust, via rustRun → debugSteps), "cpp debug step out" (cpp, developer mode only); UNIT: BreakpointsTests.testToggleAddsAndRemoves | Works on any saved file, including Markdown and TOML. No-op for untitled buffers. |
| Gutter › right-click line-number column | right-click | `GutterView.rightMouseDown` → `state.editBreakpoint(path:line:)` | With no breakpoint, adds one. With one, opens the `BreakpointEditor` alert (Condition / Hit count, [Save] [Cancel]). | UNIT: BreakpointsTests.testEditKeepsLineAndTrims, BreakpointsTests.testEditOnMissingLineDoesNothing | `BreakpointEditor` returns nil in demo mode, so no self-test is possible. Right-click on the other columns does nothing (no context menu). |
| Gutter › click fold chevron | click | `GutterView.mouseDown` (glyph column, `folds.isFoldStart`) → `FoldController.shared.toggle(line:)` | Folds the region starting on that line, or unfolds it. | SELFTEST: "gutter fold", "gutter unfold" (rust); UNIT: FoldSetTests.testIsFoldStartLine, FoldSetTests.testHidesParagraphsStrictlyInsideAndClampsCaret | ⚠ The gutter checks the fold start on its own text view, but `toggle(line:)` acts on `EditorPanes.shared.focusedView`. In a split, clicking a chevron in the unfocused pane folds or unfolds that line number in the focused pane. |
| Gutter › click run marker ▶ | click | `GutterView.mouseDown` (marker column) → `state.runTestMarker` (`Tests/AppState+Tests.swift`) | For a test, runs that test with its framework. For `main` (no framework), calls `runAction(.run)`. | RUST: tests/test_markers.rs::rust_test_functions_are_module_qualified, tests/test_markers.rs::rust_file_scope_test_and_main | ⚠ The ▶ on a `main` runs the selected run target, not necessarily this file's binary. The "gutter run markers" self-test checks only that the marker is present; it never clicks it. |
| Gutter › click intention bulb or diagnostic dot | click | `GutterView.mouseDown` → returns (not a fold start) | Nothing. | NONE | ⚠ A bulb is drawn (`IntentionGutter` → `intentionLines`) but clicking it does nothing. Intentions open only via ⌥↩. |

### Editor tab strip and splits

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Tab › click | click | `state.selectBuffer(id, in: paneID)` (`Buffers.swift`) | Focuses the tab's pane and activates the buffer. Resets completion, records a nav location, refreshes the preview. | UNIT: PaneLayoutTests.testSelectFocusesPaneShowingBuffer, PaneLayoutTests.testOpenRemovesTabFromOtherPanes | Cursor shows 1:1 until the editor publishes its position. |
| Tab › ✕ button | click | `IconButton` → `state.closeBuffer(id)` | Closes the buffer and asks [Save] [Don't Save] [Cancel] if it is dirty. | UNIT: PaneLayoutTests.testRetainPrunesMissingBuffers, PaneLayoutTests.testCloseFallsBackToLastTab (pane bookkeeping only) | The ✕ shows on hover or on the selected clean tab. Dirty tabs show a dot until hovered. |
| Tab › middle-click | middle-click | `MiddleClick` → `state.closeBuffer(id)` | Same as ✕. | UNIT: PaneLayoutTests.testRetainPrunesMissingBuffers | `MiddleClickView.hitTest` passes only other-mouse events. |
| Tab ctx › Close | — | `state.closeBuffer(id)` | Same as ✕. | UNIT: PaneLayoutTests.testRetainPrunesMissingBuffers | — |
| Tab ctx › Close Others | — | `state.closeOthers(keeping:)` (`Buffers+File.swift`) | Closes every other buffer in both panes, then selects the kept one. | UNIT: PaneLayoutTests.testRetainPrunesMissingBuffers | ⚠ Cancel on a dirty prompt skips only that buffer and keeps closing the rest (Close All stops on Cancel). Also closes tabs in the other split pane. |
| Tab ctx › Close All | — | `state.closeAll()` | Asks about each dirty buffer (stops on Cancel), then closes every buffer in every pane. | UNIT: PaneLayoutTests.testRetainPrunesMissingBuffers | — |
| Tab ctx › Open in Split | — | `state.openInSplit(id)` (`AppState+Panes.swift`) | With no split, opens one and moves the tab into the new pane. With a split, moves the tab to the pane next to the focused one. | SELFTEST: "split header source" (rust; takes the `openInSplit(other.id)` branch); UNIT: PaneLayoutTests.testMoveTakesTabToOtherPane, SplitLayoutTests.testToggleOpensHorizontalThenReturnsToSingle | ⚠ On a tab in the unfocused pane, "neighbour of focused" is the tab's own pane, so the tab doesn't move. It only focuses that pane. |
| Tab ctx › Copy Path | — | `TreeActions.copyPath(url, root: nil)` | Copies the absolute path. Only for file-backed tabs. | NONE | — |
| Tab ctx › Copy Relative Path | — | `TreeActions.copyPath(url, root: workspaceRoot)` → `WorkspaceFS.relativePath` | Copies the path relative to the workspace root, or the absolute path when no workspace is open. | NONE | — |
| Tab ctx › Reveal in Finder | — | `TreeActions.reveal` → `NSWorkspace.activateFileViewerSelecting` | Shows the file in Finder. | NONE | — |
| Tab › drag onto a pane's tab strip | drag | `onDrag` → `TabPasteboard` (`dev.ride.tab-id`, in-process) → `state.moveTab(id, to:)` | Moves the tab to that pane and focuses it. | UNIT: PaneLayoutTests.testMoveTakesTabToOtherPane | No reordering within a strip; dropping on the same strip only reactivates the tab. Only the strip accepts drops. |
| Editor split divider › drag | drag | `HSplitView` + `reportSize` → `state.setSplitRatio(width/total)` | Sets and persists the left/right pane ratio (clamped to `SplitLayout.minRatio`). | UNIT: SplitLayoutTests.testRatioClamped, SplitLayoutTests.testRestoreUsesFocusedSideAndRatio | No double-click action. `DividerGrip` is decorative only (`hitTest` → nil). ⚠ `PaneTabStrips.sidePanelsWidth` leaves out the Hierarchy panel width, so with Hierarchy open the tab strips no longer line up with the split panes. |
| Side-panel handle › drag (Preview / Outline / Hierarchy) | drag | `SplitHandle` → `state.saveLayout { previewWidth / outlineWidth / hierarchyWidth }` (`DetailColumn.swift`) | Resizes the right-side panel. Preview is 260–900, Outline and Hierarchy 160–420. Shows a resize cursor on hover. | NONE | No double-click reset. |
| Sidebar / bottom panel dividers › drag | drag | native `NSSplitView`; `SplitPositioner` restores positions from prefs | Resizes the sidebar, Problems, Terminal, Tests, Debug or Run Output panel. The initial position comes from prefs via `SplitDividerPlacement`. | UNIT: SplitDividerPlacementTests.testLeadingPaneMovesItsTrailingDivider, SplitDividerPlacementTests.testLastPaneFromEndMovesTheDividerAboveIt +3 more | Untraced: how a dragged size is written back to prefs. `SplitPositioner.updateNSView` is empty (applied only on creation). |

### Status bar

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Status › Check summary segment (click) | — | `CheckStatusView.onTapGesture` → `state.toggleProblems()` | Shows or hides the Problems panel. The segment shows running progress or the error and warning counts. | NONE | ⚠ Tooltip says "Problems (⇧⌘M)", but View › Problems is ⌘6 and ⇧⌘M is unbound. Self-tests set `showProblems` directly and never call `toggleProblems`. |
| Status › line-ending segment › Keep | — | `LineEndingMenu.keepEndings` → `updatePrefs { lineEndings = keep }` | Sets the global save policy to keep each file's original line endings. | UNIT: LineEndingsTests.testKeepWritesCRLFWhenTheBufferLoadedCRLF, LineEndingsTests.testKeepWritesLFWhenTheBufferLoadedLF | ⚠ No checkmark shows the current policy. Keep doesn't undo an earlier Convert on the buffer. |
| Status › line-ending segment › Convert to LF | — | `LineEndingMenu.convertToLF` → `buffer.convertToLF()` + `updatePrefs { lineEndings = lf }` | Marks this CRLF buffer as LF (dirty) and sets the global policy to LF. | UNIT: LineEndingsTests.testLFPolicyWritesLFAndClearsTheCRLFFlag, LineEndingsTests.testCRLFBufferRoundTripsWithoutDoubledCarriageReturns | ⚠ A per-file action silently changes the app-wide preference, so every CRLF file saved later becomes LF too. |

Non-interactive status segments (not counted): Git branch, "Ln X, Col Y" (clicking doesn't open Go to Line), file path (tooltip shows the full path), formatter error (calls `engine.formatterName` on every render), AI status ("AI…" / last note / "AI"), index progress or label. "Spaces: N" is also non-interactive. ⚠ It always says "Spaces" even in Makefiles, where Tab inserts `\t`, and it can't change the indent.

### Notice bar, empty editor, Welcome

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Notice bar › action button | — | `state.noticeAction.run` (`AppState+Notice.swift`) | Runs the notice's action. Current actions: "Install…" on the missing-tools notice (`checkTools` → `clearNotice` + Tools sheet) and "Copy Report" on the crash-report notice (copies the text). | UNIT: NoticeQueueTests.testActionableNoticeIsNotReplacedByAnotherActionableOne, NoticeQueueTests.testTransientNoticePreemptsAndThenResumesTheActionableOne +2 more; ReportStoreTests.testNoticeTextDependsOnTheKindOfReport | Copy Report leaves the notice up. Only ✕ acknowledges the reports; the 30 s timeout does not, so unacknowledged reports come back on the next launch. Both notices are skipped in demo mode. |
| Notice bar › ✕ Dismiss | — | `state.dismissNotice()` | Advances the queue and runs `onDismiss` (the crash-report notice acknowledges reports). | UNIT: NoticeQueueTests.testDismissHandlerSurvivesAQueuedNotice | Notice text is selectable. |
| Welcome › Open Folder… | — | `state.openFolder()` (`AppState+Workspace.swift`) | Opens an NSOpenPanel for folders, then `open(url)`. | NONE | Welcome shows only when `workspaceRoot == nil`; otherwise the editor area shows `EmptyEditorView`. |
| Welcome › Recent row (up to 6) | click | `state.open(url)` | Opens that folder as the workspace. It closes all buffers (asking about dirty ones), stops runs, closes terminals and reindexes. | SELFTEST: "sample project reopen" (rust; calls `state.open`) | No context menu to forget an entry. Missing folders are filtered out only when the list loads. |
| Welcome › sample button (Rust demo / C demo / C++ demo) | — | `WelcomeSamples.copy` → `state.chooseSampleDestination` (NSSavePanel) → `state.openSample` | Copies the bundled sample to the chosen place, opens it and opens its main file. A copy error shows inline in red. | SELFTEST: "sample project copied" (rust; `openSample` only, the panel is bypassed) | Only samples present in `Resources/samples` get a button. |
| Welcome › Set up › Install | — | `ToolsModel.shared.present(name)` + `showToolsSheet = true` | Opens the Install Tools sheet with that tool preselected. Shown for missing tools that have an installer command. | UNIT: SetupRowsTests.testMissingToolCarriesItsCommand, SetupRowsTests.testRowsFollowTheFixedOrderAndEndWithDebugging | The section is hidden once every row is green. |
| Welcome › Set up › Copy | — | `CopyCommandButton` | Copies a manual command (for example the Debugging row's `sudo DevToolsSecurity -enable`). The label changes to "Copied". | UNIT: SetupRowsTests.testDeveloperModeOffKeepsTheSectionOpen, SetupRowsTests.testRustupStaysDisplayOnly | Developer-mode status is read only `onAppear`, so the row stays stale after enabling it. |
| Welcome › shortcut hints | — | static `WelcomeView.hints` | Shows key caps for ⌘P, ⇧⌥⌘O, ⇧⌘F, ⌘B, F12 and ⌘/. | NONE | ⚠ "⌘/ All shortcuts" is wrong. ⌘/ is Code › Comment Line; Help › Keyboard Shortcuts is ⌘? (⇧⌘/). The other five hints match the menus. |

Empty editor view (not counted) has no controls. Its "⌘P" hint matches Navigate › Open Quickly. `RustSrcHint` shows `rustup component add rust-src` as plain text, with no copy button.

### Confirm dialogs and related prompts

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Confirm › "Delete <name>?" / "The item will be moved to the Trash." [Delete] [Cancel] | — | `Confirm.ask` ← `TreeActions.confirmTrash` | Asks before moving a tree item to the Trash. | NONE | `Confirm.ask` returns true in demo mode, so the prompt never shows under self-test. |
| Confirm › "Stop and rerun?" / "A process is already running." [Stop and Rerun] [Cancel] | — | `Confirm.ask` ← `AppState+RunOutput.confirmStopAndRerun` | Asks before killing the running process to start a new run. | SELFTEST: "build stop and rerun", "test stop and rerun" (rust; accept branch auto-taken) | Cancel is never tested. |
| Confirm › "Revert <name> to the saved version?" / "Your unsaved changes will be lost." [Revert] [Cancel] | — | `Confirm.ask` ← `revertToSaved()` | Asks before reloading a dirty buffer from disk. | NONE | — |
| Alert › "Save changes to <name>?" [Save] [Don't Save] [Cancel] | — | `confirmClose` (`Buffers.swift`) | Shown when closing a dirty tab, Close All, opening another workspace, or quitting. Save on an untitled buffer opens the save panel. | NONE | Custom NSAlert, not `Confirm`. Auto-accepted in demo mode. |
| Alert › "<name> changed on disk" [Overwrite] [Reload] [Cancel] | — | `confirmOverwrite` (`Buffers+File.swift`) | Shown on save when the file changed on disk while dirty. Overwrite saves, Reload discards local edits. | NONE | No demo bypass. |

The Breakpoint editor alert is covered in the gutter table. The TreeActions OK/Cancel name prompts belong to the tree area.

### External entry points (open URL / launch arguments)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| URL `ride://open?path=<abs>[&line=N[&column=M]]` | — | `RideAppDelegate.application(_:open:)` → `OpenURLParser.request` → `state.openRequest` (`Launch/AppState+Open.swift`) | A folder becomes the workspace. For a file, it opens the nearest ancestor with Cargo.toml / CMakeLists.txt / Makefile / compile_commands.json (else the file's folder) as workspace, opens the file, jumps to line or line:column, and focuses the editor. | SELFTEST: "ride url opens file at line" (rust); UNIT: OpenURLParserTests.testPathLineAndColumn, OpenURLParserTests.testPathOnlyAndPercentEncoding, OpenURLParserTests.testBadInputIsRejected; WorkspaceRootFinderTests.testNearestAncestorWithAManifestWins +3 more | Scheme registered in Info.plist (`com.ride.open`). Host must be `open`. A non-positive or non-numeric line or column rejects the whole URL. A column without a line is ignored. A file outside the current root switches workspace, which triggers the dirty-buffer prompts. |
| File or folder open (Finder Open With, drop on Dock icon, `open -a Ride <path>`) | — | `RideAppDelegate.open` → `state.openPath` → `openRequest` | Same as above without a position. Info.plist document types: public.folder, public.source-code, public.plain-text (rank Alternate). | UNIT: WorkspaceRootFinderTests.testEveryMarkerIsRecognised, WorkspaceRootFinderTests.testWithoutAMarkerTheFilesDirectoryIsTheRoot +2 more | No self-test sends a file URL. |
| Launch arg `--open <folder>` | — | `AppState.launchFolder()` (`AppState+Launch.swift`) → `open(url)` in `AppState+Init` | Opens that folder as the workspace at startup. Used by `scripts/run.sh`, `screenshots.sh` and every self-test launch. | SELFTEST: "setup" (implicit: every self-test launches with `--open`, and setup fails without a workspace) | ⚠ Folders only. `--open some/file.rs` is silently ignored, while `ride://` and Finder accept files. |
| Launch args `--demo <scene>` with `--theme`, `--file`, `--frame WxH`, `--scroll`, `--ready-file`, `--quit-after` | — | `DemoLaunch` / `DemoScene.run` | Runs a screenshot scene: sizes the window, writes a ready file, quits after N s (with a 600 s guard). `isDemo` also turns off confirmations, crash notices, the breakpoint editor and workspace restore. | NONE | Scenes have no assertions. These dev-only flags are in the release binary. |
| Launch args `--demo selftest --report <file> [--only a,b] [--file <path>]` | — | `DemoSelfTest.start` → `SelfTestSelection.pick` | Runs the in-app self-test (steps for the active file's language) and writes PASS/FAIL lines to the report (default `/tmp/ride-selftest.txt`). | UNIT: SelfTestSelectionTests (the `--only` filter) | — |


---

## Project sidebar, Problems panel, Find bar, Find/Replace in Project, other controls

### Project sidebar (Workspace/SidebarView.swift, TreeRow.swift, TreeKeyView.swift, TreeActions.swift, AppState+TreeActions.swift)

Header buttons show only when a workspace is open. The ctx items "Set as Active Project" and "Build Project" show only on project-root rows, and only when the workspace holds more than one project (`TreeProjectMark`). The git dirty dot on rows is display only. Rows have no drag and drop.

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Sidebar header › New File (doc.badge.plus) | — | `TreeActions.newFile(in: root, kind:)` → `state.fileCreated(url)` (Buffers+File.swift) | NSAlert with a name field and language picker (`LanguageNameField`). Creates an empty file in the **workspace root**, then calls `engine.workspaceFileChanged`, reloads the tree and opens the file. | UNIT: NewFilePromptTests.testDefaultLanguageFollowsProjectKind, NewFilePromptTests.testUntitledNameUsesTheLanguageExtension | ⚠ Ignores the tree selection and always uses the root. This is a second New File flow: File › New File… uses NSSavePanel + SaveLanguagePicker in the selected folder. The `createFile` result is ignored, so a name like `sub/x.rs` with a missing folder opens a file that does not exist. |
| Sidebar header › Collapse All | — | `state.expanded = []` | Collapses every folder. `revealInTree` re-expands ancestors on the next editor file switch. | UNIT: FileTreeRowsTests.testCollapsedFoldersHideTheirChildren | Row visibility logic only. |
| Tree row › chevron click | — | `TreeRow.toggle()` | Expands the folder (calls `node.loadChildren()` lazily) or collapses it by editing `state.expanded`. | UNIT: FileTreeRowsTests.testExpandedFoldersListChildrenOneLevelDeeper, FileTreeRowsTests.testCollapsedFoldersHideTheirChildren | |
| Tree row › click | — | `TreeRow.select()` | Sets `state.selectedURL` and makes the hidden `TreeKeyView` first responder via `TreeKeyFocus.select`, so tree keys act on this node. | NONE | A single click does not open files. |
| Tree row › double-click | — | `TreeRow.activate()` → `state.openFile(url)` | Opens a file in the editor. On a folder it toggles expansion. | SELFTEST: "open second file", "reopen first file" (rust, c; call `state.openFile`) | The single-tap gesture also fires first, so the row gets selected too. |
| Tree ctx › Set as Active Project | — | `state.projectModel.choose(root:)` (ProjectModelStore.swift) | Makes that project the active one: targets, profiles and the run target follow it. Disabled when the row is already active. | NONE | FileTreeRowsTests.testProjectMarkPrefersActive covers only the mark that drives visibility and disabled state. |
| Tree ctx › Build Project | — | `choose(root:)` then `state.runAction(.build)` | Switches the active project, then builds it. | SELFTEST: "build target" (rust), "c build" (c) | Only the build half is tested. The project switch before it is untested. |
| Tree ctx › New File | — | `TreeActions.newFile(in: dir, …)` → `fileCreated` | Same as the header New File, but in the node's folder (or the node itself if it is a folder). | UNIT: NewFilePromptTests.testDefaultLanguageFollowsProjectKind, NewFilePromptTests.testLanguageListMatchesTheSavePanel | Same caveats as the header New File. |
| Tree ctx › New Folder | — | `TreeActions.newFolder(in: dir)` | Prompts for a name and creates the folder. | NONE | ⚠ Errors are swallowed by `try?`, so an existing name is a silent no-op. Does not call `reloadTree()` and relies on the FS watcher. File › New Folder… (`AppState.newFolder`) does call `reloadTree()`. |
| Tree ctx › Rename | — | `state.runTreeAction(.rename)` → `renameItem` → `TreeActions.renamed` | Prompts for a name, then `moveItem`, `workspaceFileChanged` for the old and new paths, rebinds open buffers under the path (`TreePath.moved`), and reloads the tree. On failure it shows the notice "Could not rename…". | UNIT: TreePathTests.testMovedFileFollowsTheRename, TreePathTests.testFilesInsideAMovedFolderFollowIt, TreePathTests.testSiblingWithSharedPrefixIsNotMoved | ⚠ Breakpoints stay keyed to the old path (Delete forgets them, Rename never migrates them). `expanded`, `selectedURL` and `TreeKeyFocus.url` keep the old URL, so a renamed folder collapses. |
| Tree ctx › Duplicate | — | `TreeActions.duplicate(url)` | Copies to "name copy.ext" (then "copy 2", …) next to the original and notifies the engine. | NONE | ⚠ `copyItem` errors are swallowed (`try?`). No `reloadTree()`, so it relies on the FS watcher. |
| Tree ctx › Delete | — | `state.runTreeAction(.trash)` → `TreeActions.trash` | Asks via `Confirm.ask` ("Delete X?", Delete/Cancel), moves the item to the Trash (`NSWorkspace.recycle`), notifies the engine, forgets breakpoints under the path and reloads the tree. | NONE | ⚠ Tabs showing the trashed file stay open. `differsFromDisk()` returns false for a missing file, so there is no reload and no notice, and a later save or autosave recreates the file. |
| Tree ctx › Copy Path | — | `TreeActions.copyPath(url, root: nil)` | Puts the absolute path on the pasteboard. | NONE | |
| Tree ctx › Copy Relative Path | — | `TreeActions.copyPath(url, root: workspaceRoot)` | Puts the path relative to the **workspace** root (not the project root) on the pasteboard. | NONE | |
| Tree ctx › Reveal in Finder | — | `TreeActions.reveal` | Runs `NSWorkspace.activateFileViewerSelecting`. | NONE | |
| Tree ctx › Open in Terminal | — | `state.openTerminal(directory: dir)` (AppState+Terminal.swift) | Shows the terminal panel and opens a new tab whose cwd is the node's folder. | SELFTEST: "terminal open" (rust; calls `openTerminal(directory:)`) | |
| Tree key › Return / keypad Enter | ↩ | `TreeKeyView.keyDown` → `AppState.handleTreeKey` → `TreeModel.action` → `.rename` | Renames the last-clicked node, as in Finder. | UNIT: TreeModelTests.testReturnRunsRename, TreeModelTests.testOtherKeysDoNothing | ⚠ See the tree-keys item in the ⚠ list (stale `TreeKeyFocus.url`, modifiers ignored). The selftest "tree keys" has an empty `run` and only checks the key mapping, so it is not counted. Return does not open files. Arrow keys are not handled, so the tree has no keyboard navigation. |
| Tree key › Delete / Forward Delete | ⌫ / ⌦ | same path → `.trash` | Trashes the last-clicked node after confirmation. | UNIT: TreeModelTests.testDeleteRunsTrash | ⚠ Plain ⌫ (Finder uses ⌘⌫). Same stale-URL problem as Return. |
| New File dialog › OK / Cancel (+ language picker) | ↩ / esc | `TreeActions.newFile` NSAlert | OK creates the file. Cancel or an empty name aborts. | UNIT: NewFilePromptTests.testDefaultLanguageFollowsProjectKind | The picker lives in SaveLanguagePicker.swift, another agent's scope. |
| Rename / New Folder prompt › OK / Cancel | ↩ / esc | `TreeActions.prompt` NSAlert | Returns the trimmed name. Cancel or an empty name returns nil. | NONE | |

### Problems panel (Problems/ProblemsPanel.swift, ProblemFixes.swift, DiagnosticDocLink.swift)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Problems header › Show errors (xmark.octagon) | — | local `@State showErrors.toggle()` | Hides or shows error rows in the list. View-local, not persisted. | NONE | |
| Problems header › Show warnings (exclamationmark.triangle) | — | local `@State showWarnings.toggle()` | Hides or shows every non-error row (warning, note, …). | NONE | |
| Problems header › Check (⌥⌘B) | (⌥⌘B via Build › Check) | `state.runCheck()` (AppState+Check.swift) | If the active buffer is C/C++, calls `CheckService.run(file:)` → `engine.runCheckC`. Otherwise calls `run(root: activeProjectRoot)` → `engine.runCheck` (cargo check). Results fill the list. | UNIT (RUST): tests/check.rs::cargo_check_on_fixture_crate, tests/clang_check.rs::runs_clang_on_a_c_file_without_a_database, tests/clang_check.rs::runs_clang_on_a_cpp_file_with_std_headers | ⚠ In a C/C++/CMake/Make project with a non-C active buffer (or no editor), this runs `cargo check` on a non-Cargo root and shows a failure badge. It also ignores `prefs.useClippy`, which live cargo checks honour. |
| Problems header › Hide Problems (xmark) | — | `state.showProblems = false` | Closes the panel. | NONE | |
| Problems row › click | — | `state.openDiagnostic(diag)` → `jumpToDiagnostic` → `openFile(at: .byte)` | Opens the file at the diagnostic's byte, read-only if it is outside the workspace, and highlights the row. | NONE | ⚠ The highlight is stored as an index into the filtered list, so toggling a filter or a new check result moves it to a different diagnostic. |
| Problems row ctx › *<fix title>* (one per fix) | — | `state.applyDiagnosticFix(diag, fix:)` → `IntentionActions.apply(fix:to:)` | Opens the diagnostic, then after 0.1 s applies the compiler-suggested edits if the focused editor shows that file. The menu exists only when `diag.fixes` is non-empty. | UNIT (RUST): tests/check.rs::machine_applicable_children_become_fixes, tests/check.rs::placeholder_and_cross_file_suggestions_yield_no_fix, tests/check.rs::diagnostics_without_children_have_no_fixes | ⚠ Uses a fixed 0.1 s timer. If opening takes longer (cold file load), the fix is silently dropped. |
| Problems row › code tag (e.g. `E0308`, `clippy::x`, `-Wfoo`, `bugprone-x`) | — | `NSWorkspace.open(DiagnosticDocLink.url(for:))` | Opens the rustc error index, clippy lint page, clang diagnostic reference or clang-tidy check page. Tags with no known URL are plain text. | UNIT: DiagnosticDocLinkTests.testClippyLink, DiagnosticDocLinkTests.testRustErrorLink, DiagnosticDocLinkTests.testClangWarningLink +2 more | |
| *(automatic, not a control, not counted)* clang-tidy on save | — | `didSave` → `runClangTidyOnSave` → `ClangTidyService.run` → `CheckService.setLive` | Runs only when check-on-save is on, the buffer is C/C++, and the project root has a `.clang-tidy` file. Runs `clang-tidy -quiet [-p build dir]` and parses the output. | UNIT: ClangTidyParseTests.testParsesWarningWithCheckName, ClangTidyParseTests.testIgnoresOtherFilesAndNotes | ⚠ Results go into the **live** slot (`replaceLive`). Non-empty tidy findings replace that file's live compiler diagnostics and hide its save-check clang diagnostics, so errors vanish from Problems. The next live check then wipes the tidy findings. |

### In-file Find bar (Search/FindBar.swift, SearchActions.swift, FindMatcher.swift, FindCount.swift)

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Find bar › Find field (typing) | — | binds `state.findQuery`; label from `FindCount.label` | Updates only the "n of N" / "N" / "No results" label. Nothing is selected until Return or Next. | UNIT: FindMatcherTests.testCaseInsensitiveByDefault (matching) | There is no incremental search. `FindCount` has no test of its own. `HitNavigation.swift` belongs to completion hits, not Find. |
| Find bar › Find field Return (and Shift-Return) | ↩ | `.onSubmit` → `state.findNext()` | Selects the next match after `findOrigin` and wraps around. | SELFTEST: "find next" (rust) | Shift-Return is not handled separately. It submits the field and also goes to the next match, not the previous one. |
| Find bar › Previous (chevron.up) | (⇧⌘G via Edit › Find Previous) | `state.findPrevious()` | Selects the previous match before the current one and wraps around. | UNIT: FindMatcherTests.testNextWrapsAround | |
| Find bar › Next (chevron.down) | (⌘G via Edit › Find Next) | `state.findNext()` | Selects the next match. | SELFTEST: "find next" (rust) | |
| Find bar › Match case (textformat) | — | `state.findOptions.caseSensitive.toggle()` | Makes matching case-sensitive. | UNIT: FindMatcherTests.testCaseSensitiveAndWholeWord, FindMatcherTests.testCaseInsensitiveByDefault | |
| Find bar › Whole word | — | `state.findOptions.wholeWord.toggle()` | Wraps the pattern in `\b(?:…)\b`. | UNIT: FindMatcherTests.testCaseSensitiveAndWholeWord | |
| Find bar › Regular expression (asterisk) | — | `state.findOptions.regex.toggle()` | Uses the query as an NSRegularExpression and the replacement as a template (`$1`). | UNIT: FindMatcherTests.testRegexAndReplacementTemplate, FindMatcherTests.testRegexReplacementHonoursLookarounds, FindMatcherTests.testRegexReplacementExpandsGroupsAgainstTheWholeText | An invalid regex gives no matches and no error message. |
| Find bar › Replace toggle (arrow.left.arrow.right) | (help text says ⌥⌘F) | `state.showReplaceField.toggle()` | Shows or hides the replace field and the Replace/All buttons. | NONE | |
| Find bar › Replace field (typing / Return) | — | binds `state.replaceQuery` | Holds the replacement text. Return does nothing (no `onSubmit`). | NONE | |
| Find bar › Replace | — | `state.replaceOne()` | If the current range is not a match, finds the next one first. Then replaces it, captures the text and moves to the next match. | UNIT: FindMatcherTests.testRegexAndReplacementTemplate | No selftest calls `replaceOne`. |
| Find bar › All | — | `state.replaceAll()` | Replaces every match in the focused editor as one edit (`EditResult.mapping`). | SELFTEST: "replace all", "replace back" (rust) | |
| Find bar › Close (xmark) | — | `state.showFind = false` | Hides the bar. | NONE | ⚠ Does not give focus back to the editor. Esc does. |
| Find bar › Esc | esc | `.onExitCommand` | Hides the bar and makes the focused editor first responder. | NONE | |

### Find / Replace in Project (Search/ProjectFindView.swift, ProjectFindModel.swift, ProjectFind.swift, ProjectReplace*.swift, FindRows.swift)

The overlay opens from Edit › Find in Project… (⇧⌘F) and Edit › Replace in Project… (⇧⌘H). Both call the same `toggleProjectFind()`, so ⇧⌘H does not focus the Replace field. Those menu items belong to the menu agent.

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Project find › query field Return | ↩ | `submit()` → `model.run(root:showHidden:)` or `open(selected)` | If the query or options changed (`needsRun`) or there are no matches, searches the workspace in the background (`ProjectFind.search`, capped at 2000 matches and 1 MB per file, binary files skipped). Otherwise opens the selected match. | UNIT: ProjectFindTests.testFindsCaseInsensitiveLinesWithByteOffsets, ProjectFindTests.testSkipsTargetAndBinary, ProjectFindTests.testCapMarksTruncated +1 more | No live search. ⚠ The query is trimmed, see the ⚠ list. |
| Project find › ↑ / ↓ | ↑ ↓ | `.onKeyPress` → `model.move(±1)` | Moves the selection through matches with wraparound and scrolls to it. | NONE | |
| Project find › Esc / backdrop click | esc | `PickerCard.onExitCommand` / `OverlayBackdrop` tap → `showProjectFind = false` | Dismisses the overlay. | NONE | |
| Project find › Replace field Return | ↩ | `preview()` | Runs the search if it is stale (with `pendingPreview`), then opens the preview sheet if there are matches. | UNIT: ProjectFindTests.testFindsCaseInsensitiveLinesWithByteOffsets | Unlike the button, it is not disabled for a blank query, but that is harmless (empty result). |
| Project find › Match case | — | `model.options.caseSensitive.toggle()` | Changes matching. The next Return re-runs the search. | UNIT: FindMatcherTests.testCaseSensitiveAndWholeWord | |
| Project find › Whole word | — | `model.options.wholeWord.toggle()` | Same, for whole-word matching. | UNIT: FindMatcherTests.testCaseSensitiveAndWholeWord | |
| Project find › Regular expression | — | `model.options.regex.toggle()` | Same, for regex matching. | UNIT: FindMatcherTests.testRegexAndReplacementTemplate, ProjectReplaceTests.testRegexReplacementUsesCaptureGroups | |
| Project find › Replace… | — | `preview()` → `model.requestPreview()` | Opens the Replace in Project preview sheet, searching first if stale. Disabled when the query is blank. | UNIT: ProjectFindTests.testFindsCaseInsensitiveLinesWithByteOffsets | The preview state logic (`pendingPreview` / `requestPreview`) is untested. |
| Project find › result row click | — | `open(match)` → `state.openFile(file, at: .byte)` | Closes the overlay and opens the file at the match's byte offset. | UNIT: ProjectFindTests.testFindsCaseInsensitiveLinesWithByteOffsets | ⚠ The row highlight uses a case-insensitive substring of the raw query and ignores the regex, whole-word and case options. File group headers are not interactive. |
| Replace preview › file checkbox | — | `model.setIncluded(file, on)` | Includes or excludes a file from the replace. The summary updates. | UNIT: ProjectReplaceTests.testUntickedFileIsUnchanged | |
| Replace preview › Select All | — | `select(true)` | Includes every file. | NONE | |
| Replace preview › Select None | — | `select(false)` | Excludes every file, which disables Replace. | NONE | |
| Replace preview › Cancel | esc | `model.showPreview = false` | Closes the sheet. | NONE | |
| Replace preview › Replace | ↩ | `state.applyProjectReplace()` (ProjectReplaceApply.swift) | Re-reads the live text of included files (open buffers first), re-matches, and writes each changed file (through the buffer and `persist` if open, else directly to disk plus `workspaceFileChanged`). Closes the sheet and overlay and shows a notice with replaced, skipped and failed files. Disabled when no file is included. | UNIT: ProjectReplaceTests.testLiteralReplacesEveryHit, ProjectReplaceTests.testChangedOnDiskFileIsSkipped, ProjectReplaceTests.testSummaryNamesFailedFiles +4 more | The sheet's counts come from search time. The applied count comes from the refreshed text and can differ. Disk-only files cannot be undone. |

### Other controls

A sweep of the whole app for `Button(`, `Toggle(`, `Picker(`, `IconButton(`, `.onTapGesture`, `.contextMenu`, `NSMenuItem(`/`NSMenu(`, `.onKeyPress`, `.keyboardShortcut`, NSAlert buttons, gesture recognizers and mouse/key overrides. After excluding files owned by other agents, only these remain:

| Command (path) | Shortcut | Handler | What it does | Coverage | Notes/⚠ |
|---|---|---|---|---|---|
| Unsaved-changes alert › Save / Don't Save / Cancel (Editor/Buffers.swift `confirmClose`) | ↩ / — / esc | `save(buffer)` / proceed / abort | Shown when closing a dirty tab, closing all tabs, or closing or switching the workspace. Save proceeds only if the buffer ends up saved. | NONE | Skipped in demo launches (`DemoLaunch.isDemo`). |
| Changed-on-disk alert › Overwrite / Reload / Cancel (Editor/Buffers+File.swift `confirmOverwrite`) | ↩ / — / esc | clear `changedOnDisk` / `reloadFromDisk` / abort | Shown on save when the file changed on disk under a dirty buffer. Reload discards your edits and cancels the save. | NONE | |
| Hover popup › click (Editor/HoverPanel.swift → HoverController.upgradeIfVisible) | — | `NSClickGestureRecognizer` → `HoverController.upgradeIfVisible()` | Clicking the hover card replaces it with the Quick Doc panel for the same symbol. | NONE | demo: "popups" scene (DemoScene+Popups) presents the hover. HoverPanel and HoverController are not in any other agent's file list. |
| Overlay backdrop › click (Design/OverlayCard.swift `OverlayBackdrop`) | — | `onDismiss` | Clicking the dimmed backdrop dismisses any PickerCard overlay (Quick Open, Symbol pickers, Find in Project, …). | NONE | OverlayCard.swift is not listed under another agent (OverlayPanel/PickerCard are). |
| *(helper, not counted)* Design/MiddleClick.swift | middle click | `MiddleClickView.otherMouseUp` | Generic middle-click catcher, used only by TabItem (middle-click closes a tab, TabItem agent). | — | |
| *(helper, not counted)* Design/IconButton.swift | — | `Button(action:)` | Shared icon-button component. Has no command of its own. | — | |


---

## Preferences

Settings window: `Settings { PreferencesView() }` in `RideApp.swift` (standard `Ride › Settings…` ⌘,). Four tabs: General, Editor, Tools, AI. Every control writes through `PreferenceBindings` → `state.updatePrefs` (`AppState+Tree.swift`), which clamps (`Preferences.clamped`), saves `~/Library/Application Support/Ride/preferences.json` (skipped in demo), schedules a workspace save, reloads the tree when `showHidden` changes and calls `applyTheme()` when `theme` changes. Editors pick up changes through `EditorPane.updateNSView` → `EditorHostView.applyPrefs` → `RideTextView.applyPrefs`. `MenuModel.sync` mirrors softWrap, visibleWhitespace, indentGuides, lineNumbers, codeVision, outlinePanel. MenuModel's initial values match `Preferences.defaults` for all six, and `sync` overwrites them anyway.

### General

| Setting (pane › label) | Key | Default | Control | Where read / what it changes | Coverage | Notes/⚠ |
|---|---|---|---|---|---|---|
| General › Appearance › Dark / Light swatches | `theme` | `"dark"` | `ThemeSwatchPicker` (two swatch buttons) via `bind.theme` | `updatePrefs` sees the change → `AppState.applyTheme()` (`AppState+Theme.swift`): `ThemeStore.apply` (loads `Themes/dark.json` or `light.json`, sets `HighlightApply.theme`), re-themes terminals, sets `NSApp.appearance`, re-themes every editor host and resyncs highlighting. `RootView` sets `preferredColorScheme` from `isLightTheme`. At launch `configure()` calls `ThemeStore.apply(name: prefs.theme)` only. | UNIT: ContrastTests.testDarkPalette, ContrastTests.testLightPalette (palette JSON contrast only) | `clamped` turns any value other than "light" into "dark". `ThemeStore` re-applies the theme when macOS Increase Contrast changes (stronger borders). No menu command switches theme. demo: DemoScene sets `prefs.theme` then `applyTheme()`. |
| General › Text › Font size | `fontSize` | 13 | Stepper 11…18 | Editor font (`RideTextView.applyPrefs`), run output panel font, terminal font (`terminalFont()`), `View › Zoom In/Out/Actual Size` change it too (`AppState+View.swift`, range 10…24; Actual Size resets to 13). | SELFTEST: "zoom", "zoom reset" (rust/c/cpp; assert `prefs.fontSize` only, not the rendered font) | ⚠ Stepper range 11…18 disagrees with zoom range and `clamped` (10…24): zoom to 20 and the stepper shows a value outside its own range. ⚠ Changing the size does not update open terminals: `terminals.applyTheme(font:)` runs only on theme change or when a terminal opens. The Stepper path itself is untested. |
| General › Text › Tab width | `tabWidth` | 4 | Stepper 2…8 | `RideTextView.tabWidth` → tab stop width, indent unit for Tab/indent (spaces, tabs for Makefiles), unindent width, indent guides, code vision label indent. Status bar shows "Spaces: N". | UNIT: LineOpsTests.testUnindentRemovesUpToWidthOrOneTab, VisionLayoutTests.testIndentCountsSpacesAndTabs | Global only, no per-file detection. |
| General › Text › Line endings (Keep / Convert to LF) | `lineEndings` | `LineEndings.keep` | Picker | `buffer.save(lineEndings:)` in `persist` (`Buffers.swift`) and rename apply (`RenameApply.swift`): Keep writes CRLF back for CRLF-loaded files, LF writes LF. Status bar line-endings menu writes the same key. | UNIT: LineEndingsTests.testKeepWritesCRLFWhenTheBufferLoadedCRLF, LineEndingsTests.testLFPolicyWritesLFAndClearsTheCRLFFlag, LineEndingsTests.testUnknownPolicyBehavesLikeKeep +3 more | Status bar "Convert to LF" also converts the active buffer right away and marks it dirty. The picker only changes the policy used at the next save. Same end result, but at different times. |
| General › Files › Show hidden files | `showHidden` | false | Toggle | `updatePrefs` clears quick-open cache and calls `reloadTree()` (`WorkspaceFS.children(showHidden:)`), also used by Quick Open (`SearchActions`) and Find in Project. | NONE | Unit tests only ever pass `showHidden: false` (FileTreeRowsTests, ProjectFindTests), so the "true" path is untested. |

### Editor

| Setting (pane › label) | Key | Default | Control | Where read / what it changes | Coverage | Notes/⚠ |
|---|---|---|---|---|---|---|
| Editor › Editing › Auto-save after 1 s | `autoSave` | true | Toggle | `scheduleAutoSave` (`Buffers.swift`) saves dirty file-backed buffers 1 s after an edit. Off → no timer. | SELFTEST: "live diagnostic appears" (cpp; autoSave turned off in "live diagnostic prep", check asserts disk unchanged) | Only the off direction is checked. The label matches the 1 s delay. demo: DemoScene sets it false. |
| Editor › Popups › Completions as you type | `completions` | true | Toggle | `CompletionSession.textChanged` (auto popup) and `CompletionSession.trigger`. | NONE | ⚠ Label says "as you type", but off also blocks the explicit `Code › Trigger Completion` (⌥Space) popup for engine items. AI items still come through `AICompletionSource.trigger`. Completion steps run only with the default (on). |
| Editor › Popups › Type-aware completion (rust-analyzer, clangd) | `semanticCompletion` | true | Toggle with the oracle state as caption (`OracleSettingsRow`) | `RideEngineClient.setSemantic` → `Engine.set_oracle_enabled`; on, member, identifier and path completion in Rust asks rust-analyzer and in C/C++ asks clangd in the background, and the popup refreshes when it answers (`docs/product/semantic-oracle.md`). | `semantic member completion`, `semantic cpp member completion` | Off stops every language server process and clears the cache. |
| Editor › Popups › AI suggestions in the completion popup | `aiComplete` | false | Toggle | `AICompletionSource.textChanged` / `trigger` request AI items. Status bar shows the "AI" segment when on (`AIStatusView`). | NONE | Same key as AI › "Show AI suggestions in the completion popup" (two controls, same behaviour). demo: DemoScene forces it off. |
| Editor › Popups › Cheat sheet with completions | `cheatSheet` | true | Toggle | `CheatSheetController.follow` shows the sheet next to completions only when on or pinned. | NONE | ⌥⇧Space / Code › Cheat Sheet still toggle it when off, which fits the label. |
| Editor › Popups › Signature help | `signatureHelp` | true | Toggle | Auto signature help while typing (`EditorCoordinator.assist`) and after accepting a callable completion (`CompletionAccept`). | NONE | The explicit `Code › Signature Help` command ignores the pref, which is reasonable. |
| Editor › Popups › Documentation on hover | `hoverDocs` | true | Toggle | `RideTextView.mouseMoved` calls `HoverController` only when on. | NONE | |
| Editor › Display › Outline panel | `outlinePanel` | true | Toggle | `DetailColumn` shows `FileOutlineView` and its split handle; `PaneTabStrips` layout. Also set by `View › Outline` (⌘7) and the outline's close button (`FileOutlineView`). Saved per workspace in `LayoutState`. | NONE | ⚠ `applyLayout` (workspace restore) writes the workspace's `outlinePanel` straight into global `prefs` without saving. The Settings toggle then shows a per-workspace value, and the next `updatePrefs` of any key saves it as the global default. demo: many scenes set it directly. |
| Editor › Display › Line numbers | `lineNumbers` | true | Toggle | `EditorHostView.applyPrefs` → `gutter.showsNumbers` + `syncGutter()`. Also `View › Line Numbers`. | SELFTEST: "line numbers hidden", "line numbers shown" (rust; check gutter pixels + width) | The steps assign `state.prefs.lineNumbers` directly, so they skip `updatePrefs`/menu toggle and nothing is saved. The effect path is the same. |
| Editor › Display › Indent guides | `indentGuides` | true | Toggle | `RideTextView.showIndentGuides` → redraw. Also `View › Indent Guides`. | NONE | |
| Editor › Display › Visible whitespace | `visibleWhitespace` | false | Toggle | Mirrored to `MenuModel.visibleWhitespace` only. Nothing in the editor reads it. Also `View › Show Whitespace`. | NONE | ⚠ Dead setting. It is stored and toggled from both Settings and the View menu (the checkmark flips), but the editor never renders whitespace. |
| Editor › Display › Code vision | `codeVision` | true | Toggle | `RideTextView.applyCodeVision` (usage-count labels above declarations). Also `View › Code Vision`. | NONE | SELFTEST "code vision" (rust) checks the feature only in its default-on state and never flips the pref. |

### Tools

| Setting (pane › label) | Key | Default | Control | Where read / what it changes | Coverage | Notes/⚠ |
|---|---|---|---|---|---|---|
| Tools › cargo check › Check on save | `checkOnSave` | true | Toggle | `didSave` (`AppState+Check.swift`): cargo check for Rust roots, clang check for C/C++ (header-aware), clang-tidy on save. Also gates every live check (`scheduleLiveCheck`: live clang and live cargo). | NONE | ⚠ The section says "cargo check", but the toggle also turns off clang/clang-tidy save checks and all live diagnostics. Off also makes "Use Clippy" have no effect. The live-diagnostic self-tests only run with the default (on). |
| Tools › cargo check › Use Clippy for live diagnostics | `useClippy` | false | Toggle | `scheduleLiveCargo(clippy:)` → `engine.runCheck(clippy:)` for live Rust checks only. | NONE | Save-time `CheckService.schedule(root:)` never uses clippy, which matches the label. Has no effect when Check on save is off. |
| Tools › rustfmt › Format on save | `formatOnSave` | false | Toggle | `didSave` → `formatNow(buffer, thenSave: true)` when the engine reports a formatter for the file (`formatterName`). | NONE | ⚠ Under "rustfmt", but it formats any language with a formatter (such as clang-format for C/C++). |
| Tools › rustfmt › Check for missing tools at launch | `askMissingTools` | true | Toggle | `checkTools()` at launch (`AppState+Init`) shows the "Missing tools: …" notice with Install…. The Tools install sheet's "don't ask" checkbox writes the same key on close. | NONE | Placed under the "rustfmt" section, but it covers every tool in `ToolsModel`. Both writers behave the same. |
| Tools › Command line › Install `ride` command (Install / Retry) | — (not a pref) | — | `RideCommandRow` button | `RideCommand.shared.install` installs the `ride` CLI shim. Shows Installed / Install / error + Retry. | NONE | Not stored in Preferences. |

### AI

| Setting (pane › label) | Key | Default | Control | Where read / what it changes | Coverage | Notes/⚠ |
|---|---|---|---|---|---|---|
| AI › AI suggestions › Show AI suggestions in the completion popup | `aiComplete` | false | Toggle | Same as Editor › AI suggestions (see above). | (counted in Editor) | Duplicate control, same key and behaviour, slightly different label. |
| AI › AI suggestions › Context sent with each request | `aiContext` | `"function"` | Picker (Code block / Function / File / Directory / Project) | `AIConfig.level` → `AIContextBuilder.plan` for AI completions. Sets the starting context level of the Ask-AI sheet (`AIAssistant.askFromEditor`, which has its own picker). | UNIT: AIPromptTests.testConfigFallsBackToDefaults | Unknown values fall back to `.function`. |
| AI › Provider › Provider | `aiProvider` | `"anthropic"` | Picker (Anthropic / OpenRouter) | `AIConfig.provider` picks the client (`AnthropicMessages` / `OpenRouterChat`) for completions, Ask AI and Test connection. It also switches which key field is shown. | UNIT: AIPromptTests.testConfigFallsBackToDefaults, AIPromptTests.testDefaultModelIsTheFirstPresetOfEachProvider | ⚠ Switching provider does not reset `aiModel`. A saved Anthropic id (such as `claude-opus-5`) shows as "Custom…" and is sent to OpenRouter, which expects `anthropic/…`. The reverse happens when switching back. |
| AI › Provider › Anthropic API key / OpenRouter API key | Keychain `dev.ride.Ride` account `anthropic` / `openrouter` (not in prefs.json) | empty | SecureField, one shown per provider | Saved on Return, on focus change, or when the pane disappears (`commitKey` → `Keychain.write`; empty deletes). Read by `AnthropicMessages` / `OpenRouterChat`. | NONE | ⚠ Likely stale key on Test connection: clicking a button on macOS does not take focus, so a key typed without Return is not saved yet and the test reads the old key or none. Not verified at runtime. |
| AI › Provider › Model (+ "Model ID" field when Custom…) | `aiModel` | `""` (means provider default: `claude-haiku-4-5` / `anthropic/claude-haiku-4.5`) | Picker of provider presets + Custom…, then TextField | `AIConfig.model` (trimmed, empty → first preset) for completions, Ask AI and Test connection. Picking a preset writes it. Custom… shows the TextField bound to the key. | UNIT: AIPromptTests.testModelChoiceMapsStoredModelToPickerSelection, AIPromptTests.testConfigFallsBackToDefaults | Choosing Custom… keeps the old id until the user edits the field. |
| AI › Check › Test connection | — (not a pref) | — | Button + result text | Sends a fixed Rust prompt through `AIClient.complete` with the current config and shows "OK: …", "Connected, no suggestion returned" or the error. | NONE | See the key-commit ⚠ above. |

### Stored with no Settings control

| Setting (pane › label) | Key | Default | Control | Where read / what it changes | Coverage | Notes/⚠ |
|---|---|---|---|---|---|---|
| no UI (View › Soft Wrap) | `softWrap` | true | menu toggle only | `RideTextView.applySoftWrap` (text container width tracking, horizontal scroller). | NONE | ⚠ Inconsistent: its sibling display toggles (line numbers, indent guides, whitespace, code vision) appear in both the View menu and Settings, but soft wrap is menu-only. |
| no UI (sidebar divider drag) | `sidebarWidth` | 230 | drag | `RootView` sidebar ideal width + `SplitPositioner`; `saveLayout` saves after 0.6 s (prefs + workspace). Clamp 180…420. | UNIT: WorkspaceStateTests.testRoundTripThroughJSON (LayoutState persistence only) | Also stored per workspace. `applyLayout` overwrites the global value when a workspace opens (same leak as outlinePanel). |
| no UI (outline divider drag) | `outlineWidth` | 220 | drag | `DetailColumn` outline width. Clamp 160…420. | UNIT: WorkspaceStateTests.testRoundTripThroughJSON | Per-workspace override, as above. |
| no UI (hierarchy divider drag) | `hierarchyWidth` | 220 | drag | `DetailColumn` call-hierarchy panel width. Clamp 160…420. | UNIT: WorkspaceStateTests.testRoundTripThroughJSON | As above. |
| no UI (preview divider drag) | `previewWidth` | 460 | drag | `DetailColumn` Markdown preview width. Clamp 260…900. | UNIT: WorkspaceStateTests.testRoundTripThroughJSON | As above. |
| no UI (Problems divider drag) | `problemsHeight` | 180 | drag | `DetailColumn` Problems panel height. Clamp 80…480. | UNIT: WorkspaceStateTests.testRoundTripThroughJSON | As above. |
| no UI (Run output divider drag) | `runOutputHeight` | 200 | drag | Run output panel height. Clamp 80…480. | UNIT: WorkspaceStateTests.testRoundTripThroughJSON | As above. |
| no UI (Terminal divider drag) | `terminalHeight` | 220 | drag | Terminal panel height. Clamp 80…480. | UNIT: WorkspaceStateTests.testRoundTripThroughJSON | As above. |
| no UI (Tests divider drag) | `testsHeight` | 200 | drag | Tests panel height. Clamp 80…480. | UNIT: WorkspaceStateTests.testRoundTripThroughJSON | As above. |
| no UI (Debug divider drag) | `debugHeight` | 320 | drag | Debug panel height. Clamp 320…600 (the default sits at the minimum). | UNIT: WorkspaceStateTests.testRoundTripThroughJSON | As above. demo: DemoScene+Run bumps it. |
| no UI (internal) | `reportsAcknowledged` | 0 | set when the crash-report notice is dismissed (`acknowledgeReports`) | `checkCrashReports` shows only reports newer than this timestamp. | UNIT: ReportStoreTests.testAcknowledgedFilterDropsOlderReports | |

General gaps: no unit test covers `Preferences` decoding (missing keys → defaults), `clamped`, or `PreferencesStore` load/save. No self-test flips any Settings control. The only pref changes in self-tests are zoom, direct `lineNumbers` assignment, and `autoSave` off.


---

## 8. Summary

### Coverage counts

| Area | SELFTEST | UNIT (incl. RUST) | NONE | Total | ⚠ |
|---|---|---|---|---|---|
| App menu, Help, File, Edit | 20 | 16 | 24 | 60 | 18 |
| View, Navigate + overlays/panels | 23 | 10 | 50 | 83 | 16 |
| Code, Build + popups/sheets | 27 | 35 | 44 | 106 | 21 |
| Run, Debug, Tests, Terminal, Targets | 27 | 24 | 22 | 73 | 19 |
| Editor keys/mouse, tabs, status bar, welcome, entry points | 21 | 31 | 22 | 74 | 19 |
| Sidebar, Problems, Find bar, Project find, other | 6 | 26 | 26 | 58 | 12 |
| Preferences | 3 | 16 | 18 | 37 | 10 |
| **Total** | **127** | **158** | **206** | **491** | **115** |

### Cross-cutting findings (shortcuts, enablement, docs)

- **Standard macOS text keys taken over by the menu:**
  - ⌘⌫ is Delete Line (normally delete to line start).
  - ⇧⌘↑/↓ is Move Statement (normally select to document start/end).
  - ⌥↑/↓ is Extend/Shrink Selection (normally paragraph moves).
  - ⌥⇧↑/↓ is Move Line.
  - ⌃H is Type Hierarchy (normally deleteBackward).
  - ⌃W is Select Word, which also steals the shell's delete-word inside the SwiftTerm terminal.
  - These key equivalents apply app-wide, including text fields, the tree and the terminal, even though the commands only act when the editor is first responder.
- **Clashes with macOS system shortcuts:**
  - ⌃↑/⌃↓ (Previous/Next Method) are the defaults for Mission Control and App Exposé.
- **Possible clashes with SwiftUI's automatic menus (not verified at runtime):**
  - `.textEditing` is not replaced, so the default Edit › Find submenu may also bind ⌘F, ⌥⌘F, ⌘G, ⇧⌘G and ⌘E. ⌘E would collide with Navigate › Recent Files.
  - The toolbar command group is not replaced, so View › Show Toolbar (⌥⌘T) may collide with Code › Surround With…
- **Two dispatch paths for the same key:**
  - ⌃⌥↑ in `keyDown` is a hidden second binding for Switch Header / Source. It is not in the menu, the Shortcuts panel or the docs.
- **Keyboard Shortcuts panel (`Design/Shortcuts.swift`) is incomplete and partly wrong:**
  - It is missing at least ⇧⌘N, ⇧⌘↑/↓, ⌥⇧⌘C, ⌥⌘E, ⇧⌘H, ⌃⌥H, ⌃H, ⌥⌘⌫, ⇧⌘V, ⌥⌘L, ⇧⌘↩, ⌃⌘G, ⌥⌘V, ⌥⌘C, ⌃⌥N, ⌥↩, ⌃?, F1 and ⇧F1.
  - `ShortcutsManualTests` compares the panel to the docs, not to the menus, so it cannot catch this drift.
  - The Welcome screen hint says "⌘/ All shortcuts", but ⌘/ is Comment Line; the panel is on ⌘?.
  - The status-bar Check tooltip says ⇧⌘M, but the real shortcut is ⌘6.
- **Enablement is inconsistent:**
  - About 20 Code/Edit items have no `.disabled` and stay enabled with no editor. Their neighbours are gated on `hasEditor`.
  - `canGenerate` and `canRefactor` include C, but the engine offers no generators and no extract for plain C.
  - Check Project is enabled on `hasWorkspace` but only works with a compile_commands.json.
- **Self-tests skip every popup menu:**
  - Generate, Surround With and Intention steps call `applyGenerator`, `SurroundWith.apply` and `applyIntention` directly.
  - The NSMenu construction and pick paths are never exercised.
  - The "doc pin" step calls a test-only `pin()`, not the button's `togglePin()`.
- **Dead setting:** `prefs.visibleWhitespace` (View › Show Whitespace and Settings) is stored and toggled but never read by the editor. Verified by grep.
- **Resource leak:** Close Workspace never calls `RideEngineClient.closeWorkspace()` (nothing calls it) and never stops the file watcher. Verified by grep.
- **Toggle that cannot close:** Go to Symbol in File (⌥⌘O) calls `closeOverlays()` first, which clears `showSymbolInFile`, and only then toggles it. Pressing the shortcut again reopens the overlay instead of closing it. Verified in `AppState+Nav.swift`.
- **Invalid rustc flag:** the "undefined" sanitizer emits `-Zsanitizer=undefined`, which is not a rustc sanitizer. `RunConfigTests` asserts this value. Verified by grep.

### NONE items by area

#### App menu, Help, File, Edit
- Ride › About Ride
- Ride › Quit Ride (confirmQuit)
- File › New Buffer
- File › New Folder…
- File › Open…
- File › Close Workspace
- File › Save As…
- File › Revert to Saved
- File › Close Editor
- File › Close All
- File › Close Others
- Edit › Find…
- Edit › Find and Replace…
- Edit › Use Selection for Find
- Edit › Find in Project…
- Edit › Replace in Project…
- Edit › Cut (line-mode override)
- Edit › Copy (line-mode override)
- Edit › Paste / Paste and Match Style (plain-text override)
- New Project › Location › Choose…
- New Project › Cancel
- New File prompt › OK
- New File prompt › Cancel
- Save panel › Save / Cancel

#### View, Navigate + overlays/panels
- View › Project Sidebar
- View › Outline
- View › Problems
- View › Run Output
- View › Tests
- View › Usages
- View › AI Chat
- View › Zoom Out
- View › Soft Wrap
- View › Show Whitespace
- View › Indent Guides
- View › Code Vision
- Navigate › Open Quickly…
- Navigate › Recent Files…
- Navigate › Last Edit Location
- Navigate › Go to Symbol in File…
- Navigate › Next Problem
- Navigate › Previous Problem
- Navigate › Previous Method
- Picker › Esc
- Picker › click outside card
- Picker › Return in query field
- Picker › click row
- Picker › selection follows keys
- Open Quickly › type query
- Open Quickly › ↓ / ↑
- Open Quickly › ↩ / click row
- Recent Files › type query
- Recent Files › ↓ / ↑
- Recent Files › ↩ / click row
- Go to Line › type query
- Symbol in File › type query
- Symbol in File › ↓ / ↑
- Symbol in File › ↩ / click row
- Symbol in Project › ↓ / ↑
- Symbol in Project › ↩ / click row
- Symbol in Project › ⌘C copy path
- Hierarchy header › Hide Hierarchy
- Hierarchy › click row
- Usages header › Hide Usages
- Usages › click usage row
- Outline header › Hide Outline
- Outline › click row
- Preview header › Close Preview
- Preview › click link
- Rename box › Return
- Rename box › Esc
- Rename box › Tab / click away
- Rename sheet › Select All
- Rename sheet › Cancel

#### Code, Build + popups/sheets
- Surround › { … }
- Surround › [ … ]
- Surround › " … "
- Surround › if (Rust)
- Surround › loop (Rust)
- Surround › unsafe (Rust)
- Surround › match (Rust)
- Surround › Some( … ) (Rust)
- Surround › Ok( … ) (Rust)
- Surround › if (C/C++)
- Surround › while (C/C++)
- Surround › #if 0 … #endif (C/C++)
- Surround › /* … */
- Surround › <!-- … -->
- Intentions › Include <header> (C/C++)
- Cheat Sheet › Close (Esc)
- Cheat Sheet › Click row (browse)
- Cheat Sheet › Click same row again / double-click (insert)
- Completion › Dismiss (Esc)
- Completion › Move selection (↑/↓)
- Completion › Open source (⌘-click)
- Signature help › Hide (Esc)
- Signature help › Hide on newline (↩)
- Doc panel › Pin button
- Doc panel › Web link
- Doc panel › Hide (Esc)
- Doc panel › Auto hide
- Peek › Open button
- Peek › Open (F12 while visible)
- Peek › Pin button
- Peek › Hide (Esc)
- Ask AI › Context picker
- Ask AI › Cancel
- Ask AI › Send
- AI panel › Copy answer
- AI panel › Edit the request and ask again
- AI panel › Hide AI panel
- Tools › Row checkbox
- Tools › Copy / Copied
- Tools › Don't ask again at launch
- Tools › Close
- Tools › Install Selected
- Settings › Install `ride` command › Install
- Settings › Install `ride` command › Retry

#### Run, Debug, Tests, Terminal, Targets
- `Run › Edit Configurations…`
- `Debug › Evaluate Expression…`
- `Run header › Rerun`
- `Run Config › Environment › Add`
- `Run Config › Environment row remove`
- `Run Config › Cancel`
- `Tests header › Clear`
- `Tests header › Hide Tests`
- `Tests list › row click`
- `Debug header › Evaluate Expression`
- `Debug header › Hide Debug`
- `Watches › row Remove Watch`
- `Evaluate › Close`
- `Gutter › right-click (open breakpoint editor)`
- `Breakpoint editor › Cancel`
- `Toolbar › Toggle Sidebar`
- `Toolbar › Target picker › Project toggles`
- `Toolbar › Markdown Preview`
- `Toolbar › Problems`
- `Toolbar › Open Quickly`
- `Targets › project switcher`
- `Targets › profile picker`

#### Editor keys/mouse, tabs, status bar, welcome, entry points
- Completion popup › ↑ / ↓
- Completion popup / cheat sheet › Esc
- Editor › Esc chain (`cancelOperation`)
- Popup navigation ⌃P / ⌃N (`doCommand`)
- Editor › any key hides hover / unpinned docs
- Edit › Copy with no selection (line copy)
- Edit › Cut with no selection (line cut)
- Editor › Option-click / middle-click in text
- Editor › right-click context menu
- Gutter › click intention bulb / diagnostic dot
- Tab ctx › Copy Path
- Tab ctx › Copy Relative Path
- Tab ctx › Reveal in Finder
- Side-panel handle drag (Preview / Outline / Hierarchy)
- Status › Check summary segment click
- Welcome › Open Folder…
- Welcome › shortcut hints
- Confirm › Delete (Trash)
- Confirm › Revert
- Alert › Save changes (Save / Don't Save / Cancel)
- Alert › Changed on disk (Overwrite / Reload / Cancel)
- Launch args `--demo <scene>` and scene flags

#### Sidebar, Problems, Find bar, Project find, other
- Tree row › click (select)
- Tree ctx › Set as Active Project
- Tree ctx › New Folder
- Tree ctx › Duplicate
- Tree ctx › Delete
- Tree ctx › Copy Path
- Tree ctx › Copy Relative Path
- Tree ctx › Reveal in Finder
- Rename / New Folder prompt › OK / Cancel
- Problems header › Show errors
- Problems header › Show warnings
- Problems header › Hide Problems
- Problems row › click
- Find bar › Replace toggle
- Find bar › Replace field (typing / Return)
- Find bar › Close
- Find bar › Esc
- Project find › ↑ / ↓
- Project find › Esc / backdrop click
- Replace preview › Select All
- Replace preview › Select None
- Replace preview › Cancel
- Unsaved-changes alert › Save / Don't Save / Cancel
- Changed-on-disk alert › Overwrite / Reload / Cancel
- Hover popup › click
- Overlay backdrop › click

#### Preferences
- General › Show hidden files
- Editor › Completions as you type
- Editor › AI suggestions in the completion popup (and its AI-pane duplicate)
- Editor › Cheat sheet with completions
- Editor › Signature help
- Editor › Documentation on hover
- Editor › Outline panel
- Editor › Indent guides
- Editor › Visible whitespace
- Editor › Code vision
- Tools › Check on save
- Tools › Use Clippy for live diagnostics
- Tools › Format on save
- Tools › Check for missing tools at launch
- Tools › Install `ride` command
- AI › API key fields (Keychain)
- AI › Test connection
- softWrap (no UI, View › Soft Wrap)

### ⚠ list by area

#### App menu, Help, File, Edit
- About Ride: `AboutPanel.engineVersion` is hard-coded "0.1.0" (Cargo.toml is 1.0.0) and is also the fallback app version.
- Keyboard Shortcuts: the list is incomplete (missing ⇧⌘N, ⇧⌘↑/↓, ⌥⇧⌘C, ⌥⌘E, ⇧⌘H, and more outside this scope). The only test compares it to the docs, not to the menus. Panel appearance is frozen at first open.
- New File…: always defaults to Rust/`.rs`, while the tree's New File follows the project kind (two different flows). Confirming "Replace" on an existing file does not clear it.
- New Folder…: `createDirectory` failures are swallowed (`try?`), so the user gets no message.
- Open Recent: items show only the folder name, so same-named folders can't be told apart. No Clear Menu.
- Close Workspace: never calls `RideEngineClient.closeWorkspace()` (never called anywhere) or `watcher.stop()`. The engine workspace and the FSEvents watcher stay alive.
- Revert to Saved: enabled for untitled buffers, where it does nothing.
- Save All: skips untitled buffers silently and turns off format-on-save, unlike Save.
- Reindex: starts the helper and never checks it. No feedback if the helper is missing or fails.
- Edit line/selection commands: always enabled but do nothing unless the editor is first responder. Their key equivalents apply everywhere, so the menu takes ⌃W in the SwiftTerm terminal (the shell's delete-word), plus ⇧↩, ⌘⌫ and ⌥↑/↓ in text fields, the tree and the terminal.
- Select Line / Select Word / Extend / Shrink Selection: do nothing on read-only buffers (`isEditable` guard), though they don't edit.
- Shortcuts that replace standard macOS text keys: ⌘⌫ (Delete Line), ⇧⌘↑/↓ (Move Statement, replaces select to document start/end), ⌥↑/↓ (Extend/Shrink), ⌥⇧↑/↓ (Move Line).
- Move Statement Up/Down: enabled for every language, but the engine returns no bounds outside Rust/C/C++, so it does nothing there.
- Find group: probable duplicate key equivalents. `.textEditing` is not replaced, so SwiftUI's default Edit › Find submenu likely also binds ⌘F, ⌥⌘F, ⌘G, ⇧⌘G and ⌘E (the last clashes with Navigate › Recent Files ⌘E). I couldn't confirm this from the code; check it at runtime.
- Find… / Find and Replace…: they toggle, so pressing again closes the bar instead of focusing it. Use Selection for Find doesn't show the bar (the plan asked for ⌘E; it is ⌥⌘E).
- Replace in Project…: same handler as Find in Project. It doesn't focus the replace field, and closes the panel if it is already open.
- New Project › Create: the validation branch in `create()` can never run (the button is disabled by the same check).
- Save panel Language popup: a buffer language not in the list preselects Rust while the name keeps its real extension.

#### View, Navigate + overlays/panels
- Navigate › Go to Symbol in File…: the toggle can never close. `closeOverlays()` clears `showSymbolInFile` before `.toggle()`, so ⌥⌘O always reopens it.
- Navigate › Open Quickly…: `toggleQuickOpen` hides only Find and skips `closeOverlays()`, so it stacks over the other pickers.
- Navigate › Open Quickly…: enabled with no workspace, while the toolbar button is disabled, and the overlay stays empty.
- Navigate › Next/Previous Method: the title says "Method" but it walks every outline item (types, consts, fields, headings).
- Navigate › Next/Previous Method: ⌃↓/⌃↑ collide with the macOS default App Exposé/Mission Control shortcuts.
- Navigate › Type Hierarchy: ⌃H takes over the Cocoa text-system ⌃H (deleteBackward) in the editor.
- Navigate › Switch Header / Source: there is an undocumented second binding, ⌃⌥↑ in `RideTextView.keyDown`, that is not in the menu or the Shortcuts sheet.
- Navigate › Rename…: fails silently when there is no identifier, the buffer is read-only, there is no session or the plan is empty. Safe Delete shows a notice for the same cases.
- Navigate › Safe Delete…: the "Place the caret on an item name" notice also shows for read-only or session-less buffers, which is misleading.
- Rename inline box: nothing handles the end of editing, so after a click away or Tab the field stays stuck over the editor.
- Symbol in Project › ⌘C "copy path": `onCopyCommand` sits on the non-focusable list, so it is likely inert (the query field has focus).
- Safe Delete sheet › review row tick: deletes the identifier token at each ticked usage and leaves broken code.
- RenamePreviewSheet: the `root` property is unused and `label(_:)` is an identity function (dead code).
- Design/Shortcuts.swift (Shortcuts sheet): missing Call Hierarchy ⌃⌥H, Type Hierarchy ⌃H, Safe Delete ⌥⌘⌫ and Toggle Markdown Preview ⇧⌘V.
- Hierarchy panel: no View-menu toggle to reopen it. `showHierarchy.didSet` calls `syncMenu()`, but there is no MenuModel flag for it.
- View › Toggle Markdown Preview: a `Button` instead of a `Toggle`, so no checkmark, unlike the sibling panel items.

#### Code, Build + popups/sheets
- Code › Generate…: enabled for C (`canGenerate` includes `.c`), but the engine offers no generators for C. It always shows "Nothing to generate here".
- Code › Extract Variable: enabled for C (`canRefactor`), but the engine refuses plain C (`extract::keyword` has no C keyword). It always shows the notice.
- Code › Quick Documentation: two visible menu rows with the identical title and handler (⌃J and F1).
- Build › Check Project: runs only the clang compile_commands check. In a Cargo workspace it errors with "clang: no compile_commands.json", yet it is enabled on `hasWorkspace`.
- Build › Check: any non-clang buffer runs `cargo check` on the project root, even for CMake/Make projects or with a Markdown/TOML file active. No `.disabled`.
- Code › Reformat Selection: reformats the whole document for languages other than C, C++ and Rust (falls back to `formatBuffer`).
- Code › Surround With… (⌥⌘T): probably collides with SwiftUI's automatic View › Show/Hide Toolbar, since the window has a `.toolbar` and the toolbar command group is not replaced (not verified).
- Code › Ask AI from Comment…: `⌃?` needs Shift on US layouts. With no comment at the caret, the previous prompt is reused.
- Code › External Documentation: does nothing silently (no notice) for workspace symbols or when there is no definition hit.
- Enablement inconsistency: Comment Line/Block, Indent, Unindent, Auto-Indent, Reformat Document/Selection, Complete Statement, Surround, Fold/Unfold (all four), Trigger Completion, Cheat Sheet, Signature Help and Check have no `.disabled`. They stay enabled without an editor and do nothing silently, while neighbouring items are gated on `hasEditor`.
- Generate › impl block (Rust): hidden only when an inherent impl has `fn new`. It can add a duplicate empty impl.
- Generate › Constructor/Getters/Setters/Equality/Stream (C++): always offered, even if already present (no already-present filter).
- Surround › if / match / while templates: the placeholder words `condition` and `value` are not selected, and the wrapped body is not re-indented.
- Selftests bypass every popup: they call `applyGenerator`, `SurroundWith.apply` (ad-hoc template) and `applyIntention` (test-only) directly. `generate()`, `surroundWith()`/`templates(for:)` and `IntentionMenu` popup construction are never run.
- Doc panel › Pin button: the "doc pin" selftest calls the test-only `DocController.pin()`, not `togglePin()`, which the button uses.
- Ask AI › Send: the ↩ default action is probably swallowed by the focused TextEditor (not verified). A dead document or view drops the request silently.
- AI panel › Edit the request and ask again: reuses the stale selection and view from the earlier ask.
- Tools › Copy: the "Copied" label never resets.
- Settings › Install `ride` command (`RideCommandRow`): listed in this area's scope, but it lives in Settings, not in the Install Tools sheet.
- Shortcuts manual (`Design/Shortcuts.swift`) omits Reformat Selection ⌥⌘L, Complete Statement ⇧⌘↩, Generate ⌃⌘G, Extract Variable ⌥⌘V, Introduce Constant ⌥⌘C, Inline Variable ⌃⌥N, Intentions ⌥↩, Ask AI ⌃?, Quick Doc F1 and External Docs ⇧F1.

#### Run, Debug, Tests, Terminal, Targets
- `Run › Build`, `Run`, `Run Tests`, `Run File`: dirty buffers are not saved before running. They rely on the 1 s autosave, so stale sources can be built or run.
- `Run › Run Tests`: the selected run target's config args are appended to the test argv.
- `Run › Edit Configurations…`: the enablement (`canBuild`) differs from the handler guard (`runTarget != nil`).
- `Debug › Debug`: while a process runs, `DebugChain` is keyed to the old `runOutput.runId`. "Stop and Rerun" never launches the debugger, and "Cancel" launches it when the old run exits.
- `Debug › Debug`: the Cargo binary path ignores `--target <triple>` (sanitizer builds), `examples/` and the build profile, so it can debug a stale or missing binary.
- `Debug › <exception filter>`: toggles do not reach a live session and are not persisted.
- `Run header › Rerun`: after Run File it reruns the old binary without recompiling. After Debug it reruns only the build.
- `Run Config › Arguments`: one field serves as Cargo flags for Build and Test and as program args for Run and Debug.
- `Run Config › sanitizer toggles`: CMake flags are computed but never applied (the RunPlanner drops them and the engine's configure has no hook), which contradicts the feature inventory. The toggles are a no-op for Make and compile-db.
- `Run Config › undefined`: `-Zsanitizer=undefined` is not a valid rustc sanitizer. The unit test asserts it.
- `Gutter › run marker (main)`: it runs the selected target, not the binary that owns the clicked `main`.
- `Debug header › Hide Debug`: `syncMenu()` is not called, so the `Debug › Debug Panel` checkmark goes stale.
- `Gutter › right-click`: this is the only entry to the breakpoint editor, and on an empty line it silently adds a breakpoint.
- `Breakpoint editor`: condition and hit count only. It has no log message, enable/disable or remove.
- `Debug hover`: a failed or empty evaluation suppresses the normal definition hover while stopped.
- `Toolbar › Check`: the play.circle icon suggests Run. Its enablement differs from `Build › Check`.
- `Toolbar`: there are no Run, Stop or Debug toolbar buttons at all, although the task scope expected them.
- `Targets › profile picker`: it has no effect on Build or Run, does not reload CMake targets, breaks the Cargo Release debug path, does not sync the menu and is not persisted.
- `Targets › target row click`: it bypasses `selectTarget`, so the selection is not saved to the workspace.

#### Editor keys/mouse, tabs, status bar, welcome, entry points
- ⌃⌥↑ Switch Header/Source: a hidden `keyDown` shortcut that is not in the menu (F10 there), not in `Shortcuts.swift`, and not in the manual.
- Cheat sheet with completion open: the ⌥↑ / ⌥↓ / ⌥↩ routing is shadowed by Edit › Extend / Shrink Selection and Code › Show Intention Actions.
- Completion popup arrow keys ignore modifiers: ⇧↑ and ⌘↑ move the list instead of the selection or caret.
- Esc with nothing open: `super.cancelOperation` falls through to NSTextView's default `complete:` (the system word-completion list). Nothing overrides it. Not checked at runtime.
- The same key handling exists in three places: `doCommand` moveUp/moveDown (reachable only via ⌃P/⌃N) and the `accept()` calls in `insertTab` / `insertNewline` repeat what `keyDown` already does.
- Editor right-click: stock NSTextView menu only, with no IDE actions. Its Substitutions and Spelling items can re-enable features the editor turns off.
- Gutter fold chevron: in a split, clicking the unfocused pane's chevron folds that line number in the focused pane (`FoldController.toggle` uses `focusedView`).
- Gutter intention bulb is drawn but can't be clicked.
- Gutter ▶ on `main` runs the selected run target (`runAction(.run)`), not necessarily the clicked file's binary.
- Tab ctx › Close Others: Cancel doesn't stop the loop, and it also closes tabs in the other split pane.
- Tab ctx › Open in Split on a tab in the unfocused pane does nothing: "neighbour of focused" is the tab's own pane.
- `PaneTabStrips` leaves out the Hierarchy panel width, so the tab strips don't line up with the split panes while Hierarchy is open.
- Status Check segment tooltip says ⇧⌘M; the real shortcut is ⌘6.
- Status line-ending › Convert to LF changes the global line-ending preference, not just the file. Keep shows no current state and doesn't undo a Convert.
- Status "Spaces: N" is wrong for Makefiles (Tab inserts `\t`) and can't be clicked.
- Welcome hint "⌘/ All shortcuts" is wrong: ⌘/ is Comment Line, and Keyboard Shortcuts is ⌘?.
- `--open` accepts only folders and silently ignores file paths, unlike `ride://` and Finder opens.
- `Confirm.ask`, `confirmClose` and `BreakpointEditor` all auto-answer in demo mode, so no dialog button (Cancel, Don't Save, Revert, Delete) is ever exercised by the self-test.

#### Sidebar, Problems, Find bar, Project find, other
- Sidebar header / Tree ctx › New File: always creates in the workspace root from the header, ignoring the selection. It is a second New File flow (NSAlert + LanguageNameField) that differs from File › New File… (NSSavePanel + SaveLanguagePicker, selected folder). The `createFile` result is ignored, so a name with a missing subfolder opens a file that does not exist.
- Tree ctx › New Folder and Duplicate: errors are swallowed by `try?` (for example an existing name gives no feedback). They skip `reloadTree()` and rely on the FS watcher, while File › New Folder… reloads.
- Tree ctx › Rename: breakpoints are not migrated to the new path (Delete forgets them, Rename leaves them orphaned). `expanded`, `selectedURL` and `TreeKeyFocus.url` keep the old URL.
- Tree ctx › Delete: tabs of trashed files stay open with no notice (`differsFromDisk()` returns false for a missing file). A later save or autosave silently recreates the file.
- Tree keys (↩ / ⌫ / ⌦): `TreeKeyFocus.url` is set only on row click and never updated after rename or delete, so a second key press acts on a stale path (rename-failed notice, or a delete confirmation for a missing item). Modifiers are ignored, so ⌘⌫ and ⌥↩ act the same. Plain ⌫ trashes, where Finder uses ⌘⌫. The selftest "tree keys" has an empty `run` and only checks `TreeModel.action`.
- Problems header › Check: when the active buffer is not C/C++, it always runs cargo check (`engine.runCheck`), including in C/CMake/Make projects, which gives a failure badge. It ignores `prefs.useClippy`.
- Problems row ctx › fix: `applyDiagnosticFix` applies after a fixed 0.1 s delay and silently drops the fix if the file is not focused by then.
- Problems row selection: the highlight is stored as an index into the filtered list, so it jumps to another diagnostic when filters toggle or results refresh.
- clang-tidy on save (ClangTidyService trigger): findings are written into the live slot, which replaces that file's live compiler diagnostics and hides its save-check clang diagnostics, so errors disappear from Problems. The next live check then erases the tidy findings.
- Find bar › Close (xmark): does not give focus back to the editor. Esc does.
- Project find › query/replace: the query is whitespace-trimmed in search, replace and highlight, so leading or trailing spaces (for example `" = "`, or regexes with edge spaces) cannot be searched literally. `needsRun` compares the untrimmed text.
- Project find › result rows: the highlight uses a case-insensitive substring of the raw query and ignores the regex, whole-word and case options (regex queries show wrong or no highlight).

#### Preferences
- Visible whitespace (`visibleWhitespace`): stored and toggled from Settings and `View › Show Whitespace`, but the editor never reads it. Dead setting.
- Font size: Settings stepper range 11…18 disagrees with zoom and `clamped` (10…24).
- Font size: changes do not reach open terminals (only on theme change or a new terminal).
- Completions as you type: off also blocks the explicit `Code › Trigger Completion` (⌥Space) popup for engine items.
- Check on save: under "cargo check", but it also gates clang/clang-tidy save checks and all live diagnostics, and silently turns off the Clippy toggle.
- Format on save: under "rustfmt", but it applies to any engine formatter (C/C++ too).
- Outline panel and all panel sizes: `applyLayout` on workspace restore writes per-workspace values into global prefs without saving. The next `updatePrefs` saves them as the global default, and Settings shows the workspace's value.
- Provider picker: switching provider keeps the other provider's model id, so an invalid id goes to the new provider.
- API key fields + Test connection: a key typed without Return or a focus change is not in the Keychain yet, so Test connection likely uses the old key or none (not verified at runtime).
- Soft wrap: the only display toggle that is menu-only. It has no Settings control, unlike its siblings.
