use serde::{Deserialize, Serialize};

use crate::ffi::OutlineItem;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Visibility {
    Everywhere,
    Within(u32, u32),
}

impl Visibility {
    pub fn admits(self, at: u32, same_file: bool) -> bool {
        match self {
            Self::Everywhere => true,
            Self::Within(start, end) => same_file && start <= at && at < end,
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Unqualified {
    pub item: OutlineItem,
    pub visibility: Visibility,
}
