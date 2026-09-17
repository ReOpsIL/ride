#[derive(Clone, Copy)]
enum Scan {
    Code,
    Str,
    Line,
    Block,
}

pub fn in_open_comment(text: &str, at: usize) -> bool {
    let bytes = &text.as_bytes()[..at.min(text.len())];
    let mut state = Scan::Code;
    let mut i = 0;
    while i < bytes.len() {
        let (next, step) = step(state, bytes, i);
        state = next;
        i += step;
    }
    matches!(state, Scan::Line | Scan::Block)
}

fn step(state: Scan, bytes: &[u8], i: usize) -> (Scan, usize) {
    let here = bytes[i];
    let next = bytes.get(i + 1).copied();
    match state {
        Scan::Code => match (here, next) {
            (b'"', _) => (Scan::Str, 1),
            (b'\'', Some(b'"')) if bytes.get(i + 2) == Some(&b'\'') => (Scan::Code, 3),
            (b'/', Some(b'/')) => (Scan::Line, 2),
            (b'/', Some(b'*')) => (Scan::Block, 2),
            _ => (Scan::Code, 1),
        },
        Scan::Str => match here {
            b'\\' => (Scan::Str, 2),
            b'"' => (Scan::Code, 1),
            _ => (Scan::Str, 1),
        },
        Scan::Line if here == b'\n' => (Scan::Code, 1),
        Scan::Line => (Scan::Line, 1),
        Scan::Block if here == b'*' && next == Some(b'/') => (Scan::Code, 2),
        Scan::Block => (Scan::Block, 1),
    }
}
