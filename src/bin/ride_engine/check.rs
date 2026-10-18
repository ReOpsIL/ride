use std::path::{Path, PathBuf};
use std::process::ExitCode;

use ride_engine::{Diagnostic, DiagnosticLabel, DiagnosticLevel, run_check};

pub fn run(root: PathBuf, clippy: bool, file: Option<PathBuf>) -> ExitCode {
    match run_check(&root, &root, None, clippy) {
        Ok(result) => {
            for diagnostic in result
                .diagnostics
                .iter()
                .filter(|diagnostic| selected(diagnostic, &root, file.as_deref()))
            {
                print_diagnostic(diagnostic);
            }
            ExitCode::SUCCESS
        }
        Err(err) => {
            eprintln!("{err}");
            ExitCode::from(1)
        }
    }
}

fn selected(diagnostic: &Diagnostic, root: &Path, file: Option<&Path>) -> bool {
    let Some(file) = file else {
        return true;
    };
    let wanted = if file.is_absolute() {
        file.to_path_buf()
    } else {
        root.join(file)
    };
    let path = Path::new(&diagnostic.primary.path);
    path == wanted || same_file(path, &wanted)
}

fn same_file(left: &Path, right: &Path) -> bool {
    match (left.canonicalize(), right.canonicalize()) {
        (Ok(left), Ok(right)) => left == right,
        _ => false,
    }
}

fn print_diagnostic(diagnostic: &Diagnostic) {
    let code = diagnostic.code.as_deref().unwrap_or("-");
    println!(
        "{} {code} {}",
        level_name(diagnostic.level),
        diagnostic.message
    );
    print_label('P', &diagnostic.primary);
    for label in &diagnostic.secondary {
        print_label('S', label);
    }
    for note in &diagnostic.notes {
        for label in &note.labels {
            print_label('N', label);
        }
    }
    for fix in &diagnostic.fixes {
        println!("  fix: {}", fix.title);
    }
}

fn print_label(kind: char, label: &DiagnosticLabel) {
    let text = label
        .text
        .as_deref()
        .filter(|text| !text.is_empty())
        .unwrap_or("-");
    println!(
        "  {kind} {}:{}:{} {text}",
        label.path, label.line_start, label.column
    );
}

fn level_name(level: DiagnosticLevel) -> &'static str {
    match level {
        DiagnosticLevel::Error => "error",
        DiagnosticLevel::Warning => "warning",
        DiagnosticLevel::Note => "note",
        DiagnosticLevel::Help => "help",
    }
}
