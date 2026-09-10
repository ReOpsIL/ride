pub struct AllocMarker;
pub mod vec {
    pub struct Vec;
    impl Vec {
        pub fn new() -> Self {
            Vec
        }
        pub fn push(&mut self) {}
        pub fn len(&self) -> usize {
            0
        }
    }
}
