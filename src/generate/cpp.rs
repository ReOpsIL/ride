use super::{Field, GenType};

pub fn constructor(t: &GenType) -> String {
    let params = t
        .fields
        .iter()
        .map(|f| format!("{} {}", f.type_name, param(f)))
        .collect::<Vec<_>>()
        .join(", ");
    let inits = t
        .fields
        .iter()
        .map(|f| format!("{}({})", f.name, param(f)))
        .collect::<Vec<_>>()
        .join(", ");
    format!("    {}({}) : {} {{}}\n", t.name, params, inits)
}

pub fn getters(t: &GenType) -> String {
    t.fields
        .iter()
        .map(|f| {
            format!(
                "    {} {}() const {{ return {}; }}\n",
                f.type_name,
                getter(f),
                f.name
            )
        })
        .collect()
}

pub fn setters(t: &GenType) -> String {
    t.fields
        .iter()
        .map(|f| {
            format!(
                "    void set_{}({} value) {{ {} = value; }}\n",
                param(f),
                f.type_name,
                f.name
            )
        })
        .collect()
}

pub fn equality(t: &GenType) -> String {
    let compare = t
        .fields
        .iter()
        .map(|f| format!("{} == other.{}", f.name, f.name))
        .collect::<Vec<_>>()
        .join(" && ");
    format!(
        "    bool operator==(const {name}& other) const {{ return {compare}; }}\n    bool operator!=(const {name}& other) const {{ return !(*this == other); }}\n",
        name = t.name,
        compare = compare,
    )
}

pub fn stream_insert(t: &GenType) -> String {
    let body = t
        .fields
        .iter()
        .map(|f| format!("v.{}", f.name))
        .collect::<Vec<_>>()
        .join(" << \", \" << ");
    format!(
        "    friend std::ostream& operator<<(std::ostream& os, const {name}& v) {{ os << {body}; return os; }}\n",
        name = t.name,
        body = body,
    )
}

fn param(field: &Field) -> String {
    field
        .name
        .strip_suffix('_')
        .unwrap_or(&field.name)
        .to_string()
}

fn getter(field: &Field) -> String {
    match field.name.strip_suffix('_') {
        Some(stem) if !stem.is_empty() => stem.to_string(),
        _ => format!("get_{}", field.name),
    }
}
