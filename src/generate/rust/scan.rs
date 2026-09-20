use crate::text::is_word;

pub(super) fn has_derive(buffer: &str, name: &str, trait_name: &str) -> bool {
    let Some(pos) = find_struct(buffer, name) else {
        return false;
    };
    for line in buffer[..pos].lines().rev() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        if let Some(rest) = line.strip_prefix("#[") {
            if rest.contains("derive") && rest.contains(trait_name) {
                return true;
            }
            continue;
        }
        break;
    }
    false
}

pub(super) fn inherent_impl_has_new(buffer: &str, name: &str) -> bool {
    let needle = "impl ";
    for (idx, _) in buffer.match_indices(needle) {
        let rest = buffer[idx + needle.len()..].trim_start();
        let Some(rest) = rest.strip_prefix(name) else {
            continue;
        };
        if rest.starts_with(is_word) {
            continue;
        }
        let Some(open) = rest.find('{') else {
            continue;
        };
        if rest[..open].contains(" for ") {
            continue;
        }
        if let Some(body) = balanced_block(&rest[open..])
            && body.contains("fn new")
        {
            return true;
        }
    }
    false
}

fn find_struct(buffer: &str, name: &str) -> Option<usize> {
    let needle = format!("struct {name}");
    let idx = buffer.find(&needle)?;
    let after = &buffer[idx + needle.len()..];
    if after.starts_with(is_word) {
        return None;
    }
    Some(idx)
}

fn balanced_block(text: &str) -> Option<&str> {
    let mut depth = 0i32;
    for (i, ch) in text.char_indices() {
        match ch {
            '{' => depth += 1,
            '}' => {
                depth -= 1;
                if depth == 0 {
                    return Some(&text[..=i]);
                }
            }
            _ => {}
        }
    }
    None
}
