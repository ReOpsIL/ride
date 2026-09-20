use crate::generate::GenType;

pub(super) fn default_impl(t: &GenType) -> String {
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
