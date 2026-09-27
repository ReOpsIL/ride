pub fn normalized(name: &str) -> String {
    name.replace('-', "_")
}

pub fn root_of(path: &str) -> &str {
    path.split("::").next().unwrap_or(path)
}

pub fn same_crate(a: &str, b: &str) -> bool {
    normalized(a) == normalized(b)
}
