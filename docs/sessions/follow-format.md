# Follow file

One file per author at `.ride/follow/<author>.toml`. `<author>` is `git config user.name` with `/` and `\` removed. An empty name does not write a file.

The file is committed. It is the team's memory of what they checked. Ride does not review `.ride/` itself.

```toml
[author]
name = "Mira"
agent = false

[[mark]]
id = "m7k2q"
path = "src/fold.rs"
item = "fold::fold_entries"
kind = "fn"
mark = "question"
note = "why does a quiet batch skip the empty check?"
basis = "9e02c1aa"
commit = "4f2a9c1"
at = "1700000000"
```

`item` is the chain of outline names from outer to inner, joined by `::`. When two items in the file share that chain and kind, the signature is appended in parentheses.

`kind` is a stable label: `fn`, `method`, `struct`, `enum`, `union`, `trait`, `mod`, `type`, `const`, `static`, `macro`, `class`, `namespace`.

`mark` is `suspect`, `question`, `verified`, `answer`, or `note`.

`basis` is the shape hash of the item at the time of the mark. A short prefix of at least 8 hex digits matches. `commit` is the commit the mark was made on, and is what since-verified diffs from.

An answer sets `re` to the id it replies to. A human sets `accepted = true` on that answer. An agent file has `agent = true`. Agent marks never change a count or a verified state. They show as claims.

Entries stay sorted by `id`. Ids are time-prefixed so a later mark sorts after an earlier one.

Derived state is not stored:

| State | When |
| --- | --- |
| fresh | the item is still there and its shape hash matches `basis` |
| stale | the item is still there and the hash differs. Opens since-verified |
| moved | the id is gone and exactly one current item has the old hash |
| orphan | anything else |

Counts on the review are needs eyes, verified (fresh verified marks on the current hash, from any human), suspect, question, and unchecked. Unchecked is needs eyes minus the items that have a fresh verified mark, an open suspect, or an open question. A note's freshness is a column, not part of the count.
