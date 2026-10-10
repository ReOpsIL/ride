# HTML view

An `.html` or `.htm` file opens rendered in its editor pane. The pane header shows Rendered, and its button switches that pane to the source and back. ⌘\ still splits the editor, so one pane can hold Rust (or any other file) while the other holds the page.

The page is the buffer, including unsaved edits. A reload from disk replaces the buffer and the view loads again. CSS, images, scripts and other files load only from that file's folder. A link to `http` or `https` opens in the browser. Other targets, including `javascript:` and `file:`, are dropped. The page gets a content-security policy that allows its own inline script and style and the files next to it, and nothing from the network.

Source is the plain-text editor, with the editor find bar. The rendered page uses the system find bar (⌘F, ⌘G, ⇧⌘G, ⌥⌘F). It does not keep a second copy of the text. Switching tabs, or switching between the page and the source, keeps the page's vertical scroll.
