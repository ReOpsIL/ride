# Markdown view

A `.md` or `.markdown` file opens rendered in its editor pane. The pane header shows Rendered, and its button switches that pane to the source and back. ⌘\ still splits the editor, so one pane can hold Rust (or any other file) while the other holds the page.

The page is the buffer, including unsaved edits, rendered with the same engine as the side preview. A reload from disk replaces the buffer and the view loads again. Changing the theme loads the page again. Images and other files load only from that file's folder. A link to another markdown file in that folder opens rendered. A link to `http` or `https` opens in the browser. Other targets, including `javascript:` and `file:`, are dropped. The page gets a content-security policy that allows its own inline style and the files next to it, and nothing from the network.

Source is the editor, with the editor find bar. The rendered page uses the system find bar (⌘F, ⌘G, ⇧⌘G, ⌥⌘F). Switching tabs, or switching between the page and the source, keeps the page's vertical scroll.

View › Toggle Markdown Preview still opens the side preview for the focused markdown buffer and follows the visible lines.
