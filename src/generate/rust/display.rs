use crate::generate::GenType;

pub(super) fn display_impl(t: &GenType) -> String {
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
