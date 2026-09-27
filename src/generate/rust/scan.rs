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
    buffer
        .match_indices("impl")
        .any(|(idx, _)| impl_has_new_at(buffer, idx, name))
}

fn impl_has_new_at(buffer: &str, idx: usize, name: &str) -> bool {
    let rest = &buffer[idx + "impl".len()..];
    if buffer[..idx].ends_with(is_word) || rest.starts_with(is_word) {
        return false;
    }
    let Some(rest) = past_generics(rest.trim_start())
        .trim_start()
        .strip_prefix(name)
    else {
        return false;
    };
    if rest.starts_with(is_word) {
        return false;
    }
    let Some(open) = rest.find('{') else {
        return false;
    };
    !rest[..open].contains(" for ")
        && balanced_block(&rest[open..]).is_some_and(|body| declares_fn(body, "new"))
}

fn past_generics(text: &str) -> &str {
    if !text.starts_with('<') {
        return text;
    }
    let bytes = text.as_bytes();
    let mut depth = 0i32;
    let mut i = 0;
    while i < bytes.len() {
        match bytes[i] {
            b'-' if bytes.get(i + 1) == Some(&b'>') => i += 1,
            b'<' => depth += 1,
            b'>' => {
                depth -= 1;
                if depth == 0 {
                    return &text[i + 1..];
                }
            }
            _ => {}
        }
        i += 1;
    }
    ""
}

fn declares_fn(body: &str, name: &str) -> bool {
    body.match_indices("fn ").any(|(i, _)| {
        !body[..i].ends_with(is_word)
            && body[i + 3..]
                .trim_start()
                .strip_prefix(name)
                .is_some_and(|after| !after.starts_with(is_word))
    })
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
