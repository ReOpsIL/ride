pub fn split_name_version(dir: &str) -> Option<(String, String)> {
    for (idx, _) in dir.match_indices('-') {
        let rest = &dir[idx + 1..];
        if rest.starts_with(|c: char| c.is_ascii_digit()) && rest.contains('.') {
            return Some((dir[..idx].to_string(), rest.to_string()));
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::split_name_version;

    #[test]
    fn serde_version() {
        assert_eq!(
            split_name_version("serde-1.0.219"),
            Some(("serde".into(), "1.0.219".into()))
        );
    }

    #[test]
    fn prerelease() {
        assert_eq!(
            split_name_version("foo-1.0.0-alpha.1"),
            Some(("foo".into(), "1.0.0-alpha.1".into()))
        );
    }

    #[test]
    fn hyphenated_name() {
        assert_eq!(
            split_name_version("serde_json-1.0.0"),
            Some(("serde_json".into(), "1.0.0".into()))
        );
        assert_eq!(
            split_name_version("encoding-index-korean-1.20141219.5"),
            Some(("encoding-index-korean".into(), "1.20141219.5".into()))
        );
    }
}
