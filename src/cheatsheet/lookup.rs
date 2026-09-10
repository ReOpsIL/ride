use crate::highlight::Context;

use super::model::{Entry, Section, Sheet};

#[derive(Debug)]
pub struct Selected<'a> {
    pub section: &'a Section,
    pub entries: Vec<&'a Entry>,
    pub matched: bool,
    pub by_name: bool,
}

pub fn select<'a>(sheet: &'a Sheet, ctx: Context, prefix: &str, all: bool) -> Vec<Selected<'a>> {
    let prefix = prefix.to_lowercase();
    let in_context = |s: &Section| all || ctx == Context::Unknown || s.applies(ctx);
    let explicit = |s: &Section| !s.contexts.is_empty();
    let mut out: Vec<Selected<'a>> = sheet
        .sections
        .iter()
        .filter(|s| in_context(s) && explicit(s))
        .chain(
            sheet
                .sections
                .iter()
                .filter(|s| in_context(s) && !explicit(s)),
        )
        .filter_map(|s| pick(s, &prefix, true))
        .collect();
    if !prefix.is_empty() {
        out.extend(
            sheet
                .sections
                .iter()
                .filter(|s| !in_context(s))
                .filter_map(|s| pick(s, &prefix, false)),
        );
        out.sort_by_key(|s| (!s.matched, !s.by_name));
    }
    out
}

fn pick<'a>(section: &'a Section, prefix: &str, matched: bool) -> Option<Selected<'a>> {
    let entries: Vec<&Entry> = section
        .entries
        .iter()
        .filter(|e| e.matches(prefix))
        .collect();
    if entries.is_empty() {
        return None;
    }
    let by_name = entries.iter().any(|e| e.name_matches(prefix));
    Some(Selected {
        section,
        entries,
        matched,
        by_name,
    })
}
