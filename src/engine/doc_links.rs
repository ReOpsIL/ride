use crate::ffi::DocLink;

pub struct Rewritten {
    pub markdown: String,
    pub links: Vec<DocLink>,
}

struct Hit {
    taken: usize,
    text: String,
    link: Option<DocLink>,
}

pub fn rewrite(md: &str, resolve: impl Fn(&str) -> Option<String>) -> Rewritten {
    let mut out = String::new();
    let mut links = Vec::new();
    let mut i = 0;
    while i < md.len() {
        if let Some(hit) = take_code(&md[i..], &resolve).or_else(|| take_md(&md[i..], &resolve)) {
            i += hit.taken;
            push(&mut out, &mut links, hit);
            continue;
        }
        let Some(ch) = md[i..].chars().next() else {
            break;
        };
        out.push(ch);
        i += ch.len_utf8();
    }
    Rewritten {
        markdown: out,
        links,
    }
}

fn push(out: &mut String, links: &mut Vec<DocLink>, hit: Hit) {
    out.push_str(&hit.text);
    if let Some(link) = hit.link {
        links.push(link);
    }
}

fn take_code(s: &str, resolve: &impl Fn(&str) -> Option<String>) -> Option<Hit> {
    let inner = s.strip_prefix("[`")?;
    let end = inner.find("`]")?;
    let path = inner[..end].trim();
    if path.is_empty() || path.contains('\n') {
        return None;
    }
    let taken = 2 + end + 2;
    if s.get(taken..).is_some_and(|r| r.starts_with('(')) {
        return None;
    }
    Some(replace(path, &format!("`{path}`"), taken, resolve))
}

fn take_md(s: &str, resolve: &impl Fn(&str) -> Option<String>) -> Option<Hit> {
    if s.starts_with("![") {
        return None;
    }
    let inner = s.strip_prefix('[')?;
    let mid = inner.find("](")?;
    let label = &inner[..mid];
    if label.contains('\n') {
        return None;
    }
    let dest_and = &inner[mid + 2..];
    let end = dest_and.find(')')?;
    let dest = dest_and[..end].trim();
    if !item_path(dest) {
        return None;
    }
    let taken = 1 + mid + 2 + end + 1;
    Some(replace(dest, label, taken, resolve))
}

fn item_path(s: &str) -> bool {
    !s.is_empty()
        && !s.contains("://")
        && !s.starts_with(['#', '/', '.'])
        && !s.contains([' ', '.'])
}

fn replace(
    path: &str,
    label: &str,
    taken: usize,
    resolve: &impl Fn(&str) -> Option<String>,
) -> Hit {
    match resolve(path) {
        Some(target) => {
            let url = format!("ride-doc://{target}");
            Hit {
                taken,
                text: format!("[{label}]({url})"),
                link: Some(DocLink {
                    label: visible(label),
                    url,
                }),
            }
        }
        None => Hit {
            taken,
            text: code(label),
            link: None,
        },
    }
}

fn visible(label: &str) -> String {
    label.trim_matches('`').to_string()
}

fn code(label: &str) -> String {
    if label.starts_with('`') && label.ends_with('`') && label.len() >= 2 {
        label.to_string()
    } else {
        format!("`{label}`")
    }
}
