use std::collections::HashSet;

use crate::ffi::{CompletionHit, CompletionQuery, CompletionResponse};
use crate::index::hump;
use crate::score::IN_SCOPE_BONUS;

use super::merge;

const MIN_HUMP: usize = 2;

pub fn members(
    known: &[CompletionHit],
    q: &CompletionQuery,
    next_char: Option<char>,
) -> CompletionResponse {
    let mut pool = matching(known, &q.prefix, next_char);
    merge::keep_order(&mut pool, &q.prefix);
    merge::finish(q, pool, false)
}

pub fn in_scope(
    known: &[CompletionHit],
    q: &CompletionQuery,
    next_char: Option<char>,
) -> Vec<CompletionHit> {
    let mut pool = matching(known, &q.prefix, next_char);
    merge::keep_order(&mut pool, &q.prefix);
    for hit in &mut pool {
        hit.score += IN_SCOPE_BONUS;
    }
    pool
}

pub fn add_missing(pool: &mut Vec<CompletionHit>, extras: Vec<CompletionHit>) {
    let known: HashSet<String> = pool.iter().map(|h| h.name.clone()).collect();
    pool.extend(extras.into_iter().filter(|h| !known.contains(&h.name)));
}

fn matching(known: &[CompletionHit], prefix: &str, next_char: Option<char>) -> Vec<CompletionHit> {
    let wanted = prefix.to_lowercase();
    known
        .iter()
        .filter(|h| matches(&h.name, &wanted))
        .cloned()
        .map(|hit| match next_char {
            Some('(') => plain(hit),
            _ => hit,
        })
        .collect()
}

fn matches(name: &str, wanted: &str) -> bool {
    wanted.is_empty()
        || name.to_lowercase().starts_with(wanted)
        || (wanted.chars().count() >= MIN_HUMP && hump(name).starts_with(wanted))
}

fn plain(mut hit: CompletionHit) -> CompletionHit {
    hit.insert_text = hit.name.clone();
    hit.snippet = false;
    hit
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi::ItemKind;

    fn hit(name: &str) -> CompletionHit {
        let mut hit = CompletionHit::local(name, ItemKind::Fn, 1.0, None);
        hit.insert_text = format!("{name}($0)");
        hit.snippet = true;
        hit
    }

    #[test]
    fn prefix_and_hump_both_match() {
        let known = [hit("HashMap"), hit("hash_one"), hit("Vec")];
        let names: Vec<String> = matching(&known, "hm", None)
            .into_iter()
            .map(|h| h.name)
            .collect();
        assert_eq!(names, ["HashMap"]);
        let names: Vec<String> = matching(&known, "hash", None)
            .into_iter()
            .map(|h| h.name)
            .collect();
        assert_eq!(names, ["HashMap", "hash_one"]);
    }

    #[test]
    fn an_open_paren_after_the_caret_drops_the_call_snippet() {
        let got = matching(&[hit("len")], "", Some('('));
        assert_eq!(got[0].insert_text, "len");
        assert!(!got[0].snippet);
    }

    #[test]
    fn extras_with_a_known_name_are_left_out() {
        let mut pool = vec![hit("HashMap")];
        add_missing(&mut pool, vec![hit("HashMap"), hit("HashSet")]);
        let names: Vec<&str> = pool.iter().map(|h| h.name.as_str()).collect();
        assert_eq!(names, ["HashMap", "HashSet"]);
    }
}
