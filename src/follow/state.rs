use crate::review::Candidate;

use super::mark::Mark;

pub fn derive(mark: &Mark, items: &[Candidate]) -> &'static str {
    let same: Vec<&Candidate> = items
        .iter()
        .filter(|item| item.path == mark.path && item.item == mark.item && item.kind == mark.kind)
        .collect();
    if same.len() == 1 {
        return if basis_eq(&mark.basis, &same[0].shape) {
            "fresh"
        } else {
            "stale"
        };
    }
    if same.len() > 1 {
        return if same.iter().any(|item| basis_eq(&mark.basis, &item.shape)) {
            "fresh"
        } else {
            "stale"
        };
    }
    let shaped = items
        .iter()
        .filter(|item| basis_eq(&mark.basis, &item.shape))
        .count();
    if shaped == 1 { "moved" } else { "orphan" }
}

pub fn locate<'a>(mark: &Mark, items: &'a [Candidate], state: &str) -> Option<&'a Candidate> {
    if state == "moved" {
        return items.iter().find(|item| basis_eq(&mark.basis, &item.shape));
    }
    if state == "orphan" {
        return None;
    }
    items
        .iter()
        .find(|item| item.path == mark.path && item.item == mark.item && item.kind == mark.kind)
}

pub fn basis_eq(basis: &str, shape: &str) -> bool {
    !basis.is_empty() && (basis == shape || (basis.len() >= 8 && shape.starts_with(basis)))
}
