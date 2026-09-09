mod hash {
    pub mod map {
        pub struct HashMap;
    }
}
pub mod hash_map {
    pub use super::hash::map::*;
}
pub use hash_map::HashMap;
pub struct HashSet;
pub trait Hash {
    fn hash(&self);
}
pub fn hash_slice() {}
pub fn free_std() {}
