const OPENERS: &[&str] = &["ifdef", "ifndef", "if"];
const BRANCHES: &[&str] = &["elifdef", "elifndef", "elif", "else"];
const INLINE_TAILS: &[u8] = b")(,=<>&|+-*/?:";

struct Frame {
    depth: usize,
    branch_start: usize,
}

pub fn strip_inline_conditionals(buf: &mut [u8]) -> bool {
    let mut depth = 0usize;
    let mut changed = false;
    let mut frames: Vec<Frame> = Vec::new();
    let mut lines = Vec::new();
    let mut start = 0;
    for (i, b) in buf.iter().enumerate() {
        if *b == b'\n' {
            lines.push((start, i + 1));
            start = i + 1;
        }
    }
    if start < buf.len() {
        lines.push((start, buf.len()));
    }
    for index in 0..lines.len() {
        let (from, to) = lines[index];
        let Some(word) = directive(&buf[from..to]) else {
            continue;
        };
        if OPENERS.contains(&word) {
            depth += 1;
            if inline_context(buf, &lines, index) {
                blank(buf, from, to);
                changed = true;
                frames.push(Frame {
                    depth,
                    branch_start: to,
                });
            }
        } else if BRANCHES.contains(&word) {
            if let Some(frame) = frames.last_mut().filter(|f| f.depth == depth) {
                blank(buf, frame.branch_start, to);
                frame.branch_start = to;
            }
        } else if word == "endif" {
            if frames.last().is_some_and(|f| f.depth == depth) {
                frames.pop();
                blank(buf, from, to);
            }
            depth = depth.saturating_sub(1);
        }
    }
    changed
}

fn directive(line: &[u8]) -> Option<&'static str> {
    let trimmed = trim(line);
    let rest = trim(trimmed.strip_prefix(b"#")?);
    OPENERS
        .iter()
        .chain(BRANCHES)
        .chain(&["endif"])
        .copied()
        .find(|word| {
            rest.starts_with(word.as_bytes())
                && rest
                    .get(word.len())
                    .is_none_or(|b| !b.is_ascii_alphanumeric() && *b != b'_')
        })
}

fn inline_context(buf: &[u8], lines: &[(usize, usize)], index: usize) -> bool {
    lines[..index]
        .iter()
        .rev()
        .map(|(from, to)| trim(&buf[*from..*to]))
        .find(|line| !line.is_empty() && !line.starts_with(b"#") && !is_comment(line))
        .and_then(|line| line.last())
        .is_some_and(|last| INLINE_TAILS.contains(last))
}

fn is_comment(line: &[u8]) -> bool {
    line.starts_with(b"//") || line.starts_with(b"/*") || line.starts_with(b"*")
}

fn trim(line: &[u8]) -> &[u8] {
    let is_space = |b: &u8| matches!(b, b' ' | b'\t' | b'\r' | b'\n');
    let start = line.iter().position(|b| !is_space(b)).unwrap_or(line.len());
    let end = line
        .iter()
        .rposition(|b| !is_space(b))
        .map(|i| i + 1)
        .unwrap_or(start);
    &line[start..end.max(start)]
}

fn blank(buf: &mut [u8], from: usize, to: usize) {
    for slot in &mut buf[from..to] {
        if *slot != b'\n' {
            *slot = b' ';
        }
    }
}

#[cfg(test)]
mod tests {
    use super::strip_inline_conditionals;

    fn run(src: &str) -> String {
        let mut buf = src.as_bytes().to_vec();
        strip_inline_conditionals(&mut buf);
        String::from_utf8(buf).unwrap()
    }

    #[test]
    fn keeps_the_last_branch_of_a_conditional_inside_a_declaration() {
        let src = "  explicit vector(const allocator_type& __a)\n#if _LIBCPP_STD_VER <= 14\n      _NOEXCEPT_(x)\n#else\n      noexcept\n#endif\n      : __alloc_(__a) {}\n";
        let out = run(src);
        assert_eq!(out.len(), src.len());
        assert!(!out.contains("_NOEXCEPT_"), "{out}");
        assert!(out.contains("      noexcept\n"), "{out}");
        assert!(!out.contains('#'), "{out}");
    }

    #[test]
    fn statement_level_conditionals_are_untouched() {
        let src = "int a;\n#if X\nint b;\n#else\nint c;\n#endif\n";
        assert_eq!(run(src), src);
    }

    #[test]
    fn nested_conditionals_keep_their_own_depth() {
        let src =
            "void f()\n#if A\n#  if B\n  noexcept\n#  endif\n#endif\n{}\n#if C\nint d;\n#endif\n";
        let out = run(src);
        assert!(out.contains("#if C\nint d;\n#endif\n"), "{out}");
        assert!(out.contains("  noexcept\n"), "{out}");
        assert!(!out.contains("#if A"), "{out}");
    }
}
