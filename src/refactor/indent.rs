pub fn indent_of(text: &str, at: usize) -> String {
    let line_start = text
        .get(..at)
        .and_then(|head| head.rfind('\n').map(|i| i + 1))
        .unwrap_or(0);
    text.get(line_start..at)
        .unwrap_or_default()
        .chars()
        .take_while(|c| c.is_whitespace())
        .collect()
}
