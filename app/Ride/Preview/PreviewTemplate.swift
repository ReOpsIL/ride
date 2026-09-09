import AppKit

enum PreviewTemplate {
    static func page(_ theme: Theme) -> String {
        let c = theme.chrome
        let syntax: [(String, NSColor)] = [
            ("keyword", theme.keyword), ("function", theme.function), ("type", theme.type),
            ("property", theme.property), ("variable", theme.variable), ("constant", theme.constant),
            ("string", theme.string), ("escape", theme.escape), ("comment", theme.comment),
            ("attribute", theme.attribute), ("lifetime", theme.lifetime), ("macro", theme.macro),
            ("number", theme.number), ("operator", theme.operatorColor),
            ("punctuation", theme.punctuation), ("label", theme.label),
        ]
        let tokens = syntax.map { ".tk-\($0.0){color:\(hex($0.1))}" }.joined()
        return """
        <!doctype html><html><head><meta charset="utf-8"><style>
        :root{color-scheme:\(theme.isDark ? "dark" : "light")}
        html,body{margin:0;background:\(hex(theme.editor.background));color:\(hex(c.textPrimary))}
        body{font:16px/1.55 -apple-system,BlinkMacSystemFont,"SF Pro Text",sans-serif;-webkit-text-size-adjust:100%}
        main{max-width:72ch;margin:0 auto;padding:28px 32px 96px}
        h1,h2,h3,h4,h5,h6{color:\(hex(theme.heading));line-height:1.25;margin:1.4em 0 .5em;font-weight:650}
        h1{font-size:2em;border-bottom:1px solid \(hex(c.border));padding-bottom:.3em}
        h2{font-size:1.5em;border-bottom:1px solid \(hex(c.border));padding-bottom:.25em}
        h3{font-size:1.25em}h4{font-size:1.05em}
        p,ul,ol,blockquote,table,pre{margin:0 0 1em}
        a{color:\(hex(c.accent));text-decoration:none}a:hover{text-decoration:underline}
        code,pre{font:13px/1.5 "SF Mono",ui-monospace,Menlo,monospace}
        code{background:\(hex(c.bgRaised));padding:.1em .35em;border-radius:4px}
        pre{background:\(hex(c.bgRaised));border:1px solid \(hex(c.border));border-radius:8px;padding:12px 14px;overflow-x:auto}
        pre code{background:none;padding:0}
        blockquote{border-left:3px solid \(hex(c.accent));color:\(hex(c.textSecondary));padding:.1em 1em;margin-left:0}
        table{border-collapse:collapse;width:auto}
        th,td{border:1px solid \(hex(c.border));padding:6px 12px;text-align:left}
        th{background:\(hex(c.bgRaised));font-weight:600}
        hr{border:0;border-top:1px solid \(hex(c.border));margin:1.5em 0}
        ul.contains-task-list,li.task-list-item{list-style:none;padding-left:0}
        li.task-list-item{margin-left:0}
        input[type=checkbox]{margin:0 .5em 0 0;vertical-align:middle;accent-color:\(hex(c.accent))}
        img{max-width:100%}
        del{color:\(hex(c.textTertiary))}
        .ride-line{display:block;height:0}
        \(tokens)
        </style></head><body><main id="main"></main>
        <script>
        function setBody(h){document.getElementById('main').innerHTML=h;}
        function scrollToLine(n){var best=null;document.querySelectorAll('.ride-line').forEach(function(e){var l=parseInt(e.dataset.line,10);if(l<=n&&(best===null||l>parseInt(best.dataset.line,10)))best=e;});if(best){window.scrollTo({top:best.getBoundingClientRect().top+window.scrollY-24});}}
        </script></body></html>
        """
    }

    static func hex(_ color: NSColor) -> String {
        let c = color.usingColorSpace(.sRGB) ?? color
        let r = Int((c.redComponent * 255).rounded())
        let g = Int((c.greenComponent * 255).rounded())
        let b = Int((c.blueComponent * 255).rounded())
        let a = c.alphaComponent
        if a < 0.999 {
            return String(format: "rgba(%d,%d,%d,%.3f)", r, g, b, a)
        }
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
