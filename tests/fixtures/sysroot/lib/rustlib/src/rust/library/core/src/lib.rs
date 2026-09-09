pub struct CoreMarker;
pub mod option {
    pub enum Option {
        Some,
        None,
    }
}
pub mod hash {
    /// A hashable type.
    pub trait Hash {
        fn hash(&self);
    }
    pub type Digest = u8;
    pub mod shadow {
        pub type Hash = u8;
    }
}
