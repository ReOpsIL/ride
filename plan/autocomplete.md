> **Absorbed into [`ride_draft.md`](./ride_draft.md).** This file is historical source notes. Implement against the merged spec.

You do **not** need a cloud LLM. For this job the right design is a **local index + hybrid retrieval**, with a tiny embedding model (or even no neural net at all) doing the “meaning” part. A 32 GB Mac Pro is more than enough if you treat the LLM as optional polish, not the search engine.

## What you are actually building

There are three different products people collapse into “autocomplete over installed crates”:

| Goal | Best mechanism | Neural model needed? |
|---|---|---|
| Type a crate/item name (`HashMap`, `tokio::spawn`) | Fuzzy / prefix / rustdoc-style name index | No |
| Type a phrase (`retry with backoff`, `parse toml into struct`) | Hybrid BM25 + embeddings | Small embedder only |
| Generate an answer from hits | Local 1–3B model on retrieved snippets | Optional |

Start with the first two. Autocomplete must return in **<20–50 ms** after each keystroke. That rules out running a generative LLM on every keypress.

rust-analyzer already does fuzzy symbol search over the **current workspace + its deps**. Your extra work is a **global, offline catalog** of whatever Cargo has actually unpacked on disk.

## Where the data lives

Cargo’s cache is the corpus. Typical layout:

- `~/.cargo/registry/src/<registry-hash>/<crate>-<version>/` — unpacked crates.io sources  
- `~/.cargo/registry/cache/` — `.crate` tarballs (extract if src is missing)  
- `~/.cargo/git/checkouts/` — git deps  
- `~/.cargo/bin` + `~/.cargo/.crates2.json` — `cargo install` binaries (names only; sources may not be present)  
- Current project: `cargo metadata --format-version 1` for exact resolved versions

Do **not** index all of crates.io. Index what is already on disk. That is both the security story and the scale story.

On a busy machine that is often hundreds to a few thousand crate versions, not millions of files.

## Architecture that stays local and fast

```
keystroke
  → lexical candidates (Tantivy / FST / nucleo)     ~1–5 ms
  → optional vector rerank of top 50–200             ~5–20 ms
  → optional tiny cross-encoder on top 10            ~20–80 ms
  → UI: crate :: path :: item + 2-line snippet
```

### Layer 1 — lexical (mandatory)

This is what makes autocomplete feel instant.

- **Name / path index**: crate, module path, item kind, signature. Same idea as rustdoc search and rust-analyzer’s FST index.  
- **Full-text**: Tantivy (Lucene-like, native Rust) over docs, signatures, and selected source. BM25 + prefix + fuzzy.  
- **Tiny fuzzy engines** if you only need names: `nucleo`, `nucleo-matcher`, `simsearch`, or rust-analyzer’s `fst` approach.

Fields worth indexing separately:

- `crate`, `version`, `item_kind` (`fn` / `struct` / `trait` / `macro` / `mod`)  
- `path` (`tokio::time::sleep`)  
- `signature`  
- `doc_first_paragraph`  
- `source_chunk` (optional)  
- `features`, `edition`

This alone already beats `rg` over `~/.cargo/registry/src` for autocomplete.

### Layer 2 — local similarity (optional but worth it)

Use embeddings only for “I described the thing, I don’t know its name.”

Good Rust-native stack:

- **Embedder**: `fastembed` (ONNX Runtime, no Python). Default models: `all-MiniLM-L6-v2` (~80 MB, 384-d) or `BAAI/bge-small-en-v1.5` (~23–130 MB).  
- **Vector store**: sqlite-vec, usearch, `vicinity` (HNSW), or even brute-force cosine if you stay under a few hundred thousand chunks.  
- **Fusion**: Reciprocal Rank Fusion of BM25 + vector. This is the standard hybrid recipe used by several 2026 Rust code-search crates (`semtree`, `search-semantically`, `aurora-semantic`, `vecgrep`).

You do **not** embed every line. Embed **items**.

### Layer 3 — local LLM (optional, not for autocomplete)

On 32 GB you can run a small model for *explanation* after a hit is chosen:

- Apple Silicon: MLX / Ollama / llama.cpp, 1B–8B Q4  
- Intel Mac Pro: llama.cpp / ONNX / Ollama on CPU — keep it ≤3B Q4 if you want it snappy  

Use it for “summarize this item” or “which of these 5 hits matches?”, never for the live typeahead list.

## How to chunk Rust crates so search is useful

Naive 512-token windows over `.rs` files produce junk. Parse structure.

Preferred pipeline:

1. Walk each unpacked crate.  
2. Parse with **tree-sitter-rust** or **syn** (syn is more precise for items, tree-sitter is more forgiving of broken files).  
3. One document per item:
   - module / `struct` / `enum` / `trait` / `impl` method / free `fn` / `macro_rules!`  
   - text = `///` docs + signature + first ~30–80 lines of body  
4. Also index `README.md`, `Cargo.toml` description, and examples.  
5. Skip `target/`, generated files, minified JS in proc-macro crates, huge vendored C sources (`*-sys` crates). Cap file size.

Even better if you can afford it: generate **rustdoc JSON** (`RUSTDOCFLAGS='-Z unstable-options --output-format json'` or `cargo +nightly rustdoc`) and index *documented public API* instead of raw source. That matches how humans search docs.rs.

A pragmatic hybrid:

- Public API + docs from rustdoc JSON (quality)  
- Private helpers + examples from source (coverage)

## Models that fit a 32 GB Mac Pro

32 GB is comfortable for **retrieval**. The constraint is latency and whether the machine is Intel or Apple Silicon.

**Recommended default (any Mac, including Intel Mac Pro):**

- Embedder: MiniLM-L6 or BGE-small via ONNX (`fastembed` / `ort`)  
- RAM: ~0.3–1 GB while embedding  
- Indexing speed: thousands of chunks/sec on CPU  
- Search: embed the query once (~5–15 ms) + ANN

**If you have Apple Silicon and want better code retrieval:**

- Jina code embeddings, Qwen3-Embedding-0.6B, EmbeddingGemma-300M  
- Still well under 32 GB  
- MLX is faster than ONNX on M-series; skip MLX on Intel

**Avoid for autocomplete:**

- 7B+ embedding models just to search crate docs  
- Sending crate source to any hosted embed API (your security constraint)

Quality order of magnitude for this corpus: a 22–160M encoder on **item-level docs** beats a giant model on raw files.

Static / hashing embeddings (no transformer) are a valid v0 if you only need “a bit better than grep.” Several IDE-oriented crates ship that as fallback.

## Index size and incremental updates

Rough numbers:

- 2,000 unpacked crates × ~80 public items ≈ 160k documents  
- 384-d float32 vectors ≈ 250 MB  
- Tantivy text index often 200–800 MB  
- Total on disk: typically **0.5–2 GB**, not tens of GB

Updates:

- Content-hash each crate version directory (or use Cargo’s immutable `name-version` folders).  
- Re-embed only new/changed versions.  
- Watch `~/.cargo/registry/src` with `notify` and debounce.  
- Never mutate the Cargo cache; treat it as read-only.

## Autocomplete UX that actually works

Do not stream “LLM thoughts.” Do this:

1. 1–2 characters: crate-name prefix only.  
2. After a space or `::`: item search scoped to that crate if possible.  
3. Show:  
   `serde::Deserialize`  ·  trait  ·  serde 1.0.219  
   first sentence of the doc comment  
4. Enter opens local rustdoc (`cargo doc --open` / cached html) or the file in `$CARGO_HOME/registry/src/...`.  
5. Query syntax copied from rustdoc is free quality: `fn:spawn`, `struct:HashMap`, `Vec -> usize`.

Serve it as:

- CLI + TUI (skim / ratatui)  
- local HTTP on `127.0.0.1` for an editor plugin  
- MCP tool if you want agents to use it *without* sending code off-box  

Keep the server in-process or localhost. No accounts, no telemetry.

## Security posture (the reason you refused cloud inference)

- Read-only over `$CARGO_HOME` and project trees you opt in.  
- Models and weights stored locally (`~/.cache/...`). First-run download from Hugging Face is the only network use; pin hashes and allow air-gapped model files.  
- No query logs leaving the machine.  
- Do not execute crate build scripts while indexing. Parse source only.  
- Be careful with `*-sys` / vendored blobs; skip binary-ish paths.

Local ONNX/MLX inference is compatible with that. A hosted embedding API is not.

## What it takes in engineering terms

A solid v1, one person who already writes Rust:

| Slice | Effort | Notes |
|---|---|---|
| Discover crate dirs + `cargo metadata` | 1–2 days | Easy |
| syn/tree-sitter item extraction | 3–7 days | This is the quality bottleneck |
| Tantivy schema + prefix/fuzzy search | 2–4 days | Enough for a usable tool |
| ONNX embed + sqlite-vec + RRF | 3–6 days | Optional second phase |
| Incremental indexer + file watch | 2–3 days | |
| CLI/TUI or editor frontend | 3–7 days | |
| rustdoc-JSON path + rustdoc query syntax | extra week | High leverage |

You can skip a lot of that by composing existing crates instead of inventing a vector DB:

- Lexical: **Tantivy**, **srcsearch**, rustdoc search-index  
- Semantic libraries: **fastembed**, **semstore**, **semtree**, **aurora-semantic**, **search-semantically**, **vecgrep**  
- Scan helpers: **scan_crate** (ripgrep over crate sources)  
- Symbol search inspiration: rust-analyzer `symbol_index` (FST per crate)

Closest “don’t start from zero” paths:

1. Point `vecgrep` / `semtree` / `aurora-semantic` at `~/.cargo/registry/src` and add a crate-version metadata layer.  
2. Build rustdoc for cached crates once and reuse rustdoc’s own search index (the Alfred `alfred-rustdoc` idea, but fully local).  
3. If you only care about the **current project**, rust-analyzer workspace symbols + `*` (search deps) is already done.

## Recommended build order

1. **v0**: Tantivy over item names, paths, signatures, and doc comments of unpacked registry crates. Prefix autocomplete. No model.  
2. **v1**: Hybrid search with BGE-small / MiniLM via `fastembed`. RRF. Incremental index.  
3. **v2**: rustdoc JSON for public APIs; source chunks only for examples and private items.  
4. **v3** (only if you still want it): local 1–3B model to rerank or explain the top hits.

v0 is already a better “search my installed crates” tool than most people have. The small local embedder is the part that makes `how do I wait with a timeout` find `tokio::time::timeout` even when those words never appear together.

If you say whether you mean “all crates ever downloaded” vs “deps of the current workspace,” and whether the Mac Pro is Intel or Apple Silicon, the model + storage choice can be narrowed to one concrete stack (Tantivy + fastembed + sqlite-vec is the safe default on 32 GB either way).
