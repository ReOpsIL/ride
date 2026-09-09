//! Sample crate inner docs.

/// A visible struct.
pub struct Foo {
    pub x: i32,
}

impl Foo {
    /// Make a foo.
    pub fn new() -> Self {
        Self { x: 0 }
    }

    fn hidden() {}
}

pub trait Trait {
    fn required(&self);
}

impl Trait for Foo {
    fn required(&self) {}
}

pub fn free_fn() {}

#[macro_export]
macro_rules! my_macro {
    () => {};
}

pub const K: i32 = 1;
pub type Alias = i32;
pub static S: i32 = 1;
pub enum E {
    A,
    B,
}
pub union U {
    pub a: u32,
}

pub mod time;
mod private_mod;

#[path = "elsewhere.rs"]
pub mod renamed;
