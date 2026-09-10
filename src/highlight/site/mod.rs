use tree_sitter::Tree;

use crate::ffi::{CompletionContext, CompletionSiteKind};

mod c;
mod common;
mod plain;
mod rust;
mod use_path;

pub use c::{c as c_site, cpp as cpp_site};
pub use plain::plain as plain_site;
pub use rust::rust as rust_site;
pub use use_path::leaf_names as use_leaf_names;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Position {
    Unknown,
    Type,
    Value,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Site {
    None,
    Identifier(Position),
    MemberAccess,
    ScopedPath(Vec<String>),
    UsePath(Vec<String>),
    Include { quoted: bool, dir: String },
    Attribute { derive: bool },
    Directive,
    StructLiteral(String),
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SiteAt {
    pub site: Site,
    pub prefix: String,
    pub replace_start: usize,
}

pub type Classifier = fn(Option<&Tree>, &str, usize) -> SiteAt;

impl SiteAt {
    pub fn none(at: usize) -> Self {
        Self {
            site: Site::None,
            prefix: String::new(),
            replace_start: at,
        }
    }

    pub fn kind(&self) -> CompletionSiteKind {
        match self.site {
            Site::None => CompletionSiteKind::None,
            Site::Identifier(_) => CompletionSiteKind::Identifier,
            Site::MemberAccess => CompletionSiteKind::MemberAccess,
            Site::ScopedPath(_) => CompletionSiteKind::ScopedPath,
            Site::UsePath(_) => CompletionSiteKind::UsePath,
            Site::Include { .. } => CompletionSiteKind::Include,
            Site::Attribute { .. } => CompletionSiteKind::Attribute,
            Site::Directive => CompletionSiteKind::Directive,
            Site::StructLiteral(_) => CompletionSiteKind::StructLiteral,
        }
    }

    pub fn context(&self) -> CompletionContext {
        match self.site {
            Site::Identifier(Position::Type) => CompletionContext::TypePosition,
            Site::Identifier(Position::Value) => CompletionContext::ValuePosition,
            Site::MemberAccess => CompletionContext::MemberAccess,
            _ => CompletionContext::Unknown,
        }
    }
}
