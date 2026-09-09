use crate::ffi::ByteRange;

pub fn from_ts(start: usize, end: usize) -> ByteRange {
    ByteRange {
        start_byte: start as u32,
        end_byte: end as u32,
    }
}

pub fn intersect(a: ByteRange, b: ByteRange) -> Option<ByteRange> {
    let start = a.start_byte.max(b.start_byte);
    let end = a.end_byte.min(b.end_byte);
    (start < end).then_some(ByteRange {
        start_byte: start,
        end_byte: end,
    })
}

pub fn subtract(covered: &[ByteRange], holes: &[ByteRange]) -> Vec<ByteRange> {
    let mut out = covered.to_vec();
    for hole in holes {
        let mut next = Vec::new();
        for span in out {
            if let Some(ix) = intersect(span, *hole) {
                if span.start_byte < ix.start_byte {
                    next.push(ByteRange {
                        start_byte: span.start_byte,
                        end_byte: ix.start_byte,
                    });
                }
                if ix.end_byte < span.end_byte {
                    next.push(ByteRange {
                        start_byte: ix.end_byte,
                        end_byte: span.end_byte,
                    });
                }
            } else {
                next.push(span);
            }
        }
        out = next;
    }
    out
}

pub fn union_into(base: &mut Vec<ByteRange>, extra: &[ByteRange]) {
    base.extend_from_slice(extra);
    base.sort_by_key(|r| r.start_byte);
    let mut merged: Vec<ByteRange> = Vec::new();
    for span in base.drain(..) {
        if let Some(last) = merged.last_mut()
            && last.end_byte >= span.start_byte
        {
            last.end_byte = last.end_byte.max(span.end_byte);
            continue;
        }
        merged.push(span);
    }
    *base = merged;
}
