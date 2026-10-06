import Foundation

enum DemoChatScript {
    static let ghostAnchor = "println!(\"ride: {}\", counter.count(\"ride\"));"
    static let ghostText = " busiest = [\"ride\", \"engine\"]\n        .into_iter()\n        .max_by_key(|name| counter.count(name));"
    static let visionAnchor = "pub fn count(&self, name: &str) -> u32 {"
    static let visionGhost = "\n        self.counts.get(name).copied().unwrap_or_default()"

    static func messages(_ attachments: [AIChatAttachment]) -> [AIChatMessage] {
        [
            AIChatMessage(role: .user, text: AppState.explainSelectionPrompt, attachments: attachments),
            AIChatMessage(role: .assistant, text: explanation),
            AIChatMessage(role: .user, text: "What happens if a name is recorded that was never seen before?"),
            AIChatMessage(role: .assistant, text: followUp),
        ]
    }

    private static let explanation = """
    These two lines record one event each on the `Counter` built in `main`.

    1. `counter.record("ride")` calls `Recorder::record` (src/util.rs:14), which bumps the entry for `"ride"` in the `counts` map.
    2. `counter.record("engine")` does the same for `"engine"`.

    `record` takes `&mut self`, so `counter` must be declared `mut`, as it is on src/main.rs:9. Nothing is returned; the effect is the updated map, read back later through `count`.

    ```rust
    fn record(&mut self, name: &str) {
        *self.counts.entry(name.to_string()).or_insert(0) += 1;
    }
    ```

    **Worth knowing:** `name.to_string()` allocates on every call, even when the key already exists.
    """

    private static let followUp = """
    `entry` inserts it: `or_insert(0)` creates the slot with `0`, then `+= 1` makes it `1`. A later `count("new")` returns `1`, and `count` on a name that was never recorded returns `0` through `unwrap_or(0)` (src/util.rs:27).
    """
}
