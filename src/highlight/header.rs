const SNIFF_LIMIT: usize = 64 * 1024;

const CPP_LINE_STARTS: &[&str] = &[
    "namespace ",
    "class ",
    "template ",
    "template<",
    "using ",
    "public:",
    "private:",
    "protected:",
    "extern \"C++\"",
];

pub fn is_cpp_header(text: &str) -> bool {
    clip(text)
        .lines()
        .map(str::trim_start)
        .any(|line| starts_cpp(line) || includes_cpp_std(line))
}

fn starts_cpp(line: &str) -> bool {
    CPP_LINE_STARTS.iter().any(|p| line.starts_with(p))
}

fn includes_cpp_std(line: &str) -> bool {
    let Some(rest) = line.strip_prefix('#') else {
        return false;
    };
    let Some(rest) = rest.trim_start().strip_prefix("include") else {
        return false;
    };
    match rest
        .trim_start()
        .strip_prefix('<')
        .and_then(|r| r.split_once('>'))
    {
        Some((name, _)) => !name.is_empty() && !name.contains('.'),
        None => false,
    }
}

fn clip(text: &str) -> &str {
    if text.len() <= SNIFF_LIMIT {
        return text;
    }
    let mut end = SNIFF_LIMIT;
    while !text.is_char_boundary(end) {
        end -= 1;
    }
    &text[..end]
}
