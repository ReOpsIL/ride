const WITH_VALUE: &[&str] = &["-I", "-D", "-isystem", "-iquote", "-F"];
pub const PATH_FLAGS: &[&str] = &["-I", "-isystem", "-iquote", "-F"];

pub enum CompileArg<'a> {
    Valued {
        flag: &'static str,
        value: &'a str,
        joined: bool,
    },
    Plain(&'a str),
}

impl CompileArg<'_> {
    pub fn is_path(&self) -> bool {
        matches!(self, CompileArg::Valued { flag, .. } if PATH_FLAGS.contains(flag))
    }
}

pub fn compile_args(args: &[String]) -> Vec<CompileArg<'_>> {
    let mut out = Vec::new();
    let mut it = args.iter().map(String::as_str);
    while let Some(arg) = it.next() {
        if let Some(flag) = WITH_VALUE.iter().find(|f| **f == arg) {
            if let Some(value) = it.next() {
                out.push(CompileArg::Valued {
                    flag,
                    value,
                    joined: false,
                });
            }
        } else if let Some(flag) = WITH_VALUE.iter().find(|f| joined(arg, f)) {
            out.push(CompileArg::Valued {
                flag,
                value: &arg[flag.len()..],
                joined: true,
            });
        } else {
            out.push(CompileArg::Plain(arg));
        }
    }
    out
}

fn joined(arg: &str, flag: &str) -> bool {
    arg.len() > flag.len() && arg.starts_with(flag)
}
