use std::sync::OnceLock;

use crate::highlight::Lang;

use super::model::{Section, Sheet, SheetError};
use super::sheets;

pub type Files = &'static [(&'static str, &'static str)];

fn files(lang: Lang) -> Files {
    match lang {
        Lang::Rust => sheets::rust::FILES,
        Lang::C => sheets::c::FILES,
        Lang::Cpp => sheets::cpp::FILES,
        Lang::Make => sheets::make::FILES,
        Lang::Toml | Lang::Cmake | Lang::Markdown => &[],
    }
}

fn parse_all(files: Files) -> Result<Sheet, SheetError> {
    let sections = files
        .iter()
        .map(|(name, text)| Section::parse(name, text))
        .collect::<Result<Vec<_>, _>>()?;
    Ok(Sheet { sections })
}

pub fn validate(lang: Lang) -> Result<Sheet, SheetError> {
    parse_all(files(lang))
}

pub fn sheet(lang: Lang) -> Option<&'static Sheet> {
    static SHEETS: OnceLock<Vec<(Lang, Option<Sheet>)>> = OnceLock::new();
    let all = SHEETS.get_or_init(|| {
        [Lang::Rust, Lang::C, Lang::Cpp, Lang::Make]
            .into_iter()
            .map(|lang| (lang, parse_all(files(lang)).ok()))
            .collect()
    });
    all.iter()
        .find(|(l, _)| *l == lang)
        .and_then(|(_, s)| s.as_ref())
        .filter(|s| !s.sections.is_empty())
}
