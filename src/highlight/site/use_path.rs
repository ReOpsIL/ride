use super::common::is_word;

#[derive(Debug, PartialEq, Eq)]
enum Tok<'a> {
    Ident(&'a str),
    Sep,
    Open,
    Close,
    Comma,
    Star,
    As,
}

pub fn parse(head: &str) -> Option<Vec<String>> {
    let body = use_body(head)?;
    let toks = tokens(body);
    if matches!(toks.last(), Some(Tok::As)) {
        return None;
    }
    if let [.., Tok::Ident(_)] = toks.as_slice() {
        return None;
    }
    let mut stack: Vec<Vec<String>> = Vec::new();
    let mut current: Vec<String> = Vec::new();
    let mut pending: Option<&str> = None;
    for tok in toks {
        match tok {
            Tok::Ident(s) => pending = Some(s),
            Tok::Sep => {
                if let Some(s) = pending.take() {
                    current.push(s.to_string());
                }
            }
            Tok::Open => {
                pending = None;
                stack.push(std::mem::take(&mut current));
            }
            Tok::Comma | Tok::Star | Tok::As => {
                pending = None;
                current.clear();
            }
            Tok::Close => {
                pending = None;
                stack.pop();
                current.clear();
            }
        }
    }
    let mut out: Vec<String> = stack.into_iter().flatten().collect();
    out.extend(current);
    Some(out)
}

pub fn leaf_names(body: &str) -> Vec<String> {
    let toks = tokens(body);
    let mut out = Vec::new();
    let mut i = 0;
    while i < toks.len() {
        if let Tok::Ident(name) = toks[i] {
            match toks.get(i + 1) {
                Some(Tok::Sep) => {}
                Some(Tok::As) => {
                    if let Some(Tok::Ident(alias)) = toks.get(i + 2) {
                        out.push(alias.to_string());
                    }
                    i += 2;
                }
                _ => out.push(name.to_string()),
            }
        }
        i += 1;
    }
    out
}

fn use_body(head: &str) -> Option<&str> {
    let stmt = head.rfind(';').map(|i| i + 1).unwrap_or(0);
    let tail = &head[stmt..];
    let mut search = 0;
    let mut found = None;
    while let Some(pos) = tail[search..].find("use") {
        let abs = search + pos;
        let before_ok = abs == 0 || !is_word(tail[..abs].chars().next_back().unwrap_or(' '));
        let after = tail[abs + 3..].chars().next();
        let after_ok = after.is_none_or(char::is_whitespace);
        if before_ok && after_ok {
            found = Some(abs + 3);
        }
        search = abs + 3;
    }
    let start = found?;
    Some(&tail[start..])
}

fn tokens(body: &str) -> Vec<Tok<'_>> {
    let mut out = Vec::new();
    let bytes = body.as_bytes();
    let mut i = 0;
    while i < bytes.len() {
        let c = body[i..].chars().next().unwrap_or(' ');
        if is_word(c) {
            let end = body[i..]
                .find(|ch: char| !is_word(ch))
                .map(|e| i + e)
                .unwrap_or(body.len());
            let word = &body[i..end];
            out.push(if word == "as" {
                Tok::As
            } else {
                Tok::Ident(word)
            });
            i = end;
            continue;
        }
        if body[i..].starts_with("::") {
            out.push(Tok::Sep);
            i += 2;
            continue;
        }
        match c {
            '{' => out.push(Tok::Open),
            '}' => out.push(Tok::Close),
            ',' => out.push(Tok::Comma),
            '*' => out.push(Tok::Star),
            _ => {}
        }
        i += c.len_utf8();
    }
    out
}
