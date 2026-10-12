pub fn lines(old: &str, new: &str) -> Vec<String> {
    let old_lines: Vec<&str> = old.lines().collect();
    let new_lines: Vec<&str> = new.lines().collect();
    if old_lines.len() * new_lines.len() > 160_000 {
        return vec![
            format!("- {}", old_lines.len()),
            format!("+ {}", new_lines.len()),
        ];
    }
    let table = lcs(&old_lines, &new_lines);
    let mut out = Vec::new();
    walk(
        &table,
        &old_lines,
        &new_lines,
        old_lines.len(),
        new_lines.len(),
        &mut out,
    );
    out.reverse();
    out
}

fn lcs(old: &[&str], new: &[&str]) -> Vec<Vec<u32>> {
    let mut table = vec![vec![0u32; new.len() + 1]; old.len() + 1];
    for i in 0..old.len() {
        for j in 0..new.len() {
            table[i + 1][j + 1] = if old[i] == new[j] {
                table[i][j] + 1
            } else {
                table[i][j + 1].max(table[i + 1][j])
            };
        }
    }
    table
}

fn walk(table: &[Vec<u32>], old: &[&str], new: &[&str], i: usize, j: usize, out: &mut Vec<String>) {
    if i == 0 && j == 0 {
        return;
    }
    if i > 0 && j > 0 && old[i - 1] == new[j - 1] {
        walk(table, old, new, i - 1, j - 1, out);
        return;
    }
    if j > 0 && (i == 0 || table[i][j - 1] >= table[i - 1][j]) {
        out.push(format!("+ {}", new[j - 1]));
        walk(table, old, new, i, j - 1, out);
        return;
    }
    if i > 0 {
        out.push(format!("- {}", old[i - 1]));
        walk(table, old, new, i - 1, j, out);
    }
}
