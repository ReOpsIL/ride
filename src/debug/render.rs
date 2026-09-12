use std::path::Path;

const LOOKUP_SCRIPT: &str = "lib/rustlib/etc/lldb_lookup.py";
const LOOKUP_COMMANDS: &str = "lib/rustlib/etc/lldb_commands";

pub fn init_commands(sysroot: Option<&Path>, rust_target: bool) -> Vec<String> {
    if !rust_target {
        return Vec::new();
    }
    let Some(sysroot) = sysroot else {
        return Vec::new();
    };
    let mut commands = Vec::new();
    let script = sysroot.join(LOOKUP_SCRIPT);
    if script.is_file() {
        commands.push(format!("command script import \"{}\"", script.display()));
    }
    let sourced = sysroot.join(LOOKUP_COMMANDS);
    if sourced.is_file() {
        commands.push(format!("command source -s 0 \"{}\"", sourced.display()));
    }
    commands
}
