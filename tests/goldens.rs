use std::fs;
use std::path::Path;

use ride_engine::{CompletionContext, CompletionQuery, CompletionSiteKind, Engine, QueryMode};

#[path = "goldens/io.rs"]
mod io;
#[path = "support/sample.rs"]
mod sample;

use io::Case;
use sample::{engine, manifest};

const TOP: usize = 5;

fn sites() -> [(&'static str, CompletionSiteKind); 9] {
    use CompletionSiteKind::*;
    [
        ("none", None),
        ("identifier", Identifier),
        ("member_access", MemberAccess),
        ("scoped_path", ScopedPath),
        ("use_path", UsePath),
        ("include", Include),
        ("attribute", Attribute),
        ("directive", Directive),
        ("struct_literal", StructLiteral),
    ]
}

fn complete(engine: &Engine, case: &Case) -> (CompletionSiteKind, Vec<String>) {
    let file = manifest().join(&case.path);
    let src = fs::read_to_string(&file).unwrap();
    let (text, at) = io::place(&src, &case.after, &case.typed);
    let open = engine
        .open_session("g".into(), Some(file.display().to_string()), text, None)
        .unwrap();
    let resp = engine.query_completions(CompletionQuery {
        query_id: 1,
        session_id: open.session_id,
        prefix: String::new(),
        mode: QueryMode::BufferLocal,
        context: CompletionContext::Unknown,
        cursor_byte: at as u32,
        replace_start_byte: at as u32,
        current_crate: None,
        current_module: None,
        kind_filter: None,
        limit: 20,
    });
    let names = resp.hits.into_iter().take(TOP).map(|h| h.name).collect();
    (resp.site, names)
}

fn check_file(
    engine: &Engine,
    path: &Path,
    site: CompletionSiteKind,
    update: bool,
) -> Option<String> {
    let text = fs::read_to_string(path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
    let blocks = io::parse(&text);
    assert!(!blocks.is_empty(), "{} is empty", path.display());
    let mut actual = Vec::new();
    for (case, _) in &blocks {
        let (got, names) = complete(engine, case);
        assert_eq!(got, site, "{} {:?} site {got:?}", case.path, case.after);
        actual.push((case.clone(), names));
    }
    let rendered = io::render(&actual);
    if update {
        fs::write(path, &rendered).unwrap();
        return None;
    }
    let expected = io::render(&blocks);
    (rendered != expected)
        .then(|| format!("\n{}\n{}", path.display(), io::diff(&expected, &rendered)))
}

#[test]
fn ranking_goldens() {
    let (_dir, engine) = engine();
    let update = matches!(std::env::var("RIDE_UPDATE_GOLDENS"), Ok(v) if v == "1");
    let mut mismatches = String::new();
    for (stem, site) in sites() {
        let path = manifest().join("tests/goldens").join(format!("{stem}.txt"));
        if let Some(diff) = check_file(&engine, &path, site, update) {
            mismatches.push_str(&diff);
        }
    }
    assert!(mismatches.is_empty(), "{mismatches}");
}
