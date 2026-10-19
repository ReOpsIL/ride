use ride_engine::{BufferSession, Lang};

struct Spot {
    needle: &'static str,
    nth: usize,
    name: &'static str,
    qualifier: Option<&'static str>,
}

fn spots(lang: Lang, src: &str, want: &[Spot]) -> Vec<String> {
    let (session, _) = BufferSession::open_lang(lang, src.to_string(), None).unwrap();
    let mut misses = Vec::new();
    for spot in want {
        let at = src
            .match_indices(spot.needle)
            .nth(spot.nth)
            .unwrap_or_else(|| panic!("missing {}", spot.needle))
            .0;
        let start = at + spot.needle.find(spot.name).expect(spot.needle);
        let probes = [
            ("start", start),
            ("inside", start + spot.name.len() / 2),
            ("after", start + spot.name.len()),
        ];
        for (label, byte) in probes {
            let symbol = session.symbol_at(byte as u32);
            let name = symbol.as_ref().map(|s| s.name.as_str());
            let qualifier = symbol.as_ref().and_then(|s| s.qualifier.as_deref());
            if name != Some(spot.name) || qualifier != spot.qualifier {
                misses.push(format!(
                    "{label} {} byte {byte}: got {name:?} qual {qualifier:?}, want {} qual {:?}",
                    spot.needle, spot.name, spot.qualifier
                ));
            }
        }
    }
    misses
}

#[test]
fn every_rust_type_name_is_the_symbol_under_its_first_byte() {
    let src = "\
struct E;
trait Read {}
trait Send {}
trait Error {}
trait Iterator {}
fn f(base: &Path, items: Vec<String>) -> Result<PathBuf, E> {}
fn g<T: Read>(value: &mut T) where T: Send {}
fn h() -> &'static str {}
fn i(p: *const u8, q: *mut i32) {}
fn k() { let _x: std::path::PathBuf = todo!(); }
type Boxed = Box<dyn Error>;
fn j() -> impl Iterator {}
fn call(value: &str) { value.trim_start(); }
";
    let want = [
        Spot {
            needle: "&Path",
            nth: 0,
            name: "Path",
            qualifier: None,
        },
        Spot {
            needle: "Vec<",
            nth: 0,
            name: "Vec",
            qualifier: None,
        },
        Spot {
            needle: "<String>",
            nth: 0,
            name: "String",
            qualifier: None,
        },
        Spot {
            needle: "PathBuf,",
            nth: 0,
            name: "PathBuf",
            qualifier: None,
        },
        Spot {
            needle: ", E>",
            nth: 0,
            name: "E",
            qualifier: None,
        },
        Spot {
            needle: "<T:",
            nth: 0,
            name: "T",
            qualifier: None,
        },
        Spot {
            needle: "T: Read",
            nth: 0,
            name: "Read",
            qualifier: None,
        },
        Spot {
            needle: "&mut T",
            nth: 0,
            name: "T",
            qualifier: None,
        },
        Spot {
            needle: "T: Send",
            nth: 0,
            name: "Send",
            qualifier: None,
        },
        Spot {
            needle: "str {}",
            nth: 0,
            name: "str",
            qualifier: None,
        },
        Spot {
            needle: "u8",
            nth: 0,
            name: "u8",
            qualifier: None,
        },
        Spot {
            needle: "i32",
            nth: 0,
            name: "i32",
            qualifier: None,
        },
        Spot {
            needle: "PathBuf =",
            nth: 0,
            name: "PathBuf",
            qualifier: Some("std::path"),
        },
        Spot {
            needle: "dyn Error",
            nth: 0,
            name: "Error",
            qualifier: None,
        },
        Spot {
            needle: "impl Iterator",
            nth: 0,
            name: "Iterator",
            qualifier: None,
        },
        Spot {
            needle: "trim_start",
            nth: 0,
            name: "trim_start",
            qualifier: None,
        },
    ];
    let misses = spots(Lang::Rust, src, &want);
    assert!(misses.is_empty(), "{}", misses.join("\n"));
}

#[test]
fn every_c_type_name_is_the_symbol_under_its_first_byte() {
    let src = "\
struct Path;
void f(const Path *base, struct Path* tight, char* text, int count, size_t n);
";
    let want = [
        Spot {
            needle: "Path *",
            nth: 0,
            name: "Path",
            qualifier: None,
        },
        Spot {
            needle: "Path*",
            nth: 0,
            name: "Path",
            qualifier: None,
        },
        Spot {
            needle: "char*",
            nth: 0,
            name: "char",
            qualifier: None,
        },
        Spot {
            needle: "int ",
            nth: 0,
            name: "int",
            qualifier: None,
        },
        Spot {
            needle: "size_t",
            nth: 0,
            name: "size_t",
            qualifier: None,
        },
    ];
    let misses = spots(Lang::C, src, &want);
    assert!(misses.is_empty(), "{}", misses.join("\n"));
}

#[test]
fn every_cpp_type_name_is_the_symbol_under_its_first_byte() {
    let src = "\
struct String;
template<typename T> struct Vec { T value; };
void f(const String& base, Vec<String> items, std::string name, int* count);
";
    let want = [
        Spot {
            needle: "String&",
            nth: 0,
            name: "String",
            qualifier: None,
        },
        Spot {
            needle: "Vec<",
            nth: 0,
            name: "Vec",
            qualifier: None,
        },
        Spot {
            needle: "<String>",
            nth: 0,
            name: "String",
            qualifier: None,
        },
        Spot {
            needle: "string ",
            nth: 0,
            name: "string",
            qualifier: Some("std"),
        },
        Spot {
            needle: "int*",
            nth: 0,
            name: "int",
            qualifier: None,
        },
    ];
    let misses = spots(Lang::Cpp, src, &want);
    assert!(misses.is_empty(), "{}", misses.join("\n"));
}
