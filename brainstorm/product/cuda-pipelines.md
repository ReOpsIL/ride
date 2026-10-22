# GPU pipelines in Ride: Sinai-style stage graphs, each stage a Rust CUDA kernel

| Field | Value |
|---|---|
| Date | 2026-10-20 |
| Status | Brainstorm. Not a plan, not scheduled. Nothing here displaces `plan/roadmap/progress-2026-10.md` (P0 is still shipping 1.0) |
| Inputs | Sinai at `~/develop/sinai` (read 2026-10-20), NVIDIA `cuda-rust` at https://github.com/NVIDIA/cuda-rust (read 2026-10-20), this repo at `ecb3678` |
| Conflicts with | `plan/roadmap/next.md` and `next-1.3.md` list "remote development" and "profiler UIs" as not planned. This concept needs a narrow form of both (§8) |

## 1. The idea in one paragraph

Sinai lets imaging teams wire typed stages into a graph and watch each run, stage by stage, on a canvas. NVIDIA's `cuda-rust` makes it possible to write those stages as GPU kernels in safe Rust. Ride is a native Mac IDE with a Rust engine, rust-analyzer behind it and a graph canvas already built. Put together: **a Mac IDE where an algorithm is a graph of Rust GPU kernels, where the graph is read from the code, runs on a remote Linux GPU, and every edge shows what data crossed it, where it lived and what it cost.** Call it *Ride Pipelines* for now.

## 2. What each codebase actually brings

### 2.1 Sinai: the pipeline model

| Concept | Where | What it is |
|---|---|---|
| Pipeline file | `backend/models/pipeline.py`, `backend/pipelines/*.json` | `PipelineModel{nodes, edges}`. A node has `type`, `config`, `position`, group parent. An edge is `source/sourceHandle → target/targetHandle` with a `fanOut` flag |
| Stage | `backend/core/node_base.py` | A Python `BaseNode` subclass with `input_schema` / `output_schema` (handle → `ConnectionType`), a JSON-schema `config_schema`, `resource_tier`, `memory_estimate_gb`, and `async execute(inputs) -> dict` |
| Port types | `backend/core/connection_types.py`, `type_validator.py` | A string enum: primitives, `dicom:Series`, `numpy:Volume`, `numpy:Array2D`, `image:PIL`, `report:CSV`, polygons, `llm:Message`. Compatibility is exact match, `any`, and `list[T] → T` on fan-out edges. The spec says some widening rules are dead code |
| Data flow | `backend/core/graph_builder.py` | In memory. Values over 4 KiB go to Ray's object store (`_should_put`, `ray.put`), are freed after their last consumer, and smaller ones pass inline |
| Execution | `graph_builder.py`, `backend/api/execution.py` | Topological sort into a Ray task DAG. One cached actor per node. Fan-out shards run as stateless remote tasks. A run is a sequence of *ticks*, and iterator nodes keep state across them |
| Compute | `deploy/k8s/ray-cluster.yaml` | Tiers `standard`, `high_memory` and `gpu` (a T4 pool on GKE), overridable per node |
| Run record | `backend/models/events.py`, `backend/core/telemetry.py` | Server-sent events (`node_start`, `node_end`, `node_error`, `node_telemetry`, `tick_start`, `pipeline_done`). Artifacts under `<run>/<tick>/<node>/` with `logs.txt`, `scalars.json`, images, `.npy` and a manifest, on local disk, GCS or S3 |
| UI | `frontend/src/components/` | Canvas with status dots per node, JSON output preview, viewer nodes on the canvas (CT slice with polygon overlay), a Timeline (Gantt per node), a tick bar, and a Console |
| AI | `backend/api/xaix_tools_graph.py`, `xaix_nodegen.py`, `xaix_validation.py` | Generate a graph from a description, with `missing_nodes` as typed placeholders. Generate a node as Python, TSX and pytest, then gate it: AST check, handle alignment, `tsc`, ruff, pytest, and an LLM judge score of at least 7. Errors are fed back for retry |
| Domain | `docs/avc-nodes-roadmap.md`, pipelines | CT imaging: DICOM series → volume → TotalSegmentator → threshold, measure → report. Heart chambers, liver steatosis, bone density, calcium score, hemorrhage, pneumothorax |
| Not there | `docs/SINAI_RESEARCH_VISION.md` | No content-hash caching (roadmap only). No GPU kernels of its own: GPU work is whatever a Python library does inside a node |

### 2.2 cuda-rust: what a stage could be written in

| Concept | What it is today |
|---|---|
| Two kernel models | **cuda-oxide**: SIMT kernels compiled by a custom rustc backend (MIR → Pliron IR → LLVM IR → PTX via `llc` 21+). **cutile-rs**: tile kernels written in a proc-macro DSL over `Tensor<f32, {[B]}>`, compiled just in time at first launch through CUDA Tile IR |
| Toolchain | cuda-oxide pins `nightly-2026-10-11` with `rustc-dev` and `llvm-tools`, and needs CUDA 13.0+, driver R580+ and sm_80+. cutile-rs builds on stable Rust 1.89+ with CUDA 13.2+ |
| Tooling | The `cargo oxide` subcommand: `run`, `build`, `test`, `inspect` (PTX), `pipeline` (dumps every IR stage), `sanitize` (Compute Sanitizer), `debug` (cuda-gdb), `doctor` |
| Kernel authoring | `#[cuda_module]` and `#[kernel]`. `thread::index_1d()` returns an index witness. `DisjointSlice` gives race-free writes. `SharedArray` and `sync_threads` cover shared memory. Generics, closures, enums and `match` work. Device code is `core` only: no heap, `std` or `dyn`, and a panic is a GPU trap |
| Safety | Three tiers: safe body plus checked launch contract, scoped `unsafe` for shared memory, raw intrinsics. Known holes: `&mut [T]` parameters, warp convergence and memory spaces are not enforced |
| Host side | `CudaContext`, streams, `DeviceBuffer::from_host` / `to_host_vec`, typed generated launch methods, `cuda-async` with lazy `DeviceOperation`s, CUDA graphs. Errors are `Result`s, and kernel faults surface at sync |
| Maturity | Repo created 2026-04-22, active daily. It calls itself "early-stage research" with API breakage expected. Linux only: Windows is unsupported and macOS is not mentioned |
| Fixtures | About 190 cuda-oxide examples (`vecadd`, `sharedmem`, `warp_reduce`, `tiled_gemm`, `image_convolution`, `async_mlp`, about 20 `error_*` compile-failure cases). cutile examples: `saxpy`, `softmax`, `rms_norm`, `flash_attention`, `cuda_graphs` |

### 2.3 Ride: what a pipeline feature stands on

| Piece | Where | Reuse for pipelines |
|---|---|---|
| Engine over UniFFI | `src/`, `src/ffi` | Stage discovery, graph extraction, run records, all in Rust next to the user's own Rust |
| Item extraction | `src/extract`, `src/highlight` | Tree-sitter already reads every `fn`, `mod` and attribute. Finding `#[kernel]` items and a pipeline declaration is a query, not a new parser |
| Semantic oracle | `src/oracle`, `docs/product/semantic-oracle.md` | rust-analyzer per Cargo root, never on the keystroke path. Gives types of stage ports and launch arguments |
| Check and diagnostics | `src/check`, `docs/product/diagnostic-overlay.md` | `cargo check` JSON → Problems panel and spans drawn on the code. Device-codegen errors from `cargo oxide build` need the same treatment |
| Run and build | `app/Ride/Run` (`RunConfig`, `BuildSession`, `BuildParse`, `ProcessRunner`, `RunOutputPanel`) | Run configurations, streamed output, build-line parsing, console links |
| Tests | `src/run/tests`, `app/Ride/Tests` | Test tree and markers. A stage's CPU-reference test fits here |
| Debugger | `src/debug` (DAP over `lldb-dap`) | Host-side debugging. cuda-gdb is not a DAP adapter (§8) |
| Workspace map | `app/Ride/Map`, `docs/product/workspace-map.md` | A pan-zoom canvas with cards, edges, nested graphs and Sugiyama, Kamada–Kawai and Fruchterman–Reingold layouts. A pipeline is a layered DAG, which is exactly what Sugiyama draws |
| Trail | `src/trail` | An append-only JSON-lines record of test results and debug stops, each tagged with the HEAD commit. It is the seed of a run history |
| Review | `src/review`, `plan/roadmap/support-2027-v2.md` | The shape hash (tree-sitter tokens without whitespace and comments) identifies a stage's code across formatting and moves. That makes a stable cache key |
| AI | `src/ai`, `app/Ride/AI`, `docs/product/ai-chat.md` | Context packs (focus, enclosing item, referenced definitions, budget), streaming chat, Explain, ghost text, providers by API key (OpenRouter today) |
| Self-test scenes | `app/Ride/Debug/DemoScene*.swift`, `SelfTest*` | Scripted, recorded walkthroughs of real features. A pipeline scene is both the test and the demo video |
| Gaps | | `cargo check` never passes `--target`. There is no remote execution or SSH run target, no per-function profiling, no image or array viewer |

## 3. Opportunity and who it is for

**The gap.** Someone who writes a GPU algorithm today picks two of three: fast to iterate (Python, notebooks, Sinai nodes), fast to run (CUDA C++), safe and maintainable (Rust). Rust on the GPU now has an official NVIDIA path, and nothing around it yet: no IDE understands a `#[kernel]`, nobody shows the PTX next to the source, and no tool treats a multi-kernel algorithm as one thing you can see. NVIDIA's own tools (Nsight Systems, Nsight Compute) profile a finished binary. They do not help you author it.

**Who, in order of fit:**

1. **The imaging algorithm engineer at a Sinai customer.** They have a working Sinai pipeline in Python. One or two nodes dominate the run, for example HU windowing over 51,000 series, a threshold and connected-component pass on a TotalSegmentator mask, resampling, or a calcium-score sum. They want those stages on the GPU without becoming CUDA C++ people, and they work on a Mac. This is the beachhead: Sinai already has the users, the pipelines and the reference outputs to check a kernel against.
2. **The Rust systems engineer who needs a few kernels.** Their Rust service has a hot loop in signal processing, vision, compression or geometry. They know Rust, not CUDA. Their editor is VS Code today.
3. **The GPU engineer evaluating cuda-rust.** They know CUDA C++ and want to see what Rust codegen produces. For them the PTX and IR inspector and the sanitizer view are the hook.

**Why now.** cuda-rust went public in April 2026 and is moving daily. cutile builds on stable Rust. The window in which "the IDE for Rust on GPUs" is unclaimed is short, and Ride is already a Rust-first native IDE.

## 4. The core experience

One session, end to end. Names in *italics* are new.

### 4.1 Author the pipeline

The user opens a crate created from a *pipeline template*. A stage is an ordinary Rust item: a kernel in a `#[cuda_module]`, plus a small typed *stage* declaration naming its input and output ports. The pipeline itself is declared in Rust: stages connected port to port. There is no separate JSON file to keep in sync. The code is the graph.

⌘9 opens the *pipeline view*: the workspace map canvas, drawing this pipeline as cards in Sugiyama layers. Ports are labelled with their Rust types, such as `DeviceBuffer<f32>`, `Tensor<u16, {[512, 512]}>`, or `Volume<i16>` from a small shared types crate. Sinai's `ConnectionType` strings and its hand-written `type_validator` turn into rustc: a wrong connection is a compile error, underlined on the line that made it, with the diagnostic overlay pointing at both ports.

A *stage library* on the left lists every `#[kernel]` and stage in the workspace and its dependencies, read by the index Ride already keeps. Dragging one onto the canvas writes the stage into the pipeline declaration. Connecting two ports writes the connection. Undo is the editor's undo.

### 4.2 Write and check a kernel

Opening a stage's kernel puts the source in the editor, with:

- completion and definitions from the rust-analyzer oracle, if it copes with the cuda-oxide macros (§8, Q1)
- a *kernel cheat sheet*: `thread::index_1d`, `DisjointSlice`, `SharedArray`, `sync_threads`, warp reductions, and launch-config shapes, as TOML under `cheatsheets/` like the six that ship
- *device diagnostics*: `cargo oxide build` errors (the about 20 `error_*` examples are the fixtures) parsed into the Problems panel and the overlay, next to host-side `cargo check` errors
- *Inspect* (one key): the PTX for the kernel at the caret in a side pane, lines linked back to source, with register count, shared memory per block and occupancy for the chosen GPU. `cargo oxide pipeline` gives the intermediate IR stages for the curious
- a *CPU reference*: each stage can name a plain Rust function, or a recorded Sinai node output, that it must match. That is a test in the Tests panel, run on the GPU host

### 4.3 Run and profile

The run target is a *GPU host*: a Linux machine with an NVIDIA GPU, reached over SSH (a workstation, a cloud VM, or a pod in a customer's Sinai cluster). Ride syncs the working tree, builds there, and runs under a thin *pipeline harness*: a host-side crate that executes the declared graph on CUDA streams and writes one JSON event per line on stdout, using Sinai's event names (`run_start`, `tick_start`, `stage_start`, `stage_end`, `stage_error`, `transfer`, `run_done`).

While it runs:

- Cards light up with Sinai's status dots, and each finished card shows its GPU time measured with CUDA events on its stream, bytes moved, and achieved bandwidth.
- The editor shows the same numbers as a code-vision line above the kernel: `1.84 ms · 410 GB/s · tick 12`.
- The bottom panel has Console (the remote output, as the run panel shows today) and *Timeline* (Sinai's per-stage Gantt, per stream, with transfers drawn as their own bars).
- A stage card's menu offers *Profile this stage*, which reruns one tick under Nsight Compute for that kernel only and shows the handful of metrics that matter (occupancy, memory throughput, warp stalls) on the card. The full `ncu` report file is one click away for people who live in Nsight.
- *Sanitize this stage* runs it under Compute Sanitizer and lands races and out-of-bounds accesses in Problems at the source line.

### 4.4 See data move between stages

Clicking an edge opens the *edge inspector* for the selected tick:

- shape, element type, bytes, and **where the data lived**: device, host or pinned, and whether it crossed the PCIe bus on the way
- a preview chosen by type: a slice viewer with a window and level control for a volume (the Sinai CT viewer, rebuilt natively), an image for 2-D data, a histogram plus min, max, mean and NaN count for anything numeric
- a diff against the CPU reference or against the previous run of the same edge

Edges are drawn by residency: solid for device to device, red and labelled with the cost for a round-trip through the host. That one visual answers the most common GPU-pipeline performance question, "why is it slow when every kernel is fast?", at a glance.

## 5. How it differs

| | Nsight Systems / Compute | Jupyter (with CuPy, Numba, Sinai-style notebooks) | VS Code + rust-analyzer + terminal | Ride Pipelines |
|---|---|---|---|---|
| Unit of work | A captured binary run | A cell | A file | A stage in a typed graph |
| Authoring | None | Yes, Python, untyped | Yes, Rust, but no knowledge of kernels | Rust kernels with device diagnostics, PTX inspector and kernel cheat sheet |
| Structure of the algorithm | Inferred from a trace | Linear cells, hidden state | Invisible | Graph read from code, kept in sync both ways |
| Data between steps | Not shown | Printed by hand | Not shown | Per-edge preview, residency and transfer cost |
| Timing | Very deep, after the fact | `%timeit` by hand | None | Per stage, live, on the card and in the code |
| Correctness | Sanitizer, separate tool | Asserts by hand | Tests | CPU-reference test per stage, sanitizer results in Problems |
| Reproducibility | Report files | Poor (execution order, environment) | Git only | Run record: commit, stage shape hashes, toolchain, GPU, input digests (§6, B5) |
| Mac user | Remote GUI or copy reports | Remote kernel | Remote SSH extension | Native editor; build and run on the GPU host |

Nsight stays the tool for the last 10 % of a kernel's performance, and Ride links to it rather than competing. Jupyter stays the tool for exploration. Ride is where the algorithm is *built* and *kept*.

## 6. Bold bets

**B1. The code is the graph.** The pipeline declaration in Rust is the only source of truth. The canvas is a projection read by tree-sitter (fast, every keystroke) and confirmed by rust-analyzer (types of ports). Canvas edits are text edits through the editor's own undo. Diffs, review, blame and the support-2027 follow marks all work on pipelines for free, because pipelines are just code. Sinai's JSON-plus-Python split, with its separate TSX per node, goes away.

**B2. Edges know where data lives.** Every edge carries residency and transfer cost from the harness. A *transfer lint* flags host round-trips between two GPU stages, and copies the pipeline could drop by fusing stages or keeping a buffer on the device. Later, *Fuse stages* as a refactoring: two element-wise kernels become one, with the CPU-reference test proving equivalence.

**B3. Live per-stage GPU timing in the editor.** Code vision already writes "N usages" above every item. The same line shows the last run's GPU time and bandwidth above each kernel, and turns amber when the last run was slower than the run recorded at the last green commit. Timing becomes part of reading code, not a separate profiling session.

**B4. AI kernel writing with hard gates.** Port Sinai's node-generation loop from "LLM writes Python, gates check it" to "LLM writes a kernel, the machine checks it":

1. It compiles for the device.
2. It matches the CPU reference (or the original Sinai Python node's recorded outputs) within tolerance.
3. It is clean under Compute Sanitizer.
4. It meets a time budget on the GPU host.

Failures are fed back automatically, as Sinai's `xaix_validation.py` does. An LLM judge stays optional; the hard gates replace it. The headline flow is **Port this node to the GPU**: select a slow Sinai node, and Ride drafts the kernel, the stage, the reference test and the budget, then iterates until all four gates pass or it gives up with the failing gate shown. Ride's context packs supply the stage types, the neighbouring stages and the kernel cheat sheet.

**B5. Reproducible runs and per-stage caching.** Every run writes a run record into the trail: the commit, the shape hash of each stage's code, the toolchain pins (nightly date, CUDA version, driver, GPU model and compute capability), and a digest of each input. Two consequences follow:

- **Re-run only what changed.** A stage whose shape hash and input digest match a previous run is served from that run's artifacts, which closes the caching gap on Sinai's roadmap.
- **Hunt a performance regression.** "Since last green" (from support-2027 v2) becomes "since last fast": bisect the run records for the commit where a stage's time jumped.

**B6. The Sinai bridge.** A Ride pipeline, or one stage of it, can be exported as a Sinai node: a Python wrapper around the compiled pipeline with Sinai's `input_schema` and `output_schema` mapped from the Rust port types. That node runs on Sinai's GPU tier. Sinai customers get GPU nodes without leaving Sinai, and the people who write them use Ride. This bet is what turns the IDE into a business: it makes Ride the authoring tool for the most valuable nodes in Sinai's planned marketplace.

## 7. Roadmap

Each stage ships on its own, is demoable as a self-test scene, and only starts when the one before it has users.

| Stage | Delivers | Reuses from Ride | Reuses from Sinai | Rough size |
|---|---|---|---|---|
| **M0 Spike** | A written verdict, under `docs/product/` or `todo/`, on whether to continue. It answers three things: does Ride's index and rust-analyzer handle a cuda-oxide example crate (nightly pin, `#[cuda_module]`) on macOS? Does a cutile crate behave better? Can a GPU host be reached reliably over SSH, and can `cargo oxide run` and `cargo oxide build` output be streamed and parsed? | Index, oracle, Problems, run panel, by hand | — | 1–2 weeks |
| **M1 Kernel editor with remote run** | A GPU host as a run target (SSH, workspace sync, remote build, streamed output). `cargo oxide` build errors in Problems and the overlay. The PTX inspector. The kernel cheat sheet. Remote CPU-reference tests in the Tests panel | `RunConfig`, `BuildSession`, `BuildParse`, `ProcessRunner`, `RunOutputPanel`, `src/check` diagnostic records, cheat sheet TOML loader, test tree | — | 4–6 weeks |
| **M2 Pipeline as code, graph view** | The stage and pipeline declarations (a small `ride-pipe` crate). The harness emitting JSON-line events. The pipeline view on the map canvas. Per-stage time on cards and in code vision. The Timeline | `src/extract`, map canvas and Sugiyama layout, code vision, oracle types | Event names (`events.py`), status dots, Timeline and tick model, iterator and fan-out semantics from `pipeline-graph-spec.md` | 6–8 weeks |
| **M3 Data inspector** | The edge inspector with residency and transfer cost. Volume, image and histogram previews. Artifacts stored per run, tick and stage. The transfer lint | Markdown and HTML panes for reports, the trail directory for artifacts | Artifact layout (`<run>/<tick>/<node>/`), the CT slice viewer as the reference design | 4–6 weeks |
| **M4 Reproducible runs** | The run record. Per-stage caching keyed on shape hash and input digest. Comparing two runs. Hunting a regression | `src/trail`, `src/review` shape hash, `git` module, the hunt design from support-2027 v2 | Run IDs, manifests | 3–4 weeks |
| **M5 AI kernel author** | Generate a stage from a description. Port a Sinai node. The four-gate loop with feedback. Profile and sanitize this stage | `src/ai` context packs, chat panel, Explain, provider layer | The nodegen gate pipeline (`xaix_nodegen.py`, `xaix_validation.py`), recorded node outputs as references | 6–8 weeks |
| **M6 Sinai bridge** | Export a pipeline or stage as a Sinai node. Run it on Sinai's Ray GPU tier. Map Rust port types to `ConnectionType` | Packaging and release scripts | `BaseNode`, `node_projects.py` node repos, `TIER_RESOURCES`, workspace pods | 4–6 weeks, plus Sinai-side work |

The thinnest version worth showing anyone is **M1 plus a hard-coded two-stage harness**: edit a kernel on the Mac, press Run, and watch two cards turn green with their GPU times. That is a 30-second demo nobody else has.

## 8. Risks and open questions

**R1. cuda-rust is alpha.**

- The project calls itself early-stage research and expects API breakage, so a feature built on it breaks with every upstream release.
- cuda-oxide pins one nightly and needs `rustc-dev`.
- cutile's 0.4.0 release had several breaking changes.

Mitigation: keep everything that touches cuda-rust in one adapter (the harness crate and the build-output parser), pin the cuda-rust version per template, and run a nightly self-test against upstream examples.

**Q1. Does rust-analyzer work on a cuda-oxide crate on macOS?**

- The crate needs a nightly with `rustc-dev`.
- Device code goes through a custom backend.
- `#[cuda_module]` is a proc macro that may only expand fully on Linux.

If rust-analyzer cannot load it, completion falls back to Ride's own index, which is weaker on types. M0 answers this. cutile, on stable Rust, is the likely fallback for a good editing experience, at the cost of JIT compilation: device errors would surface only at first launch, not at check.

**Q2. Which kernel model comes first?**

- cuda-oxide gives an ahead-of-time compile, PTX inspection, sanitizer and debugger. That means more to show, and the check loop works.
- cutile gives stable Rust and higher-level tiles, which suit imaging. But it is JIT, with no thread-level view.

Lean: cuda-oxide first for the IDE story, with cutile stages allowed in the same pipeline later (they can share a stream today).

**R2. macOS has no NVIDIA GPU.** Every build of device code and every run happens on a remote Linux host. The design keeps this narrow:

- **What stays local:** editing, indexing and the graph.
- **What runs on the host:** build, run, test, profile and sanitize. They run over SSH in the same run panel.

This is a *remote run target*, not the "remote workspace" the roadmap rules out. Open points:

- How should the tree sync: rsync, or a git push to a scratch ref?
- How do diagnostic paths map from the host back to local files? The debug-source-paths work already handles one kind of path spelling.
- What latency does the check loop have over SSH?
- Can host-side `cargo check` still run locally on macOS, so most errors come back without a round-trip?

**R3. GPU access and cost.**

- cuda-rust needs sm_80 or newer. Sinai's GKE GPU pool is T4 (sm_75), so **Sinai's current GPU tier cannot run cuda-rust kernels**. M6 needs an L4, A100 or newer pool.
- Users without a GPU host need a hosted option, which is infrastructure Ride does not have.

**R4. Debugging kernels.**

- Ride's debugger speaks DAP to `lldb-dap`. cuda-gdb (`cargo oxide debug`) is a gdb, not a DAP adapter, and it runs on the remote host.
- Host-side debugging over SSH is possible later. Kernel-level stepping is out of scope until a DAP bridge exists.
- The sanitizer view and `gpu_printf!` output in the console cover most needs early on.

**R5. Profiling depth.**

- Per-stage timing comes from CUDA events in the harness, which is cheap and always on.
- Nsight Compute needs GPU performance-counter permission on the host, which a cloud VM may not grant.
- cuda-rust has no NVTX support today, so Nsight Systems traces will not show stage names unless the harness adds ranges itself.

**R6. Focus.** Ride has not shipped 1.0 publicly, and Git, the oracle finish and AI Apply are half built (`progress-2026-10.md`). This concept is a 2027 bet at the earliest. It must not pull the team off P0–P2. M0 is cheap enough to run beside them; M1 is not.

**R7. Will the users write Rust?** Sinai's users write Python, and the beachhead persona has to cross into Rust. B4 (porting a node with gates) is the answer, but it is unproven. Q3: is the buyer the algorithm engineer who wants speed, or the Sinai platform team that wants faster nodes in the marketplace? The answer decides whether M5 and M6 come before M3 and M4.

**R8. Data handling.** CT inputs are patient data. Running stages on a remote host, storing per-edge artifacts and showing previews in a Mac app all move data that may be protected. The GPU host should be inside the customer's environment (the Sinai workspace pod), artifacts should stay on the host by default, and previews should be streamed, not stored.

**R9. Licensing.** The v0.2.1 release notes put `cuda-bindings` under the NVIDIA Software License, while the current README says Apache-2.0 throughout. Check this before shipping templates that depend on it.

## 9. Recommended first step

Run M0 as a one- to two-week spike, separate from the 1.0 work:

1. On the Mac, open `vecadd`, `sharedmem` and `image_convolution` from cuda-oxide, and `saxpy` and `softmax` from cutile, in Ride.
2. Record what the index, the cheat sheet and rust-analyzer give, and which of the about 20 `error_*` cases `cargo check` reports locally.
3. Rent one sm_80+ Linux GPU VM. Run `cargo oxide run` and `cargo oxide build` there over SSH from Ride's terminal, and capture the output.
4. Write the verdict and the shape of the build-output parser into `todo/`.

The result decides Q1 and Q2, and whether M1 is worth six weeks.
