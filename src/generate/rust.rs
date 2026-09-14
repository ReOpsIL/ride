use super::{Field, GenType};
use crate::ffi::{GenKind, GenOption};

const RUST_KINDS: [GenKind; 4] = [
    GenKind::New,
    GenKind::ImplBlock,
    GenKind::DefaultImpl,
    GenKind::DisplayImpl,
];

pub fn apply(t: &GenType, kind: GenKind) -> String {
    match kind {
        GenKind::New => new_fn(t),
        GenKind::ImplBlock => impl_block(t),
        GenKind::DefaultImpl => default_impl(t),
        GenKind::DisplayImpl => display_impl(t),
        _ => String::new(),
    }
}

pub fn title(kind: GenKind) -> String {
    match kind {
        GenKind::New => "new",
        GenKind::ImplBlock => "impl block",
        GenKind::DefaultImpl => "Default impl",
        GenKind::DisplayImpl => "Display impl",
        _ => "",
    }
    .to_string()
}

pub fn options(t: &GenType, buffer: &str) -> Vec<GenOption> {
    RUST_KINDS
        .iter()
        .filter(|&&kind| !already_present(t, buffer, kind))
        .map(|&kind| GenOption {
            kind,
            title: title(kind),
        })
        .collect()
}

fn already_present(t: &GenType, buffer: &str, kind: GenKind) -> bool {
    match kind {
        GenKind::New | GenKind::ImplBlock => inherent_impl_has_new(buffer, &t.name),
        GenKind::DefaultImpl => {
            has_derive(buffer, &t.name, "Default")
                || buffer.contains(&format!("Default for {}", t.name))
        }
        GenKind::DisplayImpl => buffer.contains(&format!("Display for {}", t.name)),
        _ => false,
    }
}

fn new_fn(t: &GenType) -> String {
    let params = t
        .fields
        .iter()
        .map(|f| format!("{}: {}", f.name, f.type_name))
        .collect::<Vec<_>>()
        .join(", ");
    let inits = field_names(t).join(", ");
    format!(
        "impl {name} {{\n    pub fn new({params}) -> Self {{\n        Self {{ {inits} }}\n    }}\n}}\n",
        name = t.name,
    )
}

fn impl_block(t: &GenType) -> String {
    format!("impl {} {{}}\n", t.name)
}

fn default_impl(t: &GenType) -> String {
    let inits = t
        .fields
        .iter()
        .map(|f| format!("{}: Default::default()", f.name))
        .collect::<Vec<_>>()
        .join(", ");
    format!(
        "impl Default for {name} {{\n    fn default() -> Self {{\n        Self {{ {inits} }}\n    }}\n}}\n",
        name = t.name,
    )
}

fn display_impl(t: &GenType) -> String {
    let fmt = t
        .fields
        .iter()
        .map(|f| format!("{}: {{:?}}", f.name))
        .collect::<Vec<_>>()
        .join(", ");
    let args = t
        .fields
        .iter()
        .map(|f| format!("self.{}", f.name))
        .collect::<Vec<_>>()
        .join(", ");
    let call = if args.is_empty() {
        format!("write!(f, \"{}\")", t.name)
    } else {
        format!("write!(f, \"{fmt}\", {args})")
    };
    format!(
        "impl std::fmt::Display for {name} {{\n    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {{\n        {call}\n    }}\n}}\n",
        name = t.name,
    )
}

fn field_names(t: &GenType) -> Vec<String> {
    t.fields.iter().map(|f: &Field| f.name.clone()).collect()
}

fn has_derive(buffer: &str, name: &str, trait_name: &str) -> bool {
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

fn inherent_impl_has_new(buffer: &str, name: &str) -> bool {
    let needle = "impl ";
    for (idx, _) in buffer.match_indices(needle) {
        let rest = buffer[idx + needle.len()..].trim_start();
        let Some(rest) = rest.strip_prefix(name) else {
            continue;
        };
        if rest.starts_with(|c: char| c.is_alphanumeric() || c == '_') {
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
    if after.starts_with(|c: char| c.is_alphanumeric() || c == '_') {
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::generate::GenType;
    use crate::highlight::{BufferSession, Lang};

    fn gen_type(name: &str, src: &str) -> GenType {
        let (session, _) = BufferSession::open_lang(Lang::Rust, src.to_string(), None).unwrap();
        let scope = session.scope();
        GenType::from_scope(name, &scope.types)
    }

    const COUNTER: &str =
        "use std::collections::HashMap;\nstruct Counter {\n    counts: HashMap<String, u32>,\n}\n";

    #[test]
    fn new_uses_field_name_and_full_type() {
        let text = new_fn(&gen_type("Counter", COUNTER));
        assert!(text.contains("impl Counter {"), "{text}");
        assert!(
            text.contains("pub fn new(counts: HashMap<String, u32>) -> Self"),
            "{text}"
        );
        assert!(text.contains("Self { counts }"), "{text}");
    }

    #[test]
    fn impl_block_is_empty() {
        let text = impl_block(&gen_type("Counter", COUNTER));
        assert!(text.contains("impl Counter {}"), "{text}");
    }

    #[test]
    fn default_impl_fills_fields() {
        let text = default_impl(&gen_type("Counter", COUNTER));
        assert!(text.contains("impl Default for Counter"), "{text}");
        assert!(text.contains("counts: Default::default()"), "{text}");
    }

    #[test]
    fn display_impl_writes_fields() {
        let text = display_impl(&gen_type("Counter", COUNTER));
        assert!(
            text.contains("impl std::fmt::Display for Counter"),
            "{text}"
        );
        assert!(
            text.contains("fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result"),
            "{text}"
        );
        assert!(text.contains("self.counts"), "{text}");
    }

    #[test]
    fn options_offer_all_on_bare_struct() {
        let opts = options(&gen_type("Counter", COUNTER), COUNTER);
        assert_eq!(opts.len(), 4);
    }

    #[test]
    fn options_omit_default_when_derived() {
        let src = "#[derive(Default)]\nstruct Counter {\n    counts: u32,\n}\n";
        let opts = options(&gen_type("Counter", src), src);
        assert!(
            opts.iter().all(|o| o.kind != GenKind::DefaultImpl),
            "{opts:?}"
        );
    }

    #[test]
    fn options_omit_new_when_impl_new_exists() {
        let src = "struct Counter {\n    counts: u32,\n}\nimpl Counter {\n    pub fn new() -> Self {\n        Self { counts: 0 }\n    }\n}\n";
        let opts = options(&gen_type("Counter", src), src);
        assert!(opts.iter().all(|o| o.kind != GenKind::New), "{opts:?}");
        assert!(
            opts.iter().all(|o| o.kind != GenKind::ImplBlock),
            "{opts:?}"
        );
    }
}
