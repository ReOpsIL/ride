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
impl HashMap {
    pub fn new() -> Self {
        HashMap
    }
    pub fn insert(&mut self) {}
    pub fn get(&self) {}
    pub fn len(&self) -> usize {
        0
    }
}
