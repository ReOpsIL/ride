use crate::follow::Mark;

use super::model::{Group, Inbox};

pub fn summary(inbox: &Inbox) -> String {
    let mut out = format!(
        "# Review\n\nBase {}. {} need eyes, {} verified, {} suspect, {} question, {} unchecked.\n\n",
        inbox.upstream,
        inbox.counts.needs_eyes,
        inbox.counts.verified,
        inbox.counts.suspect,
        inbox.counts.question,
        inbox.counts.unchecked
    );
    section(&mut out, "Behaviour", inbox, Group::Behaviour);
    section(&mut out, "Light", inbox, Group::Light);
    out.push_str(&format!(
        "\nEquivalent · {} (not counted).\n",
        inbox.counts.equivalent
    ));
    out
}

pub fn brief(inbox: &Inbox, marks: &[Mark], failing: Option<&str>) -> String {
    let mut out = format!(
        "# Review at {}\n\nBase {} {}. {} need eyes, {} verified.\n",
        short(&inbox.head),
        inbox.upstream,
        short(&inbox.base),
        inbox.counts.needs_eyes,
        inbox.counts.verified
    );
    if let Some(failing) = failing {
        out.push_str("\n## Failing\n\n");
        out.push_str(failing);
        out.push('\n');
    }
    bullets(&mut out, "Suspects", marks, "suspect");
    bullets(&mut out, "Questions", marks, "question");
    out.push_str("\n## How to answer\n\nWrite `.ride/follow/<author>.toml` with `agent = true`.\nOne `[[mark]]` per reply: `mark = \"answer\"`, `re = \"<id>\"`.\nFormat: `docs/sessions/follow-format.md`\n");
    out
}

fn section(out: &mut String, title: &str, inbox: &Inbox, group: Group) {
    let rows: Vec<_> = inbox.rows.iter().filter(|row| row.group == group).collect();
    if rows.is_empty() {
        return;
    }
    out.push_str(&format!("## {title}\n\n"));
    for row in rows {
        let checks = if row.checks.is_empty() {
            row.detail.clone()
        } else {
            row.checks.join(", ")
        };
        out.push_str(&format!(
            "- `{}` {} {} · {} {}\n",
            row.item,
            row.path,
            row.line,
            row.change.label(),
            checks
        ));
    }
}

fn bullets(out: &mut String, title: &str, marks: &[Mark], kind: &str) {
    let rows: Vec<_> = marks
        .iter()
        .filter(|mark| !mark.agent && mark.mark == kind)
        .collect();
    if rows.is_empty() {
        return;
    }
    out.push_str(&format!("\n## {title}\n\n"));
    for mark in rows {
        out.push_str(&format!(
            "- [{}] {} `{}` ({})\n  {}\n",
            mark.id, mark.path, mark.item, mark.author, mark.note
        ));
    }
}

fn short(hash: &str) -> &str {
    hash.get(..7).unwrap_or(hash)
}
