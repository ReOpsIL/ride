const FILE_BONUS: f32 = 10.0;
const EXACT_BONUS: f32 = 100.0;
const SHORT_NAME_CAP: usize = 40;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Tier {
    Project,
    SearchDir,
    System,
    Framework,
}

impl Tier {
    fn base(self) -> f32 {
        match self {
            Tier::Project => 900.0,
            Tier::SearchDir => 800.0,
            Tier::System => 700.0,
            Tier::Framework => 600.0,
        }
    }
}

pub fn score(tier: Tier, name: &str, is_dir: bool, prefix: &str) -> f32 {
    let mut score = tier.base();
    if !is_dir {
        score += FILE_BONUS;
    }
    score += SHORT_NAME_CAP.saturating_sub(name.len()) as f32;
    if name.eq_ignore_ascii_case(prefix) {
        score += EXACT_BONUS;
    }
    score
}

pub fn matches(name: &str, prefix: &str) -> bool {
    let visible = !name.starts_with("__") || prefix.starts_with('_');
    visible
        && name
            .get(..prefix.len())
            .is_some_and(|head| head.eq_ignore_ascii_case(prefix))
}
