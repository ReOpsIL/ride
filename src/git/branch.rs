use crate::error::EngineError;
use crate::ffi::GitBranch;

use super::branch_name::BranchName;
use super::cli::Git;

const FORMAT: &str =
    "--format=%(HEAD)%00%(refname)%00%(refname:short)%00%(upstream:short)%00%(symref)";

pub fn branches(git: &Git) -> Result<Vec<GitBranch>, EngineError> {
    let out = git.run(&["for-each-ref", FORMAT, "refs/heads", "refs/remotes"])?;
    Ok(out.stdout.lines().filter_map(parse_ref).collect())
}

pub fn create(git: &Git, name: &str, checkout: bool) -> Result<(), EngineError> {
    let name = BranchName::parse(git, name)?;
    let args: &[&str] = if checkout {
        &["switch", "--create", name.as_str()]
    } else {
        &["branch", "--", name.as_str()]
    };
    git.run(args).map(|_| ())
}

pub fn checkout(git: &Git, branch: &GitBranch) -> Result<(), EngineError> {
    let name = BranchName::parse(git, &branch.name)?;
    let args: &[&str] = if branch.remote {
        &["switch", "--track", name.as_str()]
    } else {
        &["switch", name.as_str()]
    };
    git.run(args).map(|_| ())
}

fn parse_ref(line: &str) -> Option<GitBranch> {
    let mut fields = line.split('\0');
    let head = fields.next()?;
    let full = fields.next()?;
    let name = fields.next()?;
    let upstream = fields.next().unwrap_or_default();
    let symref = fields.next().unwrap_or_default();
    if !symref.is_empty() {
        return None;
    }
    Some(GitBranch {
        name: name.to_string(),
        remote: full.starts_with("refs/remotes/"),
        current: head == "*",
        upstream: (!upstream.is_empty()).then(|| upstream.to_string()),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_local_and_remote_refs() {
        let local = parse_ref("*\0refs/heads/main\0main\0origin/main\0").unwrap();
        assert!(local.current && !local.remote);
        assert_eq!(local.upstream.as_deref(), Some("origin/main"));
        let remote = parse_ref(" \0refs/remotes/origin/dev\0origin/dev\0\0").unwrap();
        assert!(remote.remote && !remote.current);
        assert_eq!(remote.name, "origin/dev");
    }

    #[test]
    fn skips_symbolic_remote_heads() {
        assert!(
            parse_ref(" \0refs/remotes/origin/HEAD\0origin\0\0refs/remotes/origin/main").is_none()
        );
    }
}
