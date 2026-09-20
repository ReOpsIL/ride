pub fn panic_line(time: u64, message: &str, location: &str, backtrace: &str) -> String {
    serde_json::json!({
        "time": time,
        "message": message,
        "location": location,
        "backtrace": backtrace,
    })
    .to_string()
}

#[cfg(test)]
mod tests {
    use super::panic_line;

    #[test]
    fn quotes_and_newlines_stay_inside_one_line() {
        let line = panic_line(7, "bad \"input\"", "src/x.rs:3:1", "frame\nframe");
        assert!(!line.contains('\n'));
        let value: serde_json::Value = serde_json::from_str(&line).unwrap();
        assert_eq!(value["time"], 7);
        assert_eq!(value["message"], "bad \"input\"");
        assert_eq!(value["backtrace"], "frame\nframe");
    }
}
