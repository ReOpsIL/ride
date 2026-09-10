pub fn demo() {}
pub fn free_cache() {}
pub mod noise;
#[deprecated]
pub fn old_demo() {}
mod inner {
    pub mod deep {
        pub fn buried() {}
    }
}
pub use inner::deep::buried as surfaced;
#[cfg(test)]
mod tests {
    pub fn in_tests() {}
}
