use super::types::TypeTable;

pub fn supertypes(tables: &[&TypeTable], name: &str) -> Vec<String> {
    let mut out = Vec::new();
    for table in tables {
        push_all(&mut out, name, table.bases_of(name));
        push_all(&mut out, name, table.impls_of(name));
    }
    out
}

pub fn subtypes(tables: &[&TypeTable], name: &str) -> Vec<String> {
    let mut out = Vec::new();
    for table in tables {
        push_all(&mut out, name, table.derived_of(name));
        push_all(&mut out, name, table.implementors_of(name));
    }
    out
}

fn push_all(out: &mut Vec<String>, name: &str, items: Vec<String>) {
    for item in items {
        if !item.is_empty() && item != name && !out.contains(&item) {
            out.push(item);
        }
    }
}
