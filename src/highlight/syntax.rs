use tree_sitter::InputEdit;

use crate::error::EngineError;
use crate::ffi::{ByteRange, CompletionHit, HighlightSpan, OutlineItem, ParseErrorSpan, SymbolAt};

use super::grammar::{self, Grammar};
use super::includes::IncludeRef;
use super::members::Access;
use super::types::TypeTable;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, uniffi::Enum)]
pub enum Lang {
    Rust,
    Markdown,
    C,
    Cpp,
    Toml,
    Make,
    Cmake,
}

const C_EXTS: &[&str] = &["c", "h"];
const CPP_EXTS: &[&str] = &[
    "cpp", "cc", "cxx", "c++", "hpp", "hh", "hxx", "h++", "inl", "ipp", "tpp", "cppm", "ixx",
];
const MAKE_NAMES: &[&str] = &["makefile", "gnumakefile"];
const MAKE_EXTS: &[&str] = &["mk", "mak", "make"];
const CMAKE_NAMES: &[&str] = &["cmakelists.txt"];
const CMAKE_EXTS: &[&str] = &["cmake"];

impl Lang {
    pub fn for_path(path: Option<&str>) -> Lang {
        let name = file_name(path);
        if MAKE_NAMES.contains(&name.as_str()) {
            return Lang::Make;
        }
        if CMAKE_NAMES.contains(&name.as_str()) {
            return Lang::Cmake;
        }
        match extension(&name).as_deref() {
            Some("md") | Some("markdown") => Lang::Markdown,
            Some("toml") => Lang::Toml,
            Some(e) if C_EXTS.contains(&e) => Lang::C,
            Some(e) if CPP_EXTS.contains(&e) => Lang::Cpp,
            Some(e) if MAKE_EXTS.contains(&e) => Lang::Make,
            Some(e) if CMAKE_EXTS.contains(&e) => Lang::Cmake,
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
            Lang::Rust | Lang::Markdown | Lang::Toml | Lang::Make | Lang::Cmake => None,
        }
    }

    pub fn for_fence(info: &str) -> Option<Lang> {
        let lang = info.trim().split([',', ' ', '{']).next().unwrap_or("");
        match lang.to_ascii_lowercase().as_str() {
            "rust" | "rs" => Some(Lang::Rust),
            "c" | "h" => Some(Lang::C),
            "cpp" | "c++" | "cc" | "cxx" | "hpp" | "cplusplus" => Some(Lang::Cpp),
            "toml" => Some(Lang::Toml),
            "make" | "makefile" | "mk" => Some(Lang::Make),
            "cmake" => Some(Lang::Cmake),
            _ => None,
        }
    }

    pub fn grammar(self) -> Option<Grammar> {
        match self {
            Lang::Rust => Some(grammar::rust::grammar()),
            Lang::C => Some(grammar::c::grammar()),
            Lang::Cpp => Some(grammar::cpp::grammar()),
            Lang::Toml => Some(grammar::toml::grammar()),
            Lang::Make => Some(grammar::make::grammar()),
            Lang::Cmake => Some(grammar::cmake::grammar()),
            Lang::Markdown => None,
        }
    }

    pub fn keywords(self) -> &'static [&'static str] {
        match self {
            Lang::Rust => grammar::rust::KEYWORDS,
            Lang::C => grammar::c::KEYWORDS,
            Lang::Cpp => grammar::cpp::KEYWORDS,
            Lang::Toml => grammar::toml::KEYWORDS,
            Lang::Make => grammar::make::KEYWORDS,
            Lang::Cmake => grammar::cmake::KEYWORDS,
            Lang::Markdown => &[],
        }
    }

    pub fn has_catalog(self) -> bool {
        self == Lang::Rust
    }
}

fn file_name(path: Option<&str>) -> String {
    path.map(|p| p.rsplit(['/', '\\']).next().unwrap_or(p))
        .unwrap_or_default()
        .to_ascii_lowercase()
}

fn extension(name: &str) -> Option<String> {
    name.rsplit_once('.').map(|(_, e)| e.to_string())
}

fn is_header(path: Option<&str>) -> bool {
    extension(&file_name(path)).as_deref() == Some("h")
}

#[derive(Debug, Clone, Copy)]
pub struct LocalQuery<'a> {
    pub prefix: &'a str,
    pub limit: u32,
    pub at: u32,
}

#[derive(Debug, Clone, Default)]
pub struct LocalHits {
    pub hits: Vec<CompletionHit>,
    pub access: Option<Access>,
}

pub trait Syntax: Send + Sync {
    fn parse_full(&mut self, text: &str) -> Result<(), EngineError>;
    fn edit(&mut self, edit: &InputEdit, text: &str) -> Result<Vec<ByteRange>, EngineError>;
    fn highlights(&self, text: &str, ranges: &[ByteRange]) -> Vec<HighlightSpan>;
    fn outline(&self, text: &str) -> Vec<OutlineItem>;
    fn errors(&self) -> Vec<ParseErrorSpan>;
    fn local_hits(&self, text: &str, outline: &[OutlineItem], q: &LocalQuery<'_>) -> LocalHits;
    fn symbol_at(&self, text: &str, byte: u32) -> Option<SymbolAt>;
    fn includes(&self, _text: &str) -> Vec<IncludeRef> {
        Vec::new()
    }
    fn type_table(&self, _text: &str) -> TypeTable {
        TypeTable::default()
    }
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
