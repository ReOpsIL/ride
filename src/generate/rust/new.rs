use crate::generate::{Field, GenType};

pub(super) fn new_fn(t: &GenType) -> String {
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

fn field_names(t: &GenType) -> Vec<String> {
    t.fields.iter().map(|f: &Field| f.name.clone()).collect()
}
