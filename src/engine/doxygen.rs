enum Block {
    Brief(String),
    Param(String, String),
    Returns(String),
    Para(String),
}

pub fn to_markdown(raw: &str) -> String {
    if !has_tag(raw) {
        return raw.trim().to_string();
    }
    render(&blocks(raw))
}

fn has_tag(raw: &str) -> bool {
    raw.lines().any(|l| {
        let t = l.trim();
        t.starts_with('@') || t.starts_with('\\')
    })
}

fn blocks(raw: &str) -> Vec<Block> {
    let mut out = Vec::new();
    for line in raw.lines() {
        absorb(&mut out, line.trim());
    }
    out
}

fn absorb(out: &mut Vec<Block>, t: &str) {
    if let Some(rest) = prefix(t, &["@brief", "\\brief"]) {
        out.push(Block::Brief(rest.to_string()));
        return;
    }
    if let Some(rest) = param_line(t) {
        let (name, desc) = split_name(rest);
        out.push(Block::Param(name, desc));
        return;
    }
    if let Some(rest) = prefix(t, &["@return", "@returns", "\\return", "\\returns"]) {
        out.push(Block::Returns(rest.to_string()));
        return;
    }
    if t.starts_with('@') || t.starts_with('\\') {
        return;
    }
    continue_text(out, t);
}

fn continue_text(out: &mut Vec<Block>, t: &str) {
    if t.is_empty() {
        out.push(Block::Para(String::new()));
        return;
    }
    match out.last_mut() {
        Some(Block::Brief(s) | Block::Returns(s) | Block::Para(s)) => append(s, t),
        Some(Block::Param(_, desc)) => append(desc, t),
        None => out.push(Block::Para(t.to_string())),
    }
}

fn append(s: &mut String, t: &str) {
    if !s.is_empty() {
        s.push(' ');
    }
    s.push_str(t);
}

fn prefix<'a>(t: &'a str, tags: &[&str]) -> Option<&'a str> {
    tags.iter().find_map(|p| t.strip_prefix(p).map(str::trim))
}

fn param_line(t: &str) -> Option<&str> {
    let rest = prefix(t, &["@param", "\\param"])?;
    Some(match rest.split_once(']') {
        Some((_, tail)) if rest.starts_with('[') => tail.trim(),
        _ => rest,
    })
}

fn split_name(s: &str) -> (String, String) {
    match s.split_once(char::is_whitespace) {
        Some((n, d)) => (n.to_string(), d.trim().to_string()),
        None => (s.to_string(), String::new()),
    }
}

fn render(blocks: &[Block]) -> String {
    let mut brief = String::new();
    let mut paras = Vec::new();
    let mut params = Vec::new();
    let mut returns = String::new();
    collect(blocks, &mut brief, &mut paras, &mut params, &mut returns);
    join(&brief, &paras, &params, &returns)
}

fn collect<'a>(
    blocks: &'a [Block],
    brief: &mut String,
    paras: &mut Vec<&'a str>,
    params: &mut Vec<(&'a str, &'a str)>,
    returns: &mut String,
) {
    for b in blocks {
        match b {
            Block::Brief(s) if brief.is_empty() => *brief = s.clone(),
            Block::Brief(s) | Block::Para(s) if !s.is_empty() && brief.is_empty() => {
                *brief = s.clone();
            }
            Block::Brief(s) | Block::Para(s) if !s.is_empty() => paras.push(s),
            Block::Param(n, d) => params.push((n, d)),
            Block::Returns(s) => *returns = s.clone(),
            _ => {}
        }
    }
}

fn join(brief: &str, paras: &[&str], params: &[(&str, &str)], returns: &str) -> String {
    let mut out = String::new();
    push_para(&mut out, brief);
    for p in paras {
        push_para(&mut out, p);
    }
    push_params(&mut out, params);
    push_para(&mut out, returns);
    out
}

fn push_params(out: &mut String, params: &[(&str, &str)]) {
    if params.is_empty() {
        return;
    }
    if !out.is_empty() {
        out.push_str("\n\n");
    }
    for (i, (name, desc)) in params.iter().enumerate() {
        if i > 0 {
            out.push('\n');
        }
        if desc.is_empty() {
            out.push_str(&format!("- `{name}`"));
        } else {
            out.push_str(&format!("- `{name}`: {desc}"));
        }
    }
}

fn push_para(out: &mut String, s: &str) {
    if s.is_empty() {
        return;
    }
    if !out.is_empty() {
        out.push_str("\n\n");
    }
    out.push_str(s);
}
