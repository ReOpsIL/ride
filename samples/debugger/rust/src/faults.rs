use std::panic;

pub fn run() {
    let parsed = parse_quantity("12");
    let rejected = parse_quantity("twelve");
    let caught = panic::catch_unwind(|| validate(-1));
    println!(
        "faults: parsed={parsed:?} rejected={} caught panic={}",
        rejected.is_err(),
        caught.is_err()
    );
}

fn parse_quantity(text: &str) -> Result<u32, String> {
    let value = text
        .parse::<u32>()
        .map_err(|err| format!("{text}: {err}"))?;
    Ok(value)
}

fn validate(value: i32) -> i32 {
    if value < 0 {
        panic!("negative value {value}");
    }
    value
}
