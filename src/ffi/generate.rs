#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Enum)]
pub enum GenKind {
    Constructor,
    Getters,
    Setters,
    EqualityOps,
    StreamInsert,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct GenOption {
    pub kind: GenKind,
    pub title: String,
}
