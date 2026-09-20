use crate::ffi::ItemKind;
use crate::highlight::{Member, TypeTable};

pub struct Field {
    pub name: String,
    pub type_name: String,
}

pub struct GenType {
    pub name: String,
    pub fields: Vec<Field>,
}

impl GenType {
    pub fn from_scope(name: &str, types: &TypeTable) -> Self {
        let fields = types
            .own_members(name)
            .into_iter()
            .filter(|m| m.item.kind == ItemKind::Field)
            .map(Field::from)
            .collect();
        Self {
            name: name.to_string(),
            fields,
        }
    }
}

impl From<Member> for Field {
    fn from(member: Member) -> Self {
        let type_name = field_type(&member);
        Field {
            name: member.item.name,
            type_name,
        }
    }
}

fn field_type(member: &Member) -> String {
    let detail = member.detail.trim().trim_end_matches(';').trim_end();
    if !detail.is_empty() {
        let stripped = detail
            .strip_suffix(member.item.name.as_str())
            .map(str::trim_end)
            .filter(|ty| !ty.is_empty())
            .unwrap_or(detail);
        return stripped.to_string();
    }
    member
        .type_name
        .clone()
        .unwrap_or_else(|| "auto".to_string())
}
