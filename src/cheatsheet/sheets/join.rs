use super::super::load::Files;

pub const fn count(parts: &[Files]) -> usize {
    let mut total = 0;
    let mut index = 0;
    while index < parts.len() {
        total += parts[index].len();
        index += 1;
    }
    total
}

pub const fn flatten<const N: usize>(parts: &[Files]) -> [(&'static str, &'static str); N] {
    let mut out = [("", ""); N];
    let mut slot = 0;
    let mut index = 0;
    while index < parts.len() {
        let part = parts[index];
        let mut item = 0;
        while item < part.len() {
            out[slot] = part[item];
            slot += 1;
            item += 1;
        }
        index += 1;
    }
    out
}
