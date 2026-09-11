use super::session::ByteRange;

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct TextEdit {
    pub start_byte: u32,
    pub end_byte: u32,
    pub text: String,
    pub caret_byte: u32,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct SignatureHelp {
    pub label: String,
    pub parameters: Vec<ByteRange>,
    pub active_parameter: u32,
    pub doc: String,
    pub name: String,
}
