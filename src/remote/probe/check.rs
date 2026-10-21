#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Status {
    Pass,
    Warn,
    Fail,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Check {
    pub title: String,
    pub status: Status,
    pub detail: String,
}

impl Check {
    pub fn pass(title: &str, detail: impl Into<String>) -> Self {
        Self::new(title, Status::Pass, detail)
    }

    pub fn warn(title: &str, detail: impl Into<String>) -> Self {
        Self::new(title, Status::Warn, detail)
    }

    pub fn fail(title: &str, detail: impl Into<String>) -> Self {
        Self::new(title, Status::Fail, detail)
    }

    fn new(title: &str, status: Status, detail: impl Into<String>) -> Self {
        Self {
            title: title.to_string(),
            status,
            detail: detail.into(),
        }
    }
}
