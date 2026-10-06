use crate::highlight::Lang;

pub fn name(lang: Lang) -> &'static str {
    match lang {
        Lang::Rust => "rust",
        Lang::C => "c",
        Lang::Cpp => "cpp",
        Lang::Toml => "toml",
        Lang::Make => "make",
        Lang::Cmake => "cmake",
        Lang::Markdown => "markdown",
    }
}
