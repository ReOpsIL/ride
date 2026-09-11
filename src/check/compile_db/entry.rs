use serde::Deserialize;

#[derive(Deserialize)]
pub struct Entry {
    pub directory: String,
    pub file: String,
    command: Option<String>,
    arguments: Option<Vec<String>>,
}

impl Entry {
    pub fn argv(&self) -> Option<Vec<String>> {
        match (&self.arguments, &self.command) {
            (Some(args), _) => Some(args.clone()),
            (None, Some(command)) => shlex::split(command),
            (None, None) => None,
        }
    }
}
