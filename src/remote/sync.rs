use super::argv::{self, Invocation, shell};
use super::check;
use super::endpoint::Endpoint;
use super::error::RemoteError;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SyncJob {
    pub pack: Invocation,
    pub unpack: Invocation,
}

const EXCLUDES: [&str; 3] = ["target", "build", ".git"];

impl Endpoint {
    pub fn sync(&self) -> Result<SyncJob, RemoteError> {
        let root = check::utf8(self.local_root())?;
        let remote = check::utf8(self.remote_root())?;
        let quoted = shell(&remote)?;
        Ok(SyncJob {
            pack: pack(&root),
            unpack: Invocation {
                program: "ssh".to_string(),
                args: argv::ssh_args(self, &format!("mkdir -p {quoted} && tar -x -C {quoted}"))?,
            },
        })
    }
}

fn pack(root: &str) -> Invocation {
    let mut args = vec!["-c".to_string(), "-C".to_string(), root.to_string()];
    for name in EXCLUDES {
        args.push("--exclude".to_string());
        args.push(name.to_string());
    }
    args.push(".".to_string());
    Invocation {
        program: "tar".to_string(),
        args,
    }
}
