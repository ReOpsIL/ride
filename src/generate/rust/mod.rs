mod default;
mod display;
mod impl_block;
mod new;
mod scan;

use self::default::default_impl;
use self::display::display_impl;
use self::impl_block::impl_block;
use self::new::new_fn;
use self::scan::{has_derive, inherent_impl_has_new};

use super::GenType;
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
