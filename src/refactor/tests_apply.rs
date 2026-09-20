use crate::ffi::ExtractPlan;

pub fn applied(text: &str, plan: &ExtractPlan) -> String {
    let mut out = text.to_string();
    for edit in plan.edits.iter().rev() {
        out.replace_range(edit.start_byte as usize..edit.end_byte as usize, &edit.text);
    }
    out
}

pub fn selected<'a>(text: &'a str, plan: &ExtractPlan) -> &'a str {
    &text[plan.select_start as usize..plan.select_end as usize]
}
