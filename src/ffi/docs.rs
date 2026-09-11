#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct DocLink {
    pub label: String,
    pub url: String,
}

#[derive(Debug, Clone, PartialEq, Eq, uniffi::Record)]
pub struct QuickDoc {
    pub title: String,
    pub signature: String,
    pub html: String,
    pub origin_path: String,
    pub origin_line: u32,
    pub links: Vec<DocLink>,
}
