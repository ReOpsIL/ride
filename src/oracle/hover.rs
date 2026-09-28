use serde_json::Value;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Hover {
    pub code: String,
    pub markdown: String,
}

pub fn hover_of(result: &Value) -> Option<Hover> {
    let text = contents(&result["contents"])?;
    let (code, markdown) = split_code(&text);
    (!code.is_empty() || !markdown.is_empty()).then_some(Hover { code, markdown })
}

fn contents(value: &Value) -> Option<String> {
    match value {
        Value::String(text) => Some(text.clone()),
        Value::Array(parts) => {
            let joined: Vec<String> = parts.iter().filter_map(contents).collect();
            (!joined.is_empty()).then(|| joined.join("\n\n"))
        }
        Value::Object(_) => match (value["language"].as_str(), value["value"].as_str()) {
            (Some(lang), Some(code)) => Some(format!("```{lang}\n{code}\n```")),
            (None, Some(text)) => Some(text.to_string()),
            _ => None,
        },
        _ => None,
    }
}

fn split_code(text: &str) -> (String, String) {
    let Some(open) = text.find("```") else {
        return (String::new(), text.trim().to_string());
    };
    let body_start = text[open..].find('\n').map_or(text.len(), |i| open + i + 1);
    let Some(close) = text[body_start..].find("```") else {
        return (String::new(), text.trim().to_string());
    };
    let code = text[body_start..body_start + close].trim().to_string();
    let rest = format!("{}{}", &text[..open], &text[body_start + close + 3..]);
    let markdown = rest
        .trim()
        .trim_start_matches("---")
        .trim_start_matches("___")
        .trim()
        .to_string();
    (code, markdown)
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    #[test]
    fn rust_analyzer_markup_splits_into_code_and_prose() {
        let result = json!({ "contents": { "kind": "markdown",
            "value": "\n```rust\nlet parts: Vec<&str>\n```\n\n---\n\nsize = 24, align = 0x8" } });
        let hover = hover_of(&result).expect("hover");
        assert_eq!(hover.code, "let parts: Vec<&str>");
        assert_eq!(hover.markdown, "size = 24, align = 0x8");
    }

    #[test]
    fn clangd_plaintext_keeps_its_prose() {
        let result = json!({ "contents": { "kind": "plaintext", "value": "variable it\n\nType: iterator" } });
        let hover = hover_of(&result).expect("hover");
        assert_eq!(hover.code, "");
        assert!(hover.markdown.contains("Type: iterator"));
    }

    #[test]
    fn an_empty_answer_is_none() {
        assert_eq!(hover_of(&Value::Null), None);
    }
}
