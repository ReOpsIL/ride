use super::grammar::{self, Grammar};

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

    pub fn sniff(path: Option<&str>, text: &str, is_system: bool) -> Lang {
        if is_extensionless(path) && (is_system || super::header::is_cpp_header(text)) {
            return Lang::Cpp;
        }
        Self::for_buffer(path, text)
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

fn is_extensionless(path: Option<&str>) -> bool {
    let name = file_name(path);
    !name.is_empty() && extension(&name).is_none()
}
