use ride_engine::{BufferSession, CaptureKind, Lang, render_markdown};

#[test]
fn renders_tables_task_lists_and_line_anchors() {
    let md = "# Title\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n- [x] done\n- [ ] todo\n\n~~gone~~ and a [link](https://x.y).\n";
    let html = render_markdown(md);
    assert!(html.contains("<table>"), "{html}");
    assert!(html.contains("<th>a</th>"), "{html}");
    assert!(html.contains("<td>2</td>"), "{html}");
    assert!(html.contains("type=\"checkbox\""), "{html}");
    assert!(html.contains("<del>gone</del>"), "{html}");
    assert!(html.contains("<a href=\"https://x.y\">link</a>"), "{html}");
    assert!(html.contains("data-line=\"1\""), "{html}");
    assert!(html.contains("data-line=\"3\""), "{html}");
    assert!(html.contains("data-line=\"7\""), "{html}");
}

#[test]
fn rust_fences_are_highlighted_in_html() {
    let md = "```rust\nfn main() { let x = \"<hi>\"; }\n```\n\n```text\nfn nope() {}\n```\n";
    let html = render_markdown(md);
    assert!(
        html.contains("<span class=\"tk-keyword\">fn</span>"),
        "{html}"
    );
    assert!(
        html.contains("<span class=\"tk-function\">main</span>"),
        "{html}"
    );
    assert!(html.contains("&quot;&lt;hi&gt;&quot;"), "{html}");
    assert!(html.contains("fn nope() {}"), "{html}");
    assert!(
        !html.contains("<span class=\"tk-function\">nope</span>"),
        "{html}"
    );
}

#[test]
fn rust_fences_get_rust_highlights_in_the_editor() {
    let text = "# Doc\n\n```rust\nfn main() {\n    let x = 1;\n}\n```\n\nplain `code` here\n";
    let (session, update) =
        BufferSession::open_lang(Lang::Markdown, text.to_string(), None).unwrap();
    let spans: Vec<(CaptureKind, &str)> = update
        .highlights
        .iter()
        .map(|s| (s.capture, &text[s.start_byte as usize..s.end_byte as usize]))
        .collect();
    assert!(spans.contains(&(CaptureKind::Keyword, "fn")), "{spans:?}");
    assert!(
        spans.contains(&(CaptureKind::Function, "main")),
        "{spans:?}"
    );
    assert!(
        spans.contains(&(CaptureKind::Constant, "1"))
            || spans.contains(&(CaptureKind::Number, "1")),
        "{spans:?}"
    );
    assert!(
        spans.contains(&(CaptureKind::String, "`code`")),
        "{spans:?}"
    );
    assert!(session.outline().len() == 1);
}
