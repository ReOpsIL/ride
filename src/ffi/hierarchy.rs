use super::kind::ItemKind;

#[derive(Debug, Clone, uniffi::Record)]
pub struct CalleeHit {
    pub name: String,
    pub byte_start: u32,
    pub byte_end: u32,
    pub line: u32,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct TypeNode {
    pub name: String,
    pub kind: ItemKind,
    pub path: String,
    pub byte_start: u32,
}

#[derive(Debug, Clone, uniffi::Record)]
pub struct TypeHierarchy {
    pub name: String,
    pub supertypes: Vec<TypeNode>,
    pub subtypes: Vec<TypeNode>,
}

impl TypeHierarchy {
    pub fn empty() -> Self {
        Self {
            name: String::new(),
            supertypes: Vec::new(),
            subtypes: Vec::new(),
        }
    }
}
