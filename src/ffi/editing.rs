use super::ByteRange;

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct FoldRange {
    pub start_byte: u32,
    pub end_byte: u32,
    pub kind: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct BracketPair {
    pub open_byte: u32,
    pub close_byte: u32,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, uniffi::Record)]
pub struct StatementBounds {
    pub current: ByteRange,
    pub previous: Option<ByteRange>,
    pub next: Option<ByteRange>,
}
