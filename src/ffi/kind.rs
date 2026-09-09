#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, uniffi::Enum)]
pub enum ItemKind {
    Keyword,
    Local,
    Crate,
    Mod,
    Struct,
    Enum,
    Union,
    Trait,
    Fn,
    Method,
    Macro,
    Const,
    Type,
    Static,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, uniffi::Enum)]
pub enum CaptureKind {
    Keyword,
    Function,
    Type,
    Property,
    Variable,
    Constant,
    String,
    Escape,
    Comment,
    Attribute,
    Lifetime,
    Macro,
    Number,
    Operator,
    Punctuation,
    Label,
}
