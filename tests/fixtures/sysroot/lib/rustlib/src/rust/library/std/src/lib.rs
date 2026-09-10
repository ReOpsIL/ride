extern crate alloc as alloc_crate;
pub mod collections;
pub use core::option;
pub use core::option::Option;
pub use alloc_crate::vec;
mod sys {
    pub mod pal {
        pub const TOKEN_QUERY: u32 = 8;
    }
}
