use crate::generate::GenType;

pub(super) fn impl_block(t: &GenType) -> String {
    format!("impl {} {{}}\n", t.name)
}
