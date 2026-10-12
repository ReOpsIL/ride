use ride_engine::review::{Change, FileInput, Group, review_files};

fn file(path: &str, old: Option<&str>, new: Option<&str>) -> FileInput {
    FileInput {
        path: path.to_string(),
        old_text: old.map(str::to_string),
        new_text: new.map(str::to_string),
        binary: false,
        hunks: None,
    }
}

fn rows(old: &str, new: &str) -> Vec<ride_engine::review::Row> {
    review_files(&[file("src/lib.rs", Some(old), Some(new))])
        .inbox
        .rows
}

fn kinds(old: &str, new: &str) -> Vec<Change> {
    rows(old, new).into_iter().map(|row| row.change).collect()
}

#[test]
fn body_signature_added_and_removed() {
    let body = rows(
        "fn add(a: i32) -> i32 { a }\n",
        "fn add(a: i32) -> i32 { a + 1 }\n",
    );
    assert_eq!(body.len(), 1);
    assert_eq!(body[0].change, Change::Body);
    assert_eq!(body[0].group, Group::Behaviour);
    assert!(body[0].checks.is_empty());

    let signature = rows(
        "fn add(a: i32) -> i32 { a }\n",
        "fn add(a: i64) -> i32 { a as i32 }\n",
    );
    assert_eq!(signature[0].change, Change::Signature);
    assert!(
        !signature[0]
            .checks
            .iter()
            .any(|check| check == "public signature")
    );

    let public = rows(
        "pub fn add(a: i32) -> i32 { a }\n",
        "pub fn add(a: i64) -> i32 { a as i32 }\n",
    );
    assert!(
        public[0]
            .checks
            .iter()
            .any(|check| check == "public signature")
    );

    let added = rows("", "fn added() {}\n");
    assert_eq!(added[0].change, Change::Added);
    assert!(added[0].checks.iter().any(|check| check == "added"));

    let removed = rows("fn gone() {}\n", "");
    assert_eq!(removed[0].change, Change::Removed);
    assert!(removed[0].checks.iter().any(|check| check == "removed"));
}

#[test]
fn formatting_and_comments_are_not_behaviour() {
    let formatted = rows(
        "fn add(a:i32,b:i32)->i32{a+b}\n",
        "fn add(a: i32, b: i32) -> i32 {\n    a + b\n}\n",
    );
    assert!(formatted.iter().all(|row| row.group != Group::Behaviour));

    let commented = rows(
        "fn add(a: i32, b: i32) -> i32 { a + b }\n",
        "fn add(a: i32, b: i32) -> i32 { /* note */ a + b }\n",
    );
    assert!(commented.iter().all(|row| row.group != Group::Behaviour));

    let docs = rows(
        "fn add(a: i32) -> i32 { a }\n",
        "/// sums\nfn add(a: i32) -> i32 { a }\n",
    );
    assert_eq!(docs.len(), 1);
    assert_eq!(docs[0].group, Group::Light);
    assert_eq!(docs[0].detail, "doc");
}

#[test]
fn one_token_in_two_hundred_items_leaves_equivalent() {
    let mut old = String::new();
    let mut new = String::new();
    for index in 0..200 {
        old.push_str(&format!("fn f{index}() -> i32 {{ {index} }}\n"));
        new.push_str(&format!("fn f{index}() -> i32 {{ {} }}\n", index + 1));
    }
    let found = rows(&old, &new);
    assert_eq!(found.len(), 200);
    assert!(found.iter().all(|row| row.group == Group::Behaviour));
    assert!(found.iter().all(|row| row.change == Change::Body));
}

#[test]
fn a_unique_move_is_equivalent_and_a_shared_shape_is_not() {
    let moved = review_files(&[
        file("src/a.rs", Some("fn moved() -> i32 { 1 }\n"), Some("")),
        file("src/b.rs", Some(""), Some("fn moved() -> i32 { 1 }\n")),
    ]);
    assert_eq!(moved.inbox.rows.len(), 1);
    assert_eq!(moved.inbox.rows[0].change, Change::Moved);
    assert_eq!(moved.inbox.rows[0].group, Group::Equivalent);
    assert_eq!(moved.inbox.rows[0].path, "src/b.rs");
    assert_eq!(moved.inbox.rows[0].old_path, "src/a.rs");

    let blocked = review_files(&[
        file("src/a.rs", Some("fn moved() -> i32 { 1 }\n"), Some("")),
        file(
            "src/b.rs",
            Some("fn moved() -> i32 { 1 }\n"),
            Some("fn moved() -> i32 { 1 }\n"),
        ),
        file("src/c.rs", Some(""), Some("fn moved() -> i32 { 1 }\n")),
    ]);
    let changes: Vec<_> = blocked.inbox.rows.iter().map(|row| row.change).collect();
    assert!(changes.contains(&Change::Added));
    assert!(changes.contains(&Change::Removed));
    assert!(!changes.contains(&Change::Moved));
}

#[test]
fn a_markdown_file_stays_a_file_hunk_and_ride_files_are_skipped() {
    let readme = review_files(&[file("README.md", Some("old\n"), Some("new\n"))]);
    assert_eq!(readme.inbox.rows.len(), 1);
    assert_eq!(readme.inbox.rows[0].change, Change::File);

    let hidden = review_files(&[file(".ride/follow/ada.toml", Some("a"), Some("b"))]);
    assert!(hidden.inbox.rows.is_empty());
}

#[test]
fn checks_light_only_on_a_real_delta() {
    let unsafe_added = rows(
        "fn f() { let x = 1; }\n",
        "fn f() { unsafe { let x = 1; } }\n",
    );
    assert!(unsafe_added[0].checks.iter().any(|check| check == "unsafe"));
    let unsafe_kept = rows("fn f() { unsafe { 1 } }\n", "fn f() { unsafe { 2 } }\n");
    assert!(!unsafe_kept[0].checks.iter().any(|check| check == "unsafe"));

    let weakened = rows(
        "#[test]\nfn t() { assert!(true); }\n",
        "#[test]\nfn t() { let _ = true; }\n",
    );
    assert!(
        weakened[0]
            .checks
            .iter()
            .any(|check| check == "test weakened")
    );
    assert_eq!(weakened[0].group, Group::Behaviour);
    let still = rows(
        "#[test]\nfn t() { assert!(true); }\n",
        "#[test]\nfn t() { assert!(false); }\n",
    );
    assert!(!still[0].checks.iter().any(|check| check == "test weakened"));
    assert_eq!(still[0].group, Group::Light);

    let panic = rows(
        "fn f(v: Option<i32>) -> i32 { v.unwrap_or(1) }\n",
        "fn f(v: Option<i32>) -> i32 { v.unwrap() }\n",
    );
    assert!(panic[0].checks.iter().any(|check| check == "new panic"));
    let index = rows(
        "fn f(a: [i32; 1]) -> i32 { a[0] }\n",
        "fn f(a: [i32; 1]) -> i32 { a[0] + 1 }\n",
    );
    assert!(!index[0].checks.iter().any(|check| check == "new panic"));
}

#[test]
fn import_only_is_light_and_a_header_signature_is_public() {
    let imports = rows(
        "use std::io::Read;\nfn keep() {}\n",
        "use std::fs::File;\nfn keep() {}\n",
    );
    assert!(
        imports
            .iter()
            .any(|row| row.detail == "import" && row.group == Group::Light)
    );
    assert!(imports.iter().all(|row| row.group != Group::Behaviour));

    let header = review_files(&[file(
        "include/add.h",
        Some("int add(int a, int b);\n"),
        Some("int add(int a, long b);\n"),
    )]);
    let row = header
        .inbox
        .rows
        .iter()
        .find(|row| row.change == Change::Signature)
        .expect("signature");
    assert!(row.checks.iter().any(|check| check == "public signature"));
}

#[test]
fn behaviour_sorts_by_checks_then_callers() {
    let source_old = "fn leaf() {}\nfn hot() { leaf(); }\nfn mid() {}\n";
    let source_new =
        "fn leaf() { unwrap_me(); }\nfn hot() { unsafe { leaf(); } }\nfn mid() { leaf(); }\n";
    let listed = rows(source_old, source_new);
    let behaviour: Vec<_> = listed
        .into_iter()
        .filter(|row| row.group == Group::Behaviour)
        .collect();
    assert!(behaviour.len() >= 2);
    for pair in behaviour.windows(2) {
        let left = (pair[0].checks.len(), pair[0].callers);
        let right = (pair[1].checks.len(), pair[1].callers);
        assert!(left >= right);
    }
}

#[test]
fn change_kinds_cover_the_scratch_set() {
    let found = kinds("fn same() { 1 }\n", "fn same() { 1 + 1 }\n");
    assert_eq!(found, vec![Change::Body]);
}

#[test]
fn a_mark_stays_fresh_across_formatting_and_stales_on_a_token() {
    use ride_engine::follow::{Mark, attach, derive, parse};
    use ride_engine::review::{Candidate, review_files};

    let formatted = review_files(&[file(
        "src/lib.rs",
        Some("fn add(a:i32)->i32{a}\n"),
        Some("fn add(a: i32) -> i32 { a }\n"),
    )]);
    let shape = formatted
        .inbox
        .rows
        .iter()
        .find(|row| row.group == Group::Equivalent)
        .map(|row| row.shape.clone())
        .expect("shape");
    let mark = Mark {
        id: "m1".into(),
        author: "Ada".into(),
        agent: false,
        path: "src/lib.rs".into(),
        item: "add".into(),
        kind: "fn".into(),
        mark: "verified".into(),
        note: String::new(),
        basis: shape,
        commit: "abc".into(),
        at: "1".into(),
        re: String::new(),
        accepted: false,
    };
    let items: Vec<Candidate> = formatted.items.clone();
    assert_eq!(derive(&mark, &items), "fresh");
    let changed = review_files(&[file(
        "src/lib.rs",
        Some("fn add(a: i32) -> i32 { a }\n"),
        Some("fn add(a: i32) -> i32 { a + 1 }\n"),
    )]);
    assert_eq!(derive(&mark, &changed.items), "stale");
    let mut inbox = changed.inbox;
    attach(&mut inbox, &[mark], &changed.items);
    assert_eq!(inbox.counts.verified, 0);
    assert!(inbox.rows.iter().any(|row| row.mark_state == "stale"));

    let round = "\
[author]
name = \"Ada\"
agent = false

[[mark]]
id = \"m1\"
path = \"src/lib.rs\"
item = \"add\"
kind = \"fn\"
mark = \"question\"
note = \"why\"
basis = \"abcdef0123456789\"
commit = \"abc\"
at = \"1\"
";
    let parsed = parse(round);
    assert_eq!(parsed.len(), 1);
    assert_eq!(parsed[0].mark, "question");
    assert!(!parsed[0].agent);
}

#[test]
fn hunt_lists_only_a_name_the_failing_test_calls() {
    use ride_engine::review::hunt;
    let old = "fn called() { 1 }\nfn other() { 1 }\n";
    let new = "fn called() { 2 }\nfn other() { 2 }\n";
    let built = review_files(&[file("src/lib.rs", Some(old), Some(new))]);
    let hits = hunt(&["called".into()], &built.inbox.rows, &[]);
    assert_eq!(hits.len(), 1);
    assert_eq!(hits[0].name, "called");
}

#[test]
fn since_verified_is_a_line_diff() {
    use ride_engine::review::since_lines;
    let diff = since_lines("fn add() {\n    1\n}\n", "fn add() {\n    2\n}\n");
    assert!(diff.iter().any(|line| line == "-     1"));
    assert!(diff.iter().any(|line| line == "+     2"));
}

#[test]
fn a_dossier_lists_every_mark_and_only_the_author_can_drop_it() {
    use ride_engine::review::listed_marks;

    let marks = vec![
        sample_mark("1", "Ada", false, "suspect"),
        sample_mark("2", "Bea", false, "question"),
        sample_mark("", "Ada", false, "verified"),
        sample_mark("4", "Ada", true, "answer"),
    ];
    let lines = listed_marks(&marks, "src/fold.rs", "fold_entries", "Ada");
    assert_eq!(lines.len(), 4);
    assert_eq!(lines[0].text, "suspect · Ada · asdad");
    assert!(lines[0].own);
    assert!(!lines[1].own);
    assert!(!lines[2].own);
    assert_eq!(lines[3].text, "claim · Ada · asdad");
    assert!(lines[3].own);
}

#[test]
fn dropping_one_mark_leaves_the_others() {
    use ride_engine::follow;

    let dir = tempfile::tempdir().expect("dir");
    for id in ["1", "2", "3"] {
        follow::upsert(dir.path(), "Ada", false, sample_mark(id, "Ada", false, id))
            .expect("upsert");
    }
    follow::drop(dir.path(), "Ada", "2").expect("drop");
    let left: Vec<_> = follow::read_all(dir.path())
        .into_iter()
        .map(|mark| mark.id)
        .collect();
    assert_eq!(left, vec!["1".to_string(), "3".to_string()]);
}

fn sample_mark(id: &str, author: &str, agent: bool, kind: &str) -> ride_engine::follow::Mark {
    ride_engine::follow::Mark {
        id: id.to_string(),
        author: author.to_string(),
        agent,
        path: "src/fold.rs".to_string(),
        item: "fold_entries".to_string(),
        kind: "fn".to_string(),
        mark: kind.to_string(),
        note: "asdad".to_string(),
        basis: String::new(),
        commit: String::new(),
        at: "1".to_string(),
        re: String::new(),
        accepted: false,
    }
}
