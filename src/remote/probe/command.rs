use super::super::argv::{self, Invocation, shell};
use super::super::check;
use super::super::endpoint::Endpoint;
use super::super::error::RemoteError;
use super::tools;

pub const MARK: &str = "ride-probe";

const ROOT: &str = r#"if [ -d "$d" ]; then
  if [ -w "$d" ]; then echo "MARK root ready"; else echo "MARK root readonly"; fi
else
  p=$d; while [ ! -e "$p" ]; do p=$(dirname "$p"); done
  if [ -d "$p" ] && [ -w "$p" ]; then echo "MARK root create $p"; else echo "MARK root blocked $p"; fi
fi"#;

const TOOLS: &str = r#"for t in $tools; do
  if p=$(command -v "$t" 2>/dev/null); then echo "MARK tool $t $p"; else echo "MARK tool $t"; fi
done"#;

impl Endpoint {
    pub fn probe(&self) -> Result<Invocation, RemoteError> {
        if let Some(identity) = self.identity()
            && !identity.is_file()
        {
            return Err(RemoteError::IdentityMissing {
                path: check::utf8(identity)?,
            });
        }
        let script = script(self)?;
        Ok(Invocation {
            program: "ssh".to_string(),
            args: argv::ssh_args(self, &format!("sh -c {}", shell(&script)?))?,
        })
    }
}

fn script(endpoint: &Endpoint) -> Result<String, RemoteError> {
    let root = shell(&check::utf8(endpoint.remote_root())?)?;
    let names = tools::names(&tools::needed(endpoint.local_root())).join(" ");
    let body = [
        r#"echo "MARK login $(id -un) $(uname -sm)""#.to_string(),
        format!("d={root}"),
        ROOT.to_string(),
        format!("tools='{names}'"),
        TOOLS.to_string(),
    ]
    .join("\n");
    Ok(body.replace("MARK", MARK))
}
