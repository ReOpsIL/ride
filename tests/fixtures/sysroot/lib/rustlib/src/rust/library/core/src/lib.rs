pub struct CoreMarker;
pub mod option {
    /// An optional value.
    pub enum Option<T> {
        /// Some value of type `T`.
        Some(T),
        /// No value.
        None,
    }
}
pub mod result {
    pub enum Result<T, E> {
        Ok(T),
        Err(E),
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
