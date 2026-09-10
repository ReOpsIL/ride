const DIRECTIVES: &[&str] = &[
    "ifeq", "ifneq", "ifdef", "ifndef", "else", "endif", "define", "endef", "include", "-include",
    "sinclude", "export", "unexport", "override", "vpath", "undefine", "private",
];

pub fn format(text: &str) -> String {
    let mut out: Vec<String> = Vec::new();
    let mut in_recipe = false;
    let mut in_define = false;
    let mut continued = false;
    let mut blank_run = 0;
    for raw in text.lines() {
        let line = raw.trim_end();
        let word = first_word(line);
        if in_define {
            out.push(line.to_string());
            if word == "endef" {
                in_define = false;
            }
            continue;
        }
        if line.is_empty() {
            in_recipe = false;
            blank_run += 1;
            if blank_run == 1 {
                out.push(String::new());
            }
            continued = false;
            continue;
        }
        blank_run = 0;
        let indented = line.starts_with([' ', '\t']);
        let next = if continued {
            line.to_string()
        } else if indented && in_recipe {
            format!("\t{}", line.trim_start())
        } else {
            if !indented {
                in_recipe = is_rule(line, word);
                if word == "define" {
                    in_define = true;
                }
            }
            line.to_string()
        };
        continued = next.ends_with('\\');
        out.push(next);
    }
    while out.last().is_some_and(String::is_empty) {
        out.pop();
    }
    out.push(String::new());
    out.join("\n")
}

fn first_word(line: &str) -> &str {
    line.trim_start()
        .split(|c: char| c.is_whitespace() || c == ':' || c == '=')
        .next()
        .unwrap_or("")
}

fn is_rule(line: &str, word: &str) -> bool {
    if line.starts_with('#') || DIRECTIVES.contains(&word) {
        return false;
    }
    let Some(colon) = line.find(':') else {
        return false;
    };
    let after = line[colon + 1..].chars().next();
    let assignment_before = line[..colon].contains('=');
    !assignment_before && !matches!(after, Some('=') | Some(':'))
        || line[colon + 1..].starts_with(':') && !line[colon + 2..].starts_with('=')
}
