use std::borrow::Cow;

use super::inline_ifs::strip_inline_conditionals;

const NAMESPACE_OPEN: &[u8] = b"namespace std {";
const NAMESPACE_CLOSE: &[u8] = b"}";
const MAX_ARGS: usize = 512;

pub fn scrub_macros(text: &str) -> Cow<'_, str> {
    let bytes = text.as_bytes();
    let mut buf = bytes.to_vec();
    let mut changed = false;
    let mut i = 0;
    let mut line_start = 0;
    let mut directive = false;
    while i < bytes.len() {
        if i == line_start {
            directive = continues_directive(bytes, line_start, directive);
        }
        let c = bytes[i];
        if c == b'\n' {
            i += 1;
            line_start = i;
            continue;
        }
        if directive || !is_ident_start(c) || (i > 0 && is_ident_byte(bytes[i - 1])) {
            i += 1;
            continue;
        }
        let end = ident_end(bytes, i);
        let args = args_len(&bytes[end..]);
        let replacement = replacement(&bytes[i..end])
            .or_else(|| trailing_attribute(&buf, i, args).then_some(&b""[..]));
        match replacement {
            Some(replacement) => {
                blank(&mut buf, i, end + args, replacement);
                changed = true;
                i = end + args;
            }
            None => i = end,
        }
    }
    changed |= strip_inline_conditionals(&mut buf);
    if changed {
        Cow::Owned(String::from_utf8(buf).unwrap_or_else(|_| text.to_string()))
    } else {
        Cow::Borrowed(text)
    }
}

fn trailing_attribute(buf: &[u8], start: usize, args: usize) -> bool {
    args > 0
        && buf[start..].starts_with(b"__")
        && buf[..start]
            .iter()
            .rev()
            .find(|b| !matches!(b, b' ' | b'\t' | b'\n' | b'\r'))
            .is_some_and(|b| *b == b')')
}

fn continues_directive(bytes: &[u8], line_start: usize, previous: bool) -> bool {
    if previous && line_start >= 2 && bytes[line_start - 2] == b'\\' {
        return true;
    }
    bytes[line_start..]
        .iter()
        .find(|b| !matches!(b, b' ' | b'\t'))
        .is_some_and(|b| *b == b'#')
}

fn is_ident_start(c: u8) -> bool {
    c == b'_' || c.is_ascii_alphabetic()
}

fn is_ident_byte(c: u8) -> bool {
    is_ident_start(c) || c.is_ascii_digit()
}

fn ident_end(bytes: &[u8], start: usize) -> usize {
    let mut end = start;
    while end < bytes.len() && is_ident_byte(bytes[end]) {
        end += 1;
    }
    end
}

fn replacement(ident: &[u8]) -> Option<&'static [u8]> {
    if !is_macro_name(ident) {
        return None;
    }
    if ident.starts_with(b"_LIBCPP_BEGIN_") && ident.ends_with(b"NAMESPACE_STD") {
        return Some(NAMESPACE_OPEN);
    }
    if ident.starts_with(b"_LIBCPP_END_") && ident.ends_with(b"NAMESPACE_STD") {
        return Some(NAMESPACE_CLOSE);
    }
    Some(b"")
}

fn is_macro_name(ident: &[u8]) -> bool {
    ident.len() >= 3
        && ident[0] == b'_'
        && (ident[1] == b'_' || ident[1].is_ascii_uppercase())
        && ident.iter().any(u8::is_ascii_uppercase)
        && !ident.iter().any(u8::is_ascii_lowercase)
}

fn args_len(rest: &[u8]) -> usize {
    let mut i = 0;
    while i < rest.len() && matches!(rest[i], b' ' | b'\t') {
        i += 1;
    }
    if rest.get(i) != Some(&b'(') {
        return 0;
    }
    let mut depth = 0usize;
    for (offset, b) in rest.iter().enumerate().skip(i).take(MAX_ARGS) {
        match b {
            b'(' => depth += 1,
            b')' => {
                depth -= 1;
                if depth == 0 {
                    return offset + 1;
                }
            }
            _ => {}
        }
    }
    0
}

fn blank(buf: &mut [u8], start: usize, end: usize, replacement: &[u8]) {
    for (offset, slot) in buf[start..end].iter_mut().enumerate() {
        *slot = match replacement.get(offset) {
            Some(b) => *b,
            None if *slot == b'\n' => b'\n',
            None => b' ',
        };
    }
}

#[cfg(test)]
mod tests {
    use super::scrub_macros;

    #[test]
    fn libcpp_namespace_macros_become_namespace_std() {
        let src = "_LIBCPP_BEGIN_NAMESPACE_STD\nclass _LIBCPP_TEMPLATE_VIS vector {};\n_LIBCPP_END_NAMESPACE_STD\n";
        let out = scrub_macros(src);
        assert_eq!(out.len(), src.len());
        assert!(out.starts_with("namespace std {"), "{out}");
        assert!(
            out.contains("class                      vector {};"),
            "{out}"
        );
        assert!(out.lines().nth(2).unwrap().starts_with('}'), "{out}");
    }

    #[test]
    fn function_like_macros_lose_their_arguments_but_directives_stay() {
        let src = "#if _LIBCPP_STD_VER >= 20\nint f(void) __API_AVAILABLE(macos(10.9), ios(3.0));\n#endif\n";
        let out = scrub_macros(src);
        assert_eq!(out.len(), src.len());
        assert!(out.starts_with("#if _LIBCPP_STD_VER >= 20\n"), "{out}");
        assert!(
            !out.contains("__API_AVAILABLE") && !out.contains("macos"),
            "{out}"
        );
        assert_eq!(out.find(';'), src.find(';'));
        assert!(out.contains("int f(void) "), "{out}");
    }

    #[test]
    fn lowercase_attribute_macros_after_a_declarator_are_blanked() {
        let src = "int printf(const char *fmt, ...) __printflike(1, 2)\n__swift_unavailable(\"no\");\nvoid __swap(int __x);\n";
        let out = scrub_macros(src);
        assert_eq!(out.len(), src.len());
        assert!(
            out.contains(
                "int printf(const char *fmt, ...)                   \n                         ;"
            ),
            "{out}"
        );
        assert!(out.contains("void __swap(int __x);"), "{out}");
    }

    #[test]
    fn ordinary_identifiers_are_untouched() {
        let src = "template <class _Tp> void __swap(_Tp& __x) { _Bool b = _Static_assert; }\n";
        assert_eq!(scrub_macros(src), src);
    }
}
