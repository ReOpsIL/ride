use tree_sitter::InputEdit;

use crate::error::EngineError;
use crate::ffi::{ByteRange, CompletionHit, HighlightSpan, OutlineItem, ParseErrorSpan, SymbolAt};

use super::grammar::{self, Grammar};

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash)]
pub enum Lang {
    Rust,
    Markdown,
    C,
    Cpp,
}

const C_EXTS: &[&str] = &["c", "h"];
const CPP_EXTS: &[&str] = &[
    "cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "h++", "inl", "ipp", "tpp", "cppm", "ixx",
];

impl Lang {
    pub fn for_path(path: Option<&str>) -> Lang {
        match extension(path).as_deref() {
            Some("md") | Some("markdown") => Lang::Markdown,
            Some(e) if C_EXTS.contains(&e) => Lang::C,
            Some(e) if CPP_EXTS.contains(&e) => Lang::Cpp,
            _ => Lang::Rust,
        }
    }

    pub fn for_buffer(path: Option<&str>, text: &str) -> Lang {
        match Self::for_path(path) {
            Lang::C if is_header(path) && super::header::is_cpp_header(text) => Lang::Cpp,
            lang => lang,
        }
    }

    pub fn clang_name(self) -> Option<&'static str> {
        match self {
            Lang::C => Some("c"),
            Lang::Cpp => Some("c++"),
            Lang::Rust | Lang::Markdown => None,
        }
    }

    pub fn for_fence(info: &str) -> Option<Lang> {
        let lang = info.trim().split([',', ' ', '{']).next().unwrap_or("");
        match lang.to_ascii_lowercase().as_str() {
            "rust" | "rs" => Some(Lang::Rust),
            "c" | "h" => Some(Lang::C),
            "cpp" | "c++" | "cc" | "cxx" | "hpp" | "cplusplus" => Some(Lang::Cpp),
            _ => None,
        }
    }

    pub fn grammar(self) -> Option<Grammar> {
        match self {
            Lang::Rust => Some(grammar::rust::grammar()),
            Lang::C => Some(grammar::c::grammar()),
            Lang::Cpp => Some(grammar::cpp::grammar()),
            Lang::Markdown => None,
        }
    }

    pub fn keywords(self) -> &'static [&'static str] {
        match self {
            Lang::Rust => grammar::rust::KEYWORDS,
            Lang::C => grammar::c::KEYWORDS,
            Lang::Cpp => grammar::cpp::KEYWORDS,
            Lang::Markdown => &[],
        }
    }

    pub fn has_catalog(self) -> bool {
        self == Lang::Rust
    }
}

fn extension(path: Option<&str>) -> Option<String> {
    path.and_then(|p| p.rsplit_once('.'))
        .map(|(_, e)| e.to_ascii_lowercase())
}

fn is_header(path: Option<&str>) -> bool {
    extension(path).as_deref() == Some("h")
}

pub trait Syntax: Send + Sync {
    fn parse_full(&mut self, text: &str) -> Result<(), EngineError>;
    fn edit(&mut self, edit: &InputEdit, text: &str) -> Result<Vec<ByteRange>, EngineError>;
    fn highlights(&self, text: &str, ranges: &[ByteRange]) -> Vec<HighlightSpan>;
    fn outline(&self, text: &str) -> Vec<OutlineItem>;
    fn errors(&self) -> Vec<ParseErrorSpan>;
    fn local_hits(
        &self,
        text: &str,
        outline: &[OutlineItem],
        prefix: &str,
        limit: u32,
    ) -> Vec<CompletionHit>;
    fn symbol_at(&self, text: &str, byte: u32) -> Option<SymbolAt>;
}

pub fn parse_failed() -> EngineError {
    EngineError::InvalidEdit {
        message: "parse returned none".into(),
    }
}

pub fn lang_err(e: tree_sitter::LanguageError) -> EngineError {
    EngineError::InvalidEdit {
        message: format!("{e:?}"),
    }
}

pub fn query_err(e: tree_sitter::QueryError) -> EngineError {
    EngineError::InvalidEdit {
        message: e.to_string(),
    }
}

pub fn make(lang: Lang) -> Result<Box<dyn Syntax>, EngineError> {
    Ok(match lang.grammar() {
        Some(grammar) => Box::new(super::tree_syntax::TreeSyntax::new(grammar)?),
        None => Box::new(super::markdown::MarkdownSyntax::new()?),
    })
}
