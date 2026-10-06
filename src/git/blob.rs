use std::fs;

use super::cli::Git;
use super::diff_plan::Source;

pub fn read(git: &Git, source: Source, path: &str) -> Option<String> {
    match source {
        Source::WorkTree => fs::read(git.dir().join(path))
            .ok()
            .map(|bytes| String::from_utf8_lossy(&bytes).into_owned()),
        Source::Head => show(git, &format!("HEAD:{path}")),
        Source::Index => show(git, &format!(":{path}")),
    }
}

fn show(git: &Git, object: &str) -> Option<String> {
    git.run(&["show", "--no-textconv", object])
        .ok()
        .map(|out| out.stdout)
}
