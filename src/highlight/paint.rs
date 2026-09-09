use crate::ffi::ByteRange;

pub const HUGE: usize = 1024 * 1024;
pub const MARGIN: u32 = 2048;

pub fn paint_range(len: usize, visible: Option<ByteRange>) -> Vec<ByteRange> {
    if len < HUGE || visible.is_none() {
        vec![ByteRange {
            start_byte: 0,
            end_byte: len as u32,
        }]
    } else if let Some(visible) = visible {
        vec![expand(visible, len)]
    } else {
        vec![ByteRange {
            start_byte: 0,
            end_byte: len as u32,
        }]
    }
}

pub fn expand(visible: ByteRange, len: usize) -> ByteRange {
    ByteRange {
        start_byte: visible.start_byte.saturating_sub(MARGIN),
        end_byte: visible.end_byte.saturating_add(MARGIN).min(len as u32),
    }
}

pub fn clip_changed(
    changed: &[ByteRange],
    visible: Option<ByteRange>,
    len: usize,
) -> Vec<ByteRange> {
    if len < HUGE || visible.is_none() {
        return changed.to_vec();
    }
    let Some(visible) = visible else {
        return changed.to_vec();
    };
    let window = expand(visible, len);
    changed
        .iter()
        .filter_map(|c| super::ranges::intersect(*c, window))
        .collect()
}
