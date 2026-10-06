use std::collections::HashSet;

use crate::refs::{RefKind, RefRecord};

use super::focus::Span;

pub const MAX_RELATED: usize = 16;

pub fn referenced(records: &[RefRecord], focus: Span) -> Vec<(String, u32)> {
    let mut seen = HashSet::new();
    records
        .iter()
        .filter(|r| r.kind != RefKind::Include)
        .filter(|r| {
            focus.contains(Span {
                start: r.byte_start as usize,
                end: r.byte_end as usize,
            })
        })
        .filter(|r| seen.insert(r.name.clone()))
        .map(|r| (r.name.clone(), r.byte_start))
        .take(MAX_RELATED * 2)
        .collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::ffi::ItemKind;

    fn rec(name: &str, kind: RefKind, start: u32) -> RefRecord {
        RefRecord {
            name: name.into(),
            kind,
            line: 1,
            byte_start: start,
            byte_end: start + name.len() as u32,
            enclosing_item: String::new(),
            enclosing_kind: ItemKind::Fn,
        }
    }

    #[test]
    fn keeps_first_mention_inside_the_focus_once() {
        let records = [
            rec("outside", RefKind::Call, 0),
            rec("helper", RefKind::Call, 20),
            rec("Point", RefKind::TypeMention, 30),
            rec("helper", RefKind::Call, 40),
            rec("stdio.h", RefKind::Include, 45),
        ];
        let got = referenced(&records, Span { start: 10, end: 60 });
        assert_eq!(
            got,
            vec![("helper".to_string(), 20), ("Point".to_string(), 30)]
        );
    }
}
