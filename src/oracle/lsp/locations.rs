use std::path::PathBuf;

use serde_json::Value;

use super::uri::uri_path;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Spot {
    pub path: PathBuf,
    pub line: usize,
    pub character: usize,
}

pub fn spots(result: &Value) -> Vec<Spot> {
    let items: Vec<&Value> = match result {
        Value::Array(items) => items.iter().collect(),
        Value::Object(_) => vec![result],
        _ => Vec::new(),
    };
    items.into_iter().filter_map(spot).collect()
}

fn spot(item: &Value) -> Option<Spot> {
    let uri = item["targetUri"]
        .as_str()
        .or_else(|| item["uri"].as_str())?;
    let range = if item["targetSelectionRange"].is_object() {
        &item["targetSelectionRange"]
    } else {
        &item["range"]
    };
    Some(Spot {
        path: uri_path(uri)?,
        line: range["start"]["line"].as_u64()? as usize,
        character: range["start"]["character"].as_u64()? as usize,
    })
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    #[test]
    fn a_location_link_points_at_the_name() {
        let result = json!([{
            "targetUri": "file:///a/b%20c.rs",
            "targetRange": { "start": { "line": 1, "character": 0 }, "end": { "line": 9, "character": 1 } },
            "targetSelectionRange": { "start": { "line": 2, "character": 7 }, "end": { "line": 2, "character": 10 } }
        }]);
        assert_eq!(
            spots(&result),
            [Spot {
                path: PathBuf::from("/a/b c.rs"),
                line: 2,
                character: 7
            }]
        );
    }

    #[test]
    fn a_plain_location_and_a_single_object_both_parse() {
        let one =
            json!({ "uri": "file:///x.cpp", "range": { "start": { "line": 4, "character": 2 } } });
        assert_eq!(spots(&one).len(), 1);
        assert!(spots(&Value::Null).is_empty());
    }
}
